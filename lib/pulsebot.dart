import 'dart:math' as m;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'ui.dart';

/// Estados del avatar: quieto (saluda), caminando, corriendo o feliz (celebra).
enum BotMode { idle, walk, run, happy }

BotMode botFromState(String s) => switch (s) { 'Caminata' => BotMode.walk, 'Trote' || 'Carrera' => BotMode.run, _ => BotMode.idle };

/// PulseBot: avatar animado dibujado 100 % con código (sin imágenes ni paquetes extra).
/// Se balancea, parpadea, mira a los lados, saluda, camina o corre según [mode]
/// y da un salto de alegría al tocarlo.
class PulseBot extends StatefulWidget {
  final double size;
  final BotMode mode;
  final VoidCallback? onTap;
  const PulseBot({super.key, this.size = 120, this.mode = BotMode.idle, this.onTap});
  @override
  State<PulseBot> createState() => _PulseBotState();
}

class _PulseBotState extends State<PulseBot> with SingleTickerProviderStateMixin {
  final t = ValueNotifier<double>(0);
  late final Ticker ticker;
  double jumpAt = -10;

  @override
  void initState() {
    super.initState();
    ticker = createTicker((d) => t.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    ticker.dispose(); // libera la animación al salir de la pantalla
    t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => GestureDetector(
    onTap: () {
      jumpAt = t.value;
      widget.onTap?.call();
    },
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size, widget.size * 1.3),
        painter: _BotPainter(t, widget.mode, () => jumpAt),
      ),
    ),
  );
}

class _BotPainter extends CustomPainter {
  final ValueNotifier<double> t;
  final BotMode mode;
  final double Function() jumpAt;
  _BotPainter(this.t, this.mode, this.jumpAt) : super(repaint: t);

  @override
  void paint(Canvas cv, Size s) {
    final u = s.width / 100, time = t.value, cx = 50 * u;
    final sinceJump = time - jumpAt();
    final jumping = sinceJump >= 0 && sinceJump < .7;
    final m0 = jumping ? BotMode.happy : mode;

    final freq = switch (m0) { BotMode.idle => .55, BotMode.walk => 1.5, BotMode.run => 2.6, BotMode.happy => 1.3 };
    final ph = time * freq * 2 * m.pi;
    final amp = switch (m0) { BotMode.idle => 2.0, BotMode.walk => 3.0, BotMode.run => 5.0, BotMode.happy => 3.0 } * u;
    var bob = (m0 == BotMode.idle ? m.sin(ph) : -m.sin(ph * 2).abs()) * amp;
    if (jumping) bob -= m.sin(m.pi * sinceJump / .7) * 20 * u;
    final lean = m0 == BotMode.run ? .12 : (m0 == BotMode.walk ? .05 : 0.0);

    // ---- Sombra en el piso
    final lift = (-bob / (24 * u)).clamp(0.0, 1.0);
    cv.drawOval(Rect.fromCenter(center: Offset(cx, 124 * u), width: 52 * u * (1 - .45 * lift), height: 8 * u * (1 - .4 * lift)),
        Paint()..color = purple.withOpacity(.45 - .25 * lift)..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * u));

    // ---- Líneas de velocidad al correr
    if (m0 == BotMode.run) {
      final sp = Paint()..color = cyan.withOpacity(.5)..strokeWidth = 1.6 * u..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final y = (60 + i * 14) * u, off = ((time * 3 + i * .33) % 1) * 14 * u;
        cv.drawLine(Offset(8 * u - off, y), Offset(20 * u - off, y), sp);
      }
    }

    cv.save();
    cv.translate(cx, 120 * u);
    cv.rotate(lean + (m0 == BotMode.idle ? m.sin(ph) * .03 : 0));
    cv.translate(-cx, -120 * u);

    // ---- Piernas
    final legAmp = switch (m0) { BotMode.walk => .5, BotMode.run => .9, _ => 0.0 };
    final legPaint = Paint()..strokeCap = StrokeCap.round..strokeWidth = 8 * u..shader = const LinearGradient(colors: [Color(0xFFD9D4FF), Color(0xFF8C82D9)]).createShader(Rect.fromLTWH(0, 90 * u, s.width, 34 * u));
    for (final side in [-1, 1]) {
      final hip = Offset(cx + side * 8 * u, 95 * u + bob);
      final a = side * m.sin(ph) * legAmp;
      final foot = hip + Offset(m.sin(a) * 22 * u, m.cos(a) * 22 * u);
      cv.drawLine(hip, foot, legPaint);
      cv.drawOval(Rect.fromCenter(center: foot + Offset(2 * u, 2 * u), width: 13 * u, height: 7 * u), Paint()..color = const Color(0xFF2A2460));
      cv.drawOval(Rect.fromCenter(center: foot + Offset(2 * u, 2 * u), width: 13 * u, height: 7 * u), Paint()..color = cyan..style = PaintingStyle.stroke..strokeWidth = 1.2 * u);
    }

    // ---- Brazos
    final armPaint = Paint()..strokeCap = StrokeCap.round..strokeWidth = 7 * u..color = const Color(0xFFCFC8FF);
    for (final side in [-1, 1]) {
      final sh = Offset(cx + side * 19 * u, 74 * u + bob);
      double a;
      if (m0 == BotMode.idle && side == 1) {
        a = 2.55 + m.sin(time * 2 * m.pi * 1.4) * .45; // saludando
      } else if (m0 == BotMode.happy) {
        a = side * (2.5 + m.sin(time * 2 * m.pi * 2.2) * .35); // brazos arriba celebrando
      } else if (m0 == BotMode.walk || m0 == BotMode.run) {
        a = -side * m.sin(ph) * (m0 == BotMode.run ? 1.1 : .6) + side * .15;
      } else {
        a = side * .25;
      }
      final hand = sh + Offset(m.sin(a) * 22 * u, m.cos(a) * 22 * u);
      cv.drawLine(sh, hand, armPaint);
      cv.drawCircle(hand, 5 * u, Paint()..color = Colors.white);
      cv.drawCircle(hand, 5 * u, Paint()..color = cyan.withOpacity(.6)..style = PaintingStyle.stroke..strokeWidth = 1.2 * u);
    }

    // ---- Cuerpo
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, 82 * u + bob), width: 40 * u, height: 30 * u), Radius.circular(12 * u));
    cv.drawRRect(body.inflate(2 * u), Paint()..color = purple.withOpacity(.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * u));
    cv.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2163), Color(0xFF0B0A20)]).createShader(body.outerRect));
    cv.drawRRect(body, Paint()..color = purple..style = PaintingStyle.stroke..strokeWidth = 1.6 * u);
    final tp = TextPainter(
      text: TextSpan(text: 'P', style: TextStyle(fontSize: 17 * u, fontWeight: FontWeight.w900, color: cyan, shadows: [Shadow(color: cyan, blurRadius: 8 * u)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(cv, Offset(cx - tp.width / 2, 82 * u + bob - tp.height / 2));

    // ---- Cabeza
    final hy = 42 * u + bob * 1.1;
    // antena con luz pulsante
    final glowA = .5 + .5 * m.sin(time * 4);
    cv.drawLine(Offset(cx, hy - 22 * u), Offset(cx, hy - 32 * u), Paint()..color = const Color(0xFFCFC8FF)..strokeWidth = 2 * u);
    cv.drawCircle(Offset(cx, hy - 34 * u), 4.5 * u, Paint()..color = pink.withOpacity(.4 + .4 * glowA)..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * u));
    cv.drawCircle(Offset(cx, hy - 34 * u), 3 * u, Paint()..color = pink);

    // audífonos
    for (final side in [-1, 1]) {
      final c0 = Offset(cx + side * 30 * u, hy + 2 * u);
      cv.drawCircle(c0, 10 * u, Paint()..color = cyan.withOpacity(.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * u));
      cv.drawCircle(c0, 9 * u, Paint()..color = const Color(0xFF2A2460));
      cv.drawCircle(c0, 9 * u, Paint()..color = cyan..style = PaintingStyle.stroke..strokeWidth = 2 * u);
      cv.drawCircle(c0, 4 * u, Paint()..color = purple);
    }

    final head = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, hy), width: 58 * u, height: 46 * u), Radius.circular(22 * u));
    cv.drawRRect(head.inflate(1.5 * u), Paint()..color = cyan.withOpacity(.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * u));
    cv.drawRRect(head, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFD6D0FF), Color(0xFF9A8FE8)]).createShader(head.outerRect));

    // visor
    final visor = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, hy + 1 * u), width: 46 * u, height: 30 * u), Radius.circular(14 * u));
    cv.drawRRect(visor, Paint()..color = const Color(0xFF05040F));
    cv.drawRRect(visor, Paint()..color = purple.withOpacity(.6)..style = PaintingStyle.stroke..strokeWidth = 1 * u);

    // ojos: parpadeo cada ~3.2 s, miran a los lados; felices = ^ ^
    final look = m0 == BotMode.idle ? m.sin(time * .9) * 2.5 * u : 1.5 * u;
    final cyc = time % 3.2, blink = cyc < .14 ? (1 - m.sin(cyc / .14 * m.pi)) : 1.0;
    final eyeGlow = Paint()..color = cyan.withOpacity(.7)..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * u);
    for (final side in [-1, 1]) {
      final e = Offset(cx + side * 10 * u + look, hy - 2 * u);
      if (m0 == BotMode.happy || m0 == BotMode.run) {
        final arc = Path()..addArc(Rect.fromCenter(center: e + Offset(0, 2 * u), width: 10 * u, height: 9 * u), m.pi, m.pi);
        cv.drawPath(arc, eyeGlow..style = PaintingStyle.stroke..strokeWidth = 4 * u);
        cv.drawPath(arc, Paint()..color = cyan..style = PaintingStyle.stroke..strokeWidth = 2.6 * u..strokeCap = StrokeCap.round);
      } else {
        final r = Rect.fromCenter(center: e, width: 7 * u, height: 10 * u * blink.clamp(.08, 1.0));
        cv.drawOval(r.inflate(1.5 * u), eyeGlow);
        cv.drawOval(r, Paint()..color = cyan);
      }
    }

    // boca
    final mouth = Rect.fromCenter(center: Offset(cx + look * .5, hy + 7 * u), width: m0 == BotMode.happy ? 14 * u : 11 * u, height: m0 == BotMode.happy ? 10 * u : 6 * u);
    if (m0 == BotMode.happy) {
      cv.drawArc(mouth, 0, m.pi, true, Paint()..color = cyan);
    } else {
      cv.drawArc(mouth, .2, m.pi - .4, false, Paint()..color = cyan..style = PaintingStyle.stroke..strokeWidth = 2.4 * u..strokeCap = StrokeCap.round);
    }
    cv.restore();

    // ---- Destellos al celebrar
    if (m0 == BotMode.happy) {
      for (var i = 0; i < 5; i++) {
        final ang = time * 1.5 + i * 2 * m.pi / 5, rr = 46 * u;
        final p = Offset(cx + m.cos(ang) * rr, 60 * u + m.sin(ang) * rr * .7 + bob);
        final sz = (1.5 + m.sin(time * 6 + i)) * u + 2 * u;
        _star(cv, p, sz, i.isEven ? cyan : pink);
      }
    }
  }

  void _star(Canvas cv, Offset c, double r, Color col) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2);
    cv.drawPath(p, Paint()..color = col..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .6));
    cv.drawPath(p, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_BotPainter o) => o.mode != mode;
}

/// Tarjeta con PulseBot y un globo de diálogo (consejos que cambian al tocarlo).
class BotCard extends StatefulWidget {
  final List<String> tips;
  final BotMode mode;
  const BotCard({super.key, required this.tips, this.mode = BotMode.idle});
  @override
  State<BotCard> createState() => _BotCardState();
}

class _BotCardState extends State<BotCard> {
  int i = 0;
  @override
  Widget build(BuildContext c) => Glass(
    r: 24,
    border: const [pink, purple, cyan],
    p: const EdgeInsets.fromLTRB(6, 8, 14, 8),
    child: Row(children: [
      PulseBot(size: 96, mode: widget.mode, onTap: () => setState(() => i = (i + 1) % widget.tips.length)),
      const SizedBox(width: 8),
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => i = (i + 1) % widget.tips.length),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GradText('PulseBot', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic), colors: const [cyan, pink]),
              const SizedBox(width: 6),
              const Dot('en línea'),
            ]),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (w, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.1, 0), end: Offset.zero).animate(a), child: w)),
              child: Text(widget.tips[i], key: ValueKey(i), style: const TextStyle(fontSize: 14.5, height: 1.3)),
            ),
            const SizedBox(height: 4),
            const Text('Toca para otro consejo', style: TextStyle(color: soft, fontSize: 11)),
          ]),
        ),
      ),
    ]),
  );
}
