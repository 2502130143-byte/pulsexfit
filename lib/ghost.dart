import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'services.dart';
import 'ui.dart';

// =====================================================================
//  MODO FANTASMA 👻 + ENTRENADOR DE VOZ
//  Compite en tiempo real contra uno de tus entrenamientos anteriores.
//  El fantasma avanza por su ruta al ritmo que llevabas ese día.
// =====================================================================

/// Reproduce un entrenamiento pasado segundo a segundo.
class Ghost {
  final Workout w;
  final List<double> _cum = [0]; // metros acumulados en cada punto de la ruta
  Ghost(this.w) {
    const d = Distance();
    for (var i = 1; i < w.route.length; i++) {
      _cum.add(_cum.last + d.as(LengthUnit.Meter, w.route[i - 1], w.route[i]));
    }
  }

  double get totalM => w.km * 1000;
  double _f(int secs) => w.secs == 0 ? 1 : (secs / w.secs).clamp(0.0, 1.0);

  /// Metros que llevaba el fantasma a este segundo (ritmo constante de ese día).
  double metersAt(int secs) => totalM * _f(secs);
  bool finishedAt(int secs) => secs >= w.secs;

  /// Posición del fantasma en su ruta (interpolada entre puntos GPS).
  LatLng? posAt(int secs) {
    if (w.route.isEmpty) return null;
    if (w.route.length == 1 || _cum.last == 0) return w.route.first;
    final target = _cum.last * _f(secs);
    var i = 1;
    while (i < _cum.length - 1 && _cum[i] < target) {
      i++;
    }
    final a = w.route[i - 1], b = w.route[i];
    final seg = _cum[i] - _cum[i - 1];
    final t = seg == 0 ? 0.0 : ((target - _cum[i - 1]) / seg).clamp(0.0, 1.0);
    return LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
  }

  /// Ritmo del fantasma en segundos por km.
  double get paceSec => w.km <= 0 ? 0 : w.secs / w.km;
}

String paceText(double secPerKm) {
  if (secPerKm <= 0 || secPerKm.isInfinite || secPerKm.isNaN) return '--:--';
  final s = secPerKm.round();
  return "${s ~/ 60}:${two(s % 60)}";
}

String paceSpoken(double secPerKm) {
  final s = secPerKm.round();
  return '${s ~/ 60} minutos ${s % 60} segundos por kilómetro';
}

/// Entrenador de voz (texto a voz en español) + vibración.
class Voice {
  static final _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> say(String text, {bool vibrate = false}) async {
    if (vibrate) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
    if (!S.voice) return;
    try {
      if (!_ready) {
        await _tts.setLanguage('es-MX');
        await _tts.setSpeechRate(.5);
        await _tts.setPitch(1.05);
        _ready = true;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Entrenamientos que sirven como rival (con ruta y duración suficientes).
List<Workout> ghostCandidates() => S.history.where((w) => w.secs >= 120 && w.km >= .2).toList();

Workout? bestGhost() {
  final c = ghostCandidates();
  if (c.isEmpty) return null;
  c.sort((a, b) => b.kmh.compareTo(a.kmh));
  return c.first;
}

/// Hoja inferior para elegir a qué fantasma retar.
Future<Workout?> pickGhost(BuildContext c) async {
  final list = ghostCandidates();
  if (list.isEmpty) {
    snack(c, 'Completa un entrenamiento de al menos 2 min y 200 m para crear tu primer fantasma 👻');
    return null;
  }
  final best = bestGhost();
  return showModalBottomSheet<Workout>(
    context: c,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (d) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(d).size.height * .75),
      decoration: BoxDecoration(
        color: const Color(0xFF07061A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: purple),
        boxShadow: [BoxShadow(color: purple.withOpacity(.5), blurRadius: 30)],
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 50, height: 5, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 14),
        const Text('👻', style: TextStyle(fontSize: 46)),
        GradText('Modo Fantasma', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic), colors: const [cyan, pink]),
        const Text('Elige a qué versión de ti quieres vencer', style: TextStyle(color: soft)),
        const SizedBox(height: 14),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (final w in list.take(15))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Glass(
                  r: 18,
                  glow: w == best,
                  border: w == best ? const [lime, cyan] : gBorder,
                  onTap: () => Navigator.pop(d, w),
                  child: Row(children: [
                    Text(w == best ? '🏆' : '👻', style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (w == best) const Text('TU MEJOR MARCA', style: TextStyle(color: lime, fontSize: 12, fontWeight: FontWeight.w800)),
                        Text(fdate(w.date), style: const TextStyle(color: soft, fontSize: 12)),
                        Text('${w.km.toStringAsFixed(2)} km · ${(w.secs / 60).round()} min · ritmo ${paceText(w.secs / w.km)}/km',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: cyan),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    ),
  );
}

/// Tarjeta del duelo en vivo: tú vs tu fantasma.
class DuelCard extends StatelessWidget {
  final double myM, ghostM, totalM, ghostPace;
  final bool ghostDone;
  const DuelCard({super.key, required this.myM, required this.ghostM, required this.totalM, required this.ghostPace, this.ghostDone = false});

  @override
  Widget build(BuildContext c) {
    final diff = myM - ghostM;
    final ahead = diff >= 0;
    final col = diff.abs() < 5 ? orange : (ahead ? green : red);
    final secs = ghostPace <= 0 ? 0 : (diff.abs() / 1000 * ghostPace).round();
    Widget bar(String who, double m, List<Color> g, String emoji) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        SizedBox(width: 26, child: Text(emoji, style: const TextStyle(fontSize: 18))),
        SizedBox(width: 74, child: Text(who, style: const TextStyle(fontSize: 13, color: soft))),
        Expanded(
          child: Stack(children: [
            Container(height: 12, decoration: BoxDecoration(color: const Color(0xFF1E1B4A), borderRadius: BorderRadius.circular(8))),
            FractionallySizedBox(
              widthFactor: totalM <= 0 ? 0 : (m / totalM).clamp(.02, 1.0),
              child: Container(height: 12, decoration: BoxDecoration(gradient: LinearGradient(colors: g), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: g.last.withOpacity(.6), blurRadius: 8)])),
            ),
          ]),
        ),
        SizedBox(width: 64, child: Text('${(m / 1000).toStringAsFixed(2)} km', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
      ]),
    );
    return Glass(
      r: 22,
      border: [col, purple],
      child: Column(children: [
        Row(children: [
          const Text('👻', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Duelo contra tu fantasma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (ghostDone) const Dot('Fantasma en meta', col: pink),
        ]),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            diff.abs() < 5 ? '¡Empatados!' : (ahead ? '+${diff.abs().round()} m adelante' : '−${diff.abs().round()} m atrás'),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: col, shadows: [Shadow(color: col, blurRadius: 14)]),
          ),
        ),
        if (diff.abs() >= 5) Text(ahead ? 'Le llevas ~$secs s de ventaja 🔥' : 'Estás ~$secs s detrás, ¡acelera! ⚡', style: const TextStyle(color: soft)),
        bar('Tú', myM, const [cyan, green], '🏃'),
        bar('Fantasma', ghostM, const [purple, pink], '👻'),
      ]),
    );
  }
}

/// Tarjeta de acceso al Modo Fantasma (Inicio y Entrenador).
class GhostCard extends StatelessWidget {
  final VoidCallback onTap;
  const GhostCard({super.key, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final best = bestGhost();
    return Glass(
      r: 24,
      border: const [pink, purple, cyan],
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [pink.withOpacity(.45), Colors.transparent])),
          child: const Center(child: Text('👻', style: TextStyle(fontSize: 40))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GradText('Modo Fantasma', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic), colors: const [cyan, pink]),
            Text(
              best == null ? 'Compite en vivo contra tu mejor versión. Completa un entrenamiento para crear tu primer fantasma.' : 'Reta a tu mejor marca: ${best.km.toStringAsFixed(2)} km a ${paceText(best.secs / best.km)}/km',
              style: const TextStyle(color: soft, fontSize: 13.5),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right, color: pink, size: 30),
      ]),
    );
  }
}
