import 'dart:async';
import 'dart:math' as m;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:sensors_plus/sensors_plus.dart';
import 'services.dart';
import 'ui.dart';
import 'shell.dart';
import 'permissions.dart';
import 'popups.dart';
import 'pulsebot.dart';
import 'ghost.dart';
import 'package:battery_plus/battery_plus.dart';

// ======================= SENSORES DE MOVIMIENTO =======================
/// Lee acelerómetro, giroscopio y brújula, y calcula el estado del movimiento.
/// Libera los listeners al pausar la app (onPause) y al salir de la pantalla (dispose).
class Motion extends ChangeNotifier with WidgetsBindingObserver {
  List<double> a = [0, 0, 0], g = [0, 0, 0];
  double heading = 0, _dev = 0;
  final ab = <double>[], gb = <double>[];
  final _subs = <StreamSubscription>[];
  DateTime _last = DateTime(0);
  bool hasAcc = false, hasGyro = false, checked = false, _obs = false;
  Timer? _probe;

  void start() {
    if (!_obs) {
      WidgetsBinding.instance.addObserver(this);
      _obs = true;
    }
    _listen();
    // Fallback: si en 3 s no llega ningún dato, el sensor no existe en el dispositivo.
    _probe?.cancel();
    _probe = Timer(const Duration(seconds: 3), () {
      checked = true;
      notifyListeners();
    });
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused || st == AppLifecycleState.hidden) _cancel();
    if (st == AppLifecycleState.resumed && _subs.isEmpty) _listen();
  }

  /// Inclinación del teléfono (grados) calculada con la gravedad del acelerómetro.
  double get pitch => m.atan2(-a[0], m.sqrt(a[1] * a[1] + a[2] * a[2])) * 180 / m.pi;
  double get roll => m.atan2(a[1], a[2]) * 180 / m.pi;
  bool get turning => gd.any((v) => v.abs() > 45);
  String get dir => ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'][((((heading + 360) % 360) + 22.5) ~/ 45) % 8];

  void _listen() {
    final iv = S.saver ? const Duration(seconds: 1) : SensorInterval.uiInterval;
    void push(List<double> b, double v) {
      b.add(v);
      if (b.length > 40) b.removeAt(0);
    }

    void tick() {
      final n = DateTime.now();
      if (n.difference(_last).inMilliseconds > 120) {
        _last = n;
        notifyListeners();
      }
    }

    try {
      _subs.add(accelerometerEventStream(samplingPeriod: iv).listen((e) {
        a = [e.x, e.y, e.z];
        hasAcc = true;
        final mag = m.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        _dev = _dev * .9 + (mag - 9.81).abs() * .1; // promedio móvil de la sacudida
        push(ab, mag / 20);
        tick();
      }, onError: (_) {}));
      _subs.add(gyroscopeEventStream(samplingPeriod: iv).listen((e) {
        g = [e.x, e.y, e.z];
        hasGyro = true;
        push(gb, m.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 5);
        tick();
      }, onError: (_) {}));
      final comp = FlutterCompass.events;
      if (comp != null) _subs.add(comp.listen((e) => heading = e.heading ?? heading, onError: (_) {}));
    } catch (_) {}
  }

  /// Aceleración en g y rotación en °/s, como en el diseño.
  List<double> get ag => [for (final v in a) v / 9.81];
  List<double> get gd => [for (final v in g) v * 180 / m.pi];
  double get level => (_dev / 6).clamp(0.0, 1.0);
  /// Clasificación por la variación de la aceleración triaxial |√(x²+y²+z²) − g|.
  String get state => _dev < .6 ? 'Descanso' : (_dev < 2.8 ? 'Caminata' : 'Trote');

  @override
  void dispose() {
    _probe?.cancel();
    _cancel();
    if (_obs) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ======================= MAPA NEÓN EN TIEMPO REAL (OpenStreetMap, sin API key) =======================
/// Mapa interactivo que sigue tu posición en vivo: marcador con pulso, flecha de orientación,
/// círculo de precisión GPS y trazado de la ruta. Si mueves el mapa con el dedo deja de seguirte;
/// el botón de centrar vuelve a activar el seguimiento.
class LiveMap extends StatefulWidget {
  final List<LatLng> route;
  final LatLng? pos;
  final MapController? ctl;
  final double r, heading, accuracy;
  final bool live;
  final List<LatLng> ghostRoute;
  final LatLng? ghostPos;
  const LiveMap({super.key, this.route = const [], this.pos, this.ctl, this.r = 22, this.heading = 0, this.accuracy = 0, this.live = false, this.ghostRoute = const [], this.ghostPos});
  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  late final MapController c = widget.ctl ?? MapController();
  late final pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  bool follow = true, ready = false;
  LatLng? get p => widget.pos ?? (widget.route.isEmpty ? null : widget.route.last);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  void _center({double? zoom}) {
    if (p == null || !ready) return;
    try {
      c.move(p!, zoom ?? c.camera.zoom);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(LiveMap o) {
    super.didUpdateWidget(o);
    final old = o.pos ?? (o.route.isEmpty ? null : o.route.last);
    if (follow && p != null && p != old) _center(zoom: old == null ? 17 : null);
  }

  @override
  Widget build(BuildContext ctx) {
    final fit = !widget.live && widget.pos == null && widget.route.length > 1;
    return Glass(
      r: widget.r,
      p: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.r - 1.3),
        child: Stack(children: [
          FlutterMap(
            mapController: c,
            options: MapOptions(
              backgroundColor: const Color(0xFF0A0A1F),
              initialCenter: p ?? widget.route.firstOrNull ?? const LatLng(19.4326, -99.1332),
              initialZoom: p == null ? 5 : 17,
              maxZoom: 19,
              initialCameraFit: fit ? CameraFit.coordinates(coordinates: widget.route, padding: const EdgeInsets.all(36)) : null,
              onMapReady: () => ready = true,
              onPositionChanged: (_, gesture) {
                if (gesture && follow) setState(() => follow = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.pulsexfit',
                maxNativeZoom: 19,
                tileBuilder: darkModeTileBuilder,
              ),
              IgnorePointer(child: Container(color: purple.withOpacity(.12))),
              if (p != null && widget.accuracy > 0)
                CircleLayer(circles: [
                  CircleMarker(point: p!, radius: widget.accuracy, useRadiusInMeter: true, color: cyan.withOpacity(.12), borderColor: cyan.withOpacity(.45), borderStrokeWidth: 1),
                ]),
              if (widget.ghostRoute.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: widget.ghostRoute, strokeWidth: 10, color: pink.withOpacity(.18)),
                  Polyline(points: widget.ghostRoute, strokeWidth: 3, color: pink.withOpacity(.7)),
                ]),
              if (widget.route.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: widget.route, strokeWidth: 14, color: lime.withOpacity(.22)),
                  Polyline(points: widget.route, strokeWidth: 5, gradientColors: const [green, lime, Color(0xFFFFE01A)]),
                ]),
              MarkerLayer(markers: [
                if (widget.ghostPos != null)
                  Marker(
                    point: widget.ghostPos!,
                    width: 46,
                    height: 46,
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Opacity(
                        opacity: .6 + .4 * (1 - pulse.value),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: pink.withOpacity(.25), border: Border.all(color: pink, width: 2), boxShadow: [BoxShadow(color: pink.withOpacity(.8), blurRadius: 16)]),
                          child: const Center(child: Text('👻', style: TextStyle(fontSize: 22))),
                        ),
                      ),
                    ),
                  ),
                if (widget.route.length > 1)
                  Marker(point: widget.route.first, width: 18, height: 18, child: Container(decoration: BoxDecoration(color: lime, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                if (p != null)
                  Marker(
                    point: p!,
                    width: 90,
                    height: 90,
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Stack(alignment: Alignment.center, children: [
                        // Pulso "en vivo"
                        Container(
                          width: 24 + 60 * pulse.value,
                          height: 24 + 60 * pulse.value,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: cyan.withOpacity(.35 * (1 - pulse.value))),
                        ),
                        // Flecha de orientación (brújula / rumbo GPS)
                        Transform.rotate(
                          angle: widget.heading * m.pi / 180,
                          child: const Padding(padding: EdgeInsets.only(bottom: 38), child: Icon(Icons.navigation_rounded, size: 24, color: cyan, shadows: [Shadow(color: cyan, blurRadius: 10)])),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00B8FF), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: cyan, blurRadius: 14)]),
                        ),
                      ]),
                    ),
                  ),
              ]),
              RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
          if (widget.live)
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: bg.withOpacity(.8), borderRadius: BorderRadius.circular(14), border: Border.all(color: p == null ? orange : green)),
                child: Dot(p == null ? 'Buscando GPS…' : 'EN VIVO', col: p == null ? orange : green),
              ),
            ),
          Positioned(
            right: 10,
            bottom: 28,
            child: GestureDetector(
              onTap: () {
                setState(() => follow = true);
                _center(zoom: 17);
              },
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: bg.withOpacity(.85), shape: BoxShape.circle, border: Border.all(color: follow ? cyan : purple), boxShadow: follow ? [BoxShadow(color: cyan.withOpacity(.6), blurRadius: 12)] : null),
                child: Icon(follow ? Icons.gps_fixed : Icons.gps_not_fixed, color: follow ? cyan : Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ======================= ENTRENAMIENTO EN CURSO =======================
class WorkoutPage extends StatefulWidget {
  final Advice? advice;
  final Workout? ghost;
  const WorkoutPage({super.key, this.advice, this.ghost});
  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final se = Session();
  final mo = Motion();
  final mapCtl = MapController();
  late final Ghost? ghost = widget.ghost == null ? null : Ghost(widget.ghost!);
  int _lastKm = 0, _lead = 0; // _lead: 1 adelante, -1 atrás, 0 sin definir
  bool _ghostFinishedSaid = false, _halfSaid = false, _finished = false;

  @override
  void initState() {
    super.initState();
    S.session = se;
    mo.start();
    se.addListener(_coach);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Perms.ensure(context, force: true); // diálogo claro antes de activar GPS y podómetro
      await _checkBattery();
      if (!mounted) return;
      se.start();
      final g = ghost;
      Voice.say(g == null
          ? 'Entrenamiento iniciado. ¡Vamos, ${S.firstName}!'
          : 'Modo fantasma activado. Tu rival recorrió ${g.w.km.toStringAsFixed(1)} kilómetros a ${paceSpoken(g.paceSec)}. ¡A ganarle!', vibrate: true);
    });
  }

  /// Entrenador de voz: anuncia cada km, el cambio de líder contra el fantasma y la meta.
  void _coach() {
    if (se.paused) return;
    final km = se.bestKm;
    if (km.floor() > _lastKm) {
      _lastKm = km.floor();
      Voice.say('Kilómetro $_lastKm. Ritmo ${paceSpoken(se.secs / km)}.', vibrate: true);
    }
    final g = ghost;
    if (g == null || se.secs < 10) return;
    final diff = km * 1000 - g.metersAt(se.secs);
    final now = diff > 10 ? 1 : (diff < -10 ? -1 : _lead);
    if (now != _lead) {
      if (_lead != 0) {
        Voice.say(now == 1 ? '¡Rebasaste a tu fantasma! Mantén el ritmo.' : 'Tu fantasma te rebasó. ¡Acelera!', vibrate: true);
      }
      _lead = now;
    }
    if (!_halfSaid && se.secs >= g.w.secs / 2) {
      _halfSaid = true;
      Voice.say(diff >= 0 ? 'Mitad del reto. Vas ${diff.round()} metros adelante.' : 'Mitad del reto. Vas ${(-diff).round()} metros atrás.');
    }
    if (!_ghostFinishedSaid && g.finishedAt(se.secs)) {
      _ghostFinishedSaid = true;
      Voice.say(km * 1000 >= g.totalM ? '¡Venciste a tu fantasma! Eres más rápido que antes.' : 'Tu fantasma llegó a la meta. ¡Termina fuerte!', vibrate: true);
    }
  }

  @override
  void dispose() {
    se.removeListener(_coach);
    if (!_finished) Voice.stop(); // al finalizar deja terminar el mensaje de resultado
    S.session = null;
    se.dispose();
    mo.dispose();
    super.dispose();
  }

  /// Advertencia de batería baja antes de iniciar (sugiere el modo ahorro).
  Future<void> _checkBattery() async {
    if (S.saver || !mounted) return;
    try {
      final lvl = await Battery().batteryLevel;
      if (lvl > 20 || !mounted) return;
      final on = await popupLowBattery(context, lvl);
      if (on == true) {
        S.setSaver(true);
        if (mounted) snack(context, 'Modo ahorro activado ⚡');
      }
    } catch (_) {}
  }

  Future<void> finish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Finalizar entrenamiento'),
        content: Text('${fmt(se.secs)} · ${se.km.toStringAsFixed(2)} km · ${fnum(se.steps)} pasos', style: const TextStyle(color: soft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Continuar')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Finalizar', style: TextStyle(color: red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _finished = true;
    final w = se.finish();
    final before = S.challenges, lvl = S.level;
    S.addWorkout(w);
    final news = [for (final e in S.challenges.entries) if (e.value && before[e.key] != true) e.key];
    if (S.level != lvl) news.add('Has alcanzado el ${S.level}.');
    final g = ghost;
    if (g != null) {
      // Resultado del duelo: se compara la distancia cuando terminó el fantasma (o al final si fue antes).
      final t = se.secs < g.w.secs ? se.secs : g.w.secs;
      final mine = w.km * 1000 * (se.secs == 0 ? 0 : t / se.secs);
      final diff = mine - g.metersAt(t);
      if (diff >= 0) {
        news.insert(0, 'Has alcanzado una nueva versión de ti: venciste a tu fantasma por ${diff.round()} m 👻');
        Voice.say('¡Ganaste el duelo por ${diff.round()} metros!', vibrate: true);
      } else {
        Voice.say('Tu fantasma ganó por ${(-diff).round()} metros. La próxima es tuya.');
      }
    } else {
      Voice.say('Entrenamiento terminado. ${w.km.toStringAsFixed(2)} kilómetros. ¡Excelente trabajo!');
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CompletedPage(w, news: news)));
  }

  Widget sensorMini(IconData i, Color col, String t, List<double> v, String u) => Expanded(
    child: Glass(
      r: 18,
      p: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        glowIcon(i, 26, c: col),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            for (var k = 0; k < 3; k++) Text('${'XYZ'[k]}:  ${v[k].toStringAsFixed(2)} $u', style: const TextStyle(fontSize: 14)),
          ]),
        ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      waves: false,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([se, mo]),
          builder: (_, __) {
            final kmh = se.speed * 3.6;
            final moving = kmh > 1.5 ? se.intensity : mo.state;
            final adv = widget.advice;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(c)),
                Expanded(child: Center(child: Text(ghost == null ? 'Entrenamiento' : 'Modo Fantasma 👻', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))),
                GestureDetector(
                  onTap: se.toggle,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [pink, purple]), boxShadow: [BoxShadow(color: purple.withOpacity(.7), blurRadius: 14)]),
                    child: Icon(se.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                glowIcon(Icons.timer_outlined, 54, c: cyan),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmt(se.secs), style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()], color: se.paused ? soft : Colors.white)),
                  Text(se.paused ? 'En pausa' : 'Tiempo transcurrido', style: TextStyle(color: se.paused ? orange : soft, fontSize: 15)),
                ]),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: StatTile(Icons.location_on, cyan, se.bestKm.toStringAsFixed(2), se.km > 0.01 ? 'km GPS' : 'km (pasos)')),
                const SizedBox(width: 8),
                Expanded(child: StatTile(Icons.directions_run, cyan, fnum(se.steps), 'Pasos')),
                const SizedBox(width: 8),
                Expanded(child: StatTile(Icons.local_fire_department, orange, '${se.cal}', 'Calorías')),
                const SizedBox(width: 8),
                Expanded(child: StatTile(Icons.speed, cyan, kmh.toStringAsFixed(1), 'km/h')),
              ]),
              if (adv != null) ...[
                const SizedBox(height: 12),
                Glass(
                  r: 18,
                  border: const [pink, purple],
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      glowIcon(Icons.psychology_outlined, 24, c: pink),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Pulse IA · ${adv.title}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${se.km.toStringAsFixed(1)} / ${adv.km} km', style: const TextStyle(color: cyan)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: adv.km == 0 ? 0 : (se.km / adv.km).clamp(0.0, 1.0), minHeight: 8, backgroundColor: const Color(0xFF1E1B4A), color: lime),
                    ),
                    const SizedBox(height: 6),
                    Text(kmh < adv.kmh - .5 && kmh > 0 ? 'Sube el ritmo: objetivo ${adv.kmh.toStringAsFixed(1)} km/h' : 'Objetivo ${adv.kmh.toStringAsFixed(1)} km/h · ${adv.mins} min', style: const TextStyle(color: soft, fontSize: 13)),
                  ]),
                ),
              ],
              if (ghost != null) ...[
                const SizedBox(height: 12),
                DuelCard(
                  myM: se.bestKm * 1000,
                  ghostM: ghost!.metersAt(se.secs),
                  totalM: ghost!.totalM,
                  ghostPace: ghost!.paceSec,
                  ghostDone: ghost!.finishedAt(se.secs),
                ),
              ],
              const SizedBox(height: 12),
              Stack(children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: LiveMap(
                    route: se.route,
                    pos: se.pos,
                    ctl: mapCtl,
                    live: true,
                    accuracy: se.accuracy,
                    heading: se.speed > .5 ? se.gpsHeading : mo.heading,
                    ghostRoute: ghost?.w.route ?? const [],
                    ghostPos: ghost?.posAt(se.secs),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: GestureDetector(
                    onTap: () => go(c, const MapPage()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: bg.withOpacity(.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: purple)),
                      child: const Row(children: [Icon(Icons.fullscreen, size: 18, color: cyan), SizedBox(width: 4), Text('Pantalla completa', style: TextStyle(fontSize: 13))]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Glass(
                r: 18,
                p: const EdgeInsets.fromLTRB(6, 4, 14, 4),
                child: Row(children: [
                  PulseBot(size: 52, mode: se.paused ? BotMode.idle : botFromState(moving)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Movimiento: ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        TextSpan(text: moving, style: const TextStyle(fontSize: 18, color: lime, fontWeight: FontWeight.w700, shadows: [Shadow(color: lime, blurRadius: 10)])),
                      ])),
                    ),
                  ),
                  const SizedBox(width: 6),
                  LevelBars(kmh > 1.5 ? (kmh / 14).clamp(0.0, 1.0) : mo.level, h: 30, n: 7, w: 10),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                sensorMini(Icons.monitor_heart_outlined, cyan, 'Acelerómetro', mo.ag, 'g'),
                const SizedBox(width: 10),
                sensorMini(Icons.threesixty, pink, 'Giroscopio', mo.gd, '°/s'),
              ]),
              const SizedBox(height: 10),
              Glass(
                r: 18,
                p: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Transform.rotate(angle: -mo.heading * m.pi / 180, child: glowIcon(Icons.explore, 30)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Orientación ${mo.dir} ${((mo.heading + 360) % 360).round()}°  ·  Inclinación ${mo.pitch.round()}° / ${mo.roll.round()}°',
                        style: const TextStyle(fontSize: 14)),
                  ),
                  if (mo.turning) const Text('Giro', style: TextStyle(color: lime, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GradBtn(se.paused ? 'Reanudar' : 'Pausar', se.toggle, icon: se.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, colors: const [Color(0xFF9B30FF), Color(0xFF6A3CFF)], h: 54, fs: 19)),
                const SizedBox(width: 12),
                Expanded(child: GradBtn('Finalizar', finish, icon: Icons.stop_rounded, colors: const [Color(0xFFFF1744), Color(0xFFC2002F)], h: 54, fs: 19)),
              ]),
            ]);
          },
        ),
      ),
    ),
  );
}

// ======================= COMPLETADO =======================
class CompletedPage extends StatefulWidget {
  final Workout w;
  final List<String> news;
  const CompletedPage(this.w, {super.key, this.news = const []});
  @override
  State<CompletedPage> createState() => _CompletedPageState();
}

class _CompletedPageState extends State<CompletedPage> {
  Workout get w => widget.w;

  @override
  void initState() {
    super.initState();
    // Ventanas emergentes: ¡Excelente trabajo! y luego los logros nuevos.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await popupWorkoutDone(context, km: w.km, kcal: w.cal, mins: (w.secs / 60).round());
      for (final n in widget.news) {
        if (!mounted) return;
        final see = await popupAchievement(context, n.startsWith('Has alcanzado') ? n : 'Desbloqueaste: $n');
        if (see == true && mounted) {
          tab.value = 4;
          goRoot(context, const Shell());
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            glowIcon(Icons.emoji_events, 130, c: const Color(0xFFFFC21A)),
            const SizedBox(height: 10),
            GradText('¡Entrenamiento\nCompletado!', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1), colors: const [cyan, purple, pink]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: StatTile(Icons.location_on, cyan, w.km.toStringAsFixed(2), 'km')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(Icons.timer_outlined, blue, fmt(w.secs), 'Tiempo')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(Icons.local_fire_department, orange, '${w.cal}', 'kcal')),
            ]),
            const SizedBox(height: 24),
            const Text('"Pequeños pasos,\ngrandes logros"', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontStyle: FontStyle.italic, color: soft)),
            const SizedBox(height: 36),
            GradBtn('Ver detalle', () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => DetailPage(w))), icon: Icons.map_outlined),
            const SizedBox(height: 14),
            OutlineBtn('Volver al inicio', () {
              tab.value = 0;
              goRoot(c, const Shell());
            }, icon: Icons.home_rounded),
          ]),
        ),
      ),
    ),
  );
}

// ======================= MAPA EN TIEMPO REAL =======================
class MapPage extends StatefulWidget {
  final List<LatLng> route;
  const MapPage({super.key, this.route = const []});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  final ctl = MapController();
  Position? pos;
  double heading = 0, walked = 0;
  final trail = <LatLng>[];
  StreamSubscription<Position>? sub;
  StreamSubscription? comp;
  DateTime? lastFix;
  Timer? clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    // Refresca el "hace X s" del último dato GPS.
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _start() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) snack(context, 'Activa el permiso de ubicación para ver el mapa en vivo');
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) snack(context, 'Enciende el GPS (ubicación) de tu teléfono');
    }
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && pos == null && mounted) setState(() => pos = last);
    } catch (_) {}
    try {
      sub = Geolocator.getPositionStream(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(accuracy: S.saver ? LocationAccuracy.medium : LocationAccuracy.best, distanceFilter: 0, intervalDuration: Duration(milliseconds: S.saver ? 4000 : 1000))
            : LocationSettings(accuracy: S.saver ? LocationAccuracy.medium : LocationAccuracy.best, distanceFilter: 0),
      ).listen((p) {
        if (!mounted) return;
        setState(() {
          pos = p;
          lastFix = DateTime.now();
          final ll = LatLng(p.latitude, p.longitude);
          if (p.accuracy <= 25) {
            if (trail.isEmpty) {
              trail.add(ll);
            } else {
              final d = Geolocator.distanceBetween(trail.last.latitude, trail.last.longitude, ll.latitude, ll.longitude);
              if (d >= 2) {
                walked += d;
                trail.add(ll);
              }
            }
          }
          if (p.speed > .5 && p.heading >= 0) heading = p.heading;
        });
      }, onError: (_) {});
    } catch (_) {}
    try {
      comp = FlutterCompass.events?.listen((e) {
        if (mounted && (pos?.speed ?? 0) <= .5 && e.heading != null) setState(() => heading = e.heading!);
      }, onError: (_) {});
    } catch (_) {}
  }

  void _stop() {
    sub?.cancel();
    comp?.cancel();
    sub = null;
    comp = null;
  }

  // Batería: el GPS se libera al mandar la app a segundo plano.
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused) _stop();
    if (st == AppLifecycleState.resumed && sub == null) _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock?.cancel();
    _stop();
    super.dispose();
  }

  Widget fab(IconData i, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(onTap: f, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bg.withOpacity(.85), shape: BoxShape.circle, border: Border.all(color: purple)), child: Icon(i))),
  );

  Widget info(IconData i, Color col, String v, String l) => Expanded(
    child: Column(children: [
      glowIcon(i, 22, c: col),
      const SizedBox(height: 2),
      FittedBox(child: Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
      Text(l, style: const TextStyle(color: soft, fontSize: 11)),
    ]),
  );

  @override
  Widget build(BuildContext c) {
    final ll = pos == null ? null : LatLng(pos!.latitude, pos!.longitude);
    final session = S.session;
    // Prioridad: ruta del entrenamiento en curso → ruta en vivo de esta pantalla → ruta pedida.
    final route = session != null && session.route.length > 1 ? session.route : (trail.length > 1 ? trail : widget.route);
    final ago = lastFix == null ? null : DateTime.now().difference(lastFix!).inSeconds;
    return Scaffold(
      body: NeonBg(
        waves: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: [
              const TopBar('Mapa en Tiempo Real'),
              Expanded(
                child: Stack(children: [
                  Positioned.fill(child: LiveMap(ctl: ctl, pos: ll, route: route, heading: heading, accuracy: pos?.accuracy ?? 0, live: true)),
                  Positioned(right: 10, bottom: 84, child: Column(children: [
                    fab(Icons.add, () => ctl.move(ctl.camera.center, ctl.camera.zoom + 1)),
                    fab(Icons.remove, () => ctl.move(ctl.camera.center, ctl.camera.zoom - 1)),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),
              Glass(
                child: Column(children: [
                  Row(children: [
                    glowIcon(Icons.location_on, 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Ubicación actual', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(pos == null ? 'Buscando señal GPS…' : '${pos!.latitude.toStringAsFixed(5)}, ${pos!.longitude.toStringAsFixed(5)}', style: const TextStyle(color: soft)),
                      ]),
                    ),
                    if (ago != null) Dot(ago <= 3 ? 'En vivo' : 'hace ${ago}s', col: ago <= 3 ? green : orange),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    info(Icons.speed, cyan, '${((pos?.speed ?? 0).clamp(0, 100) * 3.6).toStringAsFixed(1)}', 'km/h'),
                    info(Icons.gps_fixed, green, '±${pos?.accuracy.round() ?? '--'} m', 'Precisión'),
                    info(Icons.terrain, purple, '${pos?.altitude.round() ?? '--'} m', 'Altitud'),
                    info(Icons.route, lime, walked >= 1000 ? '${(walked / 1000).toStringAsFixed(2)} km' : '${walked.round()} m', 'Recorrido'),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ======================= SENSORES =======================
class SensorsTab extends StatefulWidget {
  const SensorsTab({super.key});
  @override
  State<SensorsTab> createState() => _SensorsTabState();
}

class _SensorsTabState extends State<SensorsTab> with WidgetsBindingObserver {
  final mo = Motion();
  int view = 0;
  bool? bio;
  Position? pos;
  StreamSubscription<Position>? sub;

  @override
  void initState() {
    super.initState();
    mo.start();
    WidgetsBinding.instance.addObserver(this);
    S.bioAvailable().then((v) {
      if (mounted) setState(() => bio = v);
    });
    _gps();
  }

  // GPS: se libera al pausar la app y se reanuda al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused) {
      sub?.cancel();
      sub = null;
    }
    if (st == AppLifecycleState.resumed && sub == null) _gps();
  }

  void _gps() {
    Geolocator.checkPermission().then((p) {
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      try {
        sub = Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: S.saver ? LocationAccuracy.medium : LocationAccuracy.high, distanceFilter: 5)).listen((v) {
          if (mounted) setState(() => pos = v);
        }, onError: (_) {});
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    mo.dispose();
    sub?.cancel();
    super.dispose();
  }

  Widget seg(String t, int k) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => view = k),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: card2,
          border: Border.all(color: view == k ? lime : purple.withOpacity(.4), width: view == k ? 2 : 1),
          boxShadow: view == k ? [BoxShadow(color: lime.withOpacity(.45), blurRadius: 14)] : null,
        ),
        child: Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: view == k ? lime : Colors.white)),
      ),
    ),
  );

  Widget sensor(IconData i, Color col, String t, Widget body, {String? status, Color sc = green, Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Glass(
      r: 22,
      p: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        SizedBox(width: 64, child: Center(child: glowIcon(i, 50, c: col))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              if (status != null) Dot(status, col: sc),
            ]),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: body), if (trailing != null) trailing]),
          ]),
        ),
      ]),
    ),
  );

  Widget xyz(List<double> v, String u) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text('X: ${v[0].toStringAsFixed(2)} $u    Y: ${v[1].toStringAsFixed(2)} $u    Z: ${v[2].toStringAsFixed(2)} $u', style: const TextStyle(fontSize: 16)),
  );

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: Listenable.merge([mo, S]),
    builder: (_, __) {
      final steps = S.todaySteps;
      final h = (mo.heading + 360) % 360;
      final dir = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'][((h + 22.5) ~/ 45) % 8];
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => tab.value = 0),
          const Expanded(child: Center(child: Text('Sensores', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)))),
          IconButton(icon: glowIcon(Icons.bar_chart_rounded, 30), onPressed: () => setState(() => view = 1)),
        ]),
        const SizedBox(height: 8),
        Row(children: [seg('En Tiempo Real', 0), const SizedBox(width: 10), seg('Gráficas', 1)]),
        const SizedBox(height: 14),
        if (view == 0) ...[
          sensor(Icons.fingerprint, cyan, 'Autenticación Biométrica',
              Text(bio == null ? 'Comprobando…' : (bio! ? 'Huella disponible en este dispositivo' : 'Sin huella configurada en el teléfono'), style: const TextStyle(color: soft, fontSize: 14)),
              status: bio == false ? 'Inactivo' : 'Activo',
              sc: bio == false ? orange : green,
              trailing: bio == true ? const Icon(Icons.check_circle_outline, color: green, size: 30) : null),
          sensor(Icons.directions_run, cyan, 'Podómetro',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fnum(steps), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)), const Text('Pasos', style: TextStyle(color: soft))]),
              status: S.stepsOk == false ? 'Sin permiso/sensor' : (S.stepsOk == true ? 'Activo' : 'Esperando'),
              sc: S.stepsOk == true ? green : orange,
              trailing: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var k = 0; k < 7; k++)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 10,
                    height: 14.0 + 6 * k,
                    decoration: BoxDecoration(color: k / 7 < (steps / AppState.stepGoal) ? cyan : const Color(0xFF1E2A6A), borderRadius: BorderRadius.circular(2), boxShadow: k / 7 < (steps / AppState.stepGoal) ? [BoxShadow(color: cyan.withOpacity(.6), blurRadius: 8)] : null),
                  ),
              ])),
          sensor(Icons.open_with, purple, 'Acelerómetro', mo.hasAcc || !mo.checked ? xyz(mo.ag, 'g') : const Text('Este dispositivo no tiene acelerómetro', style: TextStyle(color: soft)),
              status: mo.hasAcc ? 'Activo' : (mo.checked ? 'No disponible' : 'Esperando'), sc: mo.hasAcc ? green : orange),
          sensor(
              Icons.threesixty,
              pink,
              'Giroscopio',
              mo.hasGyro || !mo.checked
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      xyz(mo.gd, '°/s'),
                      const SizedBox(height: 4),
                      Text('Inclinación: ${mo.pitch.round()}° adelante · ${mo.roll.round()}° lateral${mo.turning ? '  ·  ¡Girando!' : ''}', style: TextStyle(color: mo.turning ? lime : soft, fontSize: 13)),
                    ])
                  : const Text('Este dispositivo no tiene giroscopio', style: TextStyle(color: soft)),
              status: mo.hasGyro ? 'Activo' : (mo.checked ? 'No disponible' : 'Esperando'),
              sc: mo.hasGyro ? green : orange),
          sensor(Icons.location_on, blue, 'GPS',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pos == null ? 'Buscando señal…' : '${pos!.latitude.toStringAsFixed(4)}, ${pos!.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 16)),
                Text(pos == null ? 'Activa la ubicación' : 'Precisión: ${pos!.accuracy.round()} m', style: const TextStyle(color: soft)),
              ]),
              status: pos == null ? 'Esperando' : 'Activo',
              sc: pos == null ? orange : green,
              trailing: IconButton(icon: glowIcon(Icons.map_outlined, 30, c: blue), onPressed: () => go(c, const MapPage()))),
          Glass(
            r: 22,
            p: const EdgeInsets.fromLTRB(4, 6, 14, 6),
            child: Row(children: [
              PulseBot(size: 62, mode: botFromState(mo.state)),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Estado del Movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: green.withOpacity(.15), border: Border.all(color: green, width: 1.5), boxShadow: [BoxShadow(color: green.withOpacity(.4), blurRadius: 10)]),
                  child: Text(mo.state, style: const TextStyle(fontSize: 18, color: lime, fontWeight: FontWeight.w700)),
                ),
              ]),
              const Spacer(),
              LevelBars(mo.level, w: 12, h: 40),
            ]),
          ),
        ] else ...[
          for (final e in [('Acelerómetro', Icons.open_with, purple, mo.ab), ('Giroscopio', Icons.threesixty, pink, mo.gb)])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Glass(
                r: 22,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [glowIcon(e.$2, 26, c: e.$3), const SizedBox(width: 10), Text(e.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const Spacer(), const Dot('En vivo')]),
                  const SizedBox(height: 12),
                  SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: LinePainter(e.$4, e.$3))),
                ]),
              ),
            ),
          Glass(
            r: 22,
            child: Row(children: [
              Transform.rotate(angle: -h * m.pi / 180, child: glowIcon(Icons.explore, 60)),
              const SizedBox(width: 16),
              const Text('Orientación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$dir ${h.round()}°', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: cyan)),
            ]),
          ),
          const SizedBox(height: 12),
          Glass(
            r: 22,
            border: const [green, cyan],
            child: Row(children: [
              glowIcon(Icons.eco, 30, c: green),
              const SizedBox(width: 12),
              Expanded(child: Text(S.saver ? 'Modo ahorro: sensores a 1 Hz' : 'Sensores a máxima frecuencia', style: const TextStyle(fontSize: 15))),
            ]),
          ),
        ],
        const SizedBox(height: 110),
      ]);
    },
  );
}

// ======================= HISTORIAL =======================
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  int f = 0;
  DateTime? day;
  int shown = 10;

  static const filters = [(Icons.directions_run, 'Todas'), (Icons.directions_walk, 'Caminatas'), (Icons.run_circle_outlined, 'Carreras'), (Icons.emoji_events_outlined, 'Entrenamientos')];

  bool pass(Workout w) {
    if (day != null && !(w.date.year == day!.year && w.date.month == day!.month && w.date.day == day!.day)) return false;
    return switch (f) { 1 => w.type == 'Caminata', 2 => w.type == 'Trote', 3 => w.secs >= 15 * 60, _ => true };
  }

  Future<void> pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: day ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: purple, surface: card2)), child: child!),
    );
    setState(() => day = d);
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: S,
    builder: (_, __) {
      final all = S.history.where(pass).toList();
      final km = all.fold(0.0, (a, w) => a + w.km), cal = all.fold(0, (a, w) => a + w.cal);
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => tab.value = 0),
          const Expanded(child: Center(child: Text('Historial', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)))),
          IconButton(icon: Icon(Icons.calendar_month_outlined, size: 30, color: day == null ? Colors.white : lime), onPressed: pickDay),
        ]),
        if (day != null)
          Center(child: InputChip(label: Text('${two(day!.day)}/${two(day!.month)}/${day!.year}'), onDeleted: () => setState(() => day = null), backgroundColor: card2, side: const BorderSide(color: lime))),
        const SizedBox(height: 8),
        Row(children: [
          for (var k = 0; k < filters.length; k++) ...[
            if (k > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => f = k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: f == k ? const Color(0xFF16301A) : card2,
                    border: Border.all(color: f == k ? lime : purple.withOpacity(.35), width: f == k ? 2 : 1),
                    boxShadow: f == k ? [BoxShadow(color: lime.withOpacity(.45), blurRadius: 14)] : null,
                  ),
                  child: Column(children: [
                    Icon(filters[k].$1, color: f == k ? lime : Colors.white),
                    const SizedBox(height: 4),
                    FittedBox(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(filters[k].$2, style: TextStyle(color: f == k ? lime : Colors.white, fontSize: 13)))),
                  ]),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatTile(Icons.directions_run, cyan, '${all.length}', 'Entrenamientos')),
          const SizedBox(width: 8),
          Expanded(child: StatTile(Icons.location_on, cyan, '${km.toStringAsFixed(1)} km', 'Distancia Total')),
          const SizedBox(width: 8),
          Expanded(child: StatTile(Icons.local_fire_department, orange, fnum(cal), 'Calorías')),
        ]),
        const SizedBox(height: 12),
        if (all.isEmpty)
          Glass(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                glowIcon(Icons.directions_run, 60, c: purple),
                const SizedBox(height: 10),
                const Text('Aún no hay entrenamientos aquí.\n¡Inicia el primero!', textAlign: TextAlign.center, style: TextStyle(color: soft, fontSize: 16)),
                const SizedBox(height: 14),
                GradBtn('Iniciar Entrenamiento', () => go(c, const WorkoutPage()), icon: Icons.play_arrow_rounded, h: 50, fs: 17),
              ]),
            ),
          ),
        for (final w in all.take(shown))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Glass(
                r: 16,
                p: EdgeInsets.zero,
                child: ClipRRect(borderRadius: BorderRadius.circular(15), child: SizedBox(width: 120, height: 92, child: CustomPaint(painter: RouteThumbPainter([for (final p in w.route) (p.latitude, p.longitude)])))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Glass(
                  r: 16,
                  onTap: () => go(c, DetailPage(w)),
                  p: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: SizedBox(
                    height: 70,
                    child: Row(children: [
                      glowIcon(w.type == 'Trote' ? Icons.directions_run : Icons.directions_walk, 30, c: green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FittedBox(fit: BoxFit.scaleDown, child: Text(fdate(w.date), style: const TextStyle(color: soft, fontSize: 13))),
                          const SizedBox(height: 4),
                          Text('${w.km.toStringAsFixed(1)} km · ${(w.secs / 60).round()} min', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          Text('${fnum(w.steps)} pasos', style: const TextStyle(fontSize: 14)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: cyan, size: 30),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        if (all.length > shown) Center(child: TextButton(onPressed: () => setState(() => shown += 10), child: const Text('Ver más  ⌄'))),
        const SizedBox(height: 6),
        Center(child: SizedBox(width: 300, child: GradBtn('Ver Mapa Completo', () => go(c, MapPage(route: all.firstOrNull?.route ?? const [])), icon: Icons.bar_chart_rounded, h: 54, fs: 18))),
        const SizedBox(height: 120),
      ]);
    },
  );
}

class DetailPage extends StatelessWidget {
  final Workout w;
  const DetailPage(this.w, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      waves: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            TopBar(
              w.type,
              right: IconButton(
                icon: const Icon(Icons.delete_outline, color: red),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: c,
                    builder: (d) => AlertDialog(
                      title: const Text('Eliminar entrenamiento'),
                      content: const Text('Esta acción no se puede deshacer.', style: TextStyle(color: soft)),
                      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Eliminar', style: TextStyle(color: red)))],
                    ),
                  );
                  if (ok == true) {
                    S.removeWorkout(w);
                    if (c.mounted) Navigator.pop(c);
                  }
                },
              ),
            ),
            Text(fdate(w.date), style: const TextStyle(color: soft)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: StatTile(Icons.timer_outlined, blue, fmt(w.secs), 'Tiempo')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(Icons.location_on, cyan, w.km.toStringAsFixed(2), 'km')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(Icons.directions_run, cyan, fnum(w.steps), 'Pasos')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(Icons.local_fire_department, orange, '${w.cal}', 'kcal')),
            ]),
            const SizedBox(height: 12),
            Expanded(child: w.route.length > 1 ? LiveMap(route: w.route) : Glass(child: Center(child: Text('Este entrenamiento no tiene ruta GPS', style: TextStyle(color: soft.withOpacity(.8)))))),
          ]),
        ),
      ),
    ),
  );
}
