import 'dart:math' as m;
import 'package:material_ui/material_ui.dart';

// ======================= PALETA NEÓN PULSEX =======================
const bg = Color(0xFF04030C);
const card = Color(0xFF0B0A1F);
const card2 = Color(0xFF12103A);
const pink = Color(0xFFE040FB);
const purple = Color(0xFF7C3CFF);
const blue = Color(0xFF3D5BFF);
const cyan = Color(0xFF00E5FF);
const lime = Color(0xFFC6FF1A);
const green = Color(0xFF39FF88);
const orange = Color(0xFFFF7A1A);
const red = Color(0xFFFF2D55);
const soft = Color(0xFFB9B6D9);

const gMain = [pink, purple, cyan];
const gBorder = [purple, blue, cyan];

ThemeData pulseTheme() => ThemeData.dark().copyWith(
  scaffoldBackgroundColor: bg,
  colorScheme: const ColorScheme.dark(primary: cyan, secondary: purple, surface: card),
  dialogTheme: DialogThemeData(
    backgroundColor: card2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: purple)),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: card2,
    behavior: SnackBarBehavior.floating,
    contentTextStyle: const TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: purple)),
  ),
  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: cyan)),
);

// ======================= UTILIDADES =======================
void go(BuildContext c, Widget w) => Navigator.push(c, _fade(w));
void goRoot(BuildContext c, Widget w) => Navigator.pushAndRemoveUntil(c, _fade(w), (_) => false);
Route _fade(Widget w) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 350),
  pageBuilder: (_, __, ___) => w,
  transitionsBuilder: (_, a, __, child) => FadeTransition(
    opacity: a,
    child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: child),
  ),
);
void snack(BuildContext c, String t) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(t)));
String two(int n) => n.toString().padLeft(2, '0');
String fmt(int s) => '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
String fnum(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (x) => '${x[1]},');
const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
String fdate(DateTime d) =>
    '${_dias[d.weekday - 1]}, ${d.day} ${_meses[d.month - 1]} ${d.year} · ${two(d.hour % 12 == 0 ? 12 : d.hour % 12)}:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
String dayShort(int weekday) => _dias[weekday - 1];

// ======================= FONDO NEÓN =======================
class NeonBg extends StatelessWidget {
  final Widget child;
  final bool waves;
  const NeonBg({super.key, required this.child, this.waves = true});
  @override
  Widget build(BuildContext c) => Stack(children: [
    Positioned.fill(child: Container(color: bg)),
    Positioned(top: -140, left: -120, child: _glow(purple, 360, .35)),
    Positioned(top: 120, right: -160, child: _glow(cyan, 320, .18)),
    Positioned(bottom: -160, left: 40, child: _glow(pink, 360, .22)),
    if (waves) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: WavePainter()))),
    Positioned.fill(child: child),
  ]);

  Widget _glow(Color col, double s, double o) => Container(
    width: s,
    height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [col.withOpacity(o), col.withOpacity(0)])),
  );
}

/// Ondas de luz en la parte inferior (como en el diseño).
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas cv, Size s) {
    void wave(double y, double amp, Color col, double w, double shift) {
      final p = Path()..moveTo(0, y);
      p.cubicTo(s.width * .3, y - amp + shift, s.width * .6, y + amp, s.width, y - amp * .6);
      cv.drawPath(p, Paint()..color = col.withOpacity(.55)..style = PaintingStyle.stroke..strokeWidth = w * 3..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      cv.drawPath(p, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = w);
    }

    wave(s.height - 40, 40, purple, 1.4, 0);
    wave(s.height - 22, 30, cyan, 1.2, 14);
    wave(s.height - 8, 24, pink, 1, -10);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Línea de pulso (electrocardiograma) neón.
class PulseLine extends StatelessWidget {
  final double width, height;
  final List<Color> colors;
  const PulseLine({super.key, this.width = 220, this.height = 46, this.colors = const [purple, pink, cyan]});
  @override
  Widget build(BuildContext c) => CustomPaint(size: Size(width, height), painter: _PulsePainter(colors));
}

class _PulsePainter extends CustomPainter {
  final List<Color> colors;
  _PulsePainter(this.colors);
  @override
  void paint(Canvas cv, Size s) {
    final h = s.height, w = s.width, mid = h * .6;
    final p = Path()
      ..moveTo(0, mid)
      ..lineTo(w * .38, mid)
      ..lineTo(w * .44, mid - h * .35)
      ..lineTo(w * .5, h * .02)
      ..lineTo(w * .56, h * .98)
      ..lineTo(w * .62, mid - h * .2)
      ..lineTo(w * .66, mid)
      ..lineTo(w, mid);
    final sh = LinearGradient(colors: colors).createShader(Offset.zero & s);
    cv.drawPath(p, Paint()..shader = sh..style = PaintingStyle.stroke..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    cv.drawPath(p, Paint()..shader = sh..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ======================= TIPOGRAFÍA =======================
class GradText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  const GradText(this.text, {super.key, required this.style, this.colors = const [cyan, purple]});
  @override
  Widget build(BuildContext c) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => LinearGradient(colors: colors).createShader(r),
    child: Text(text, style: style.copyWith(shadows: [Shadow(color: colors.first.withOpacity(.6), blurRadius: 18)])),
  );
}

class PulseLogo extends StatelessWidget {
  final double size;
  const PulseLogo({super.key, this.size = 40});
  @override
  Widget build(BuildContext c) {
    final st = TextStyle(fontSize: size, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -1, height: 1);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Pulse', style: st.copyWith(color: Colors.white, shadows: [Shadow(color: purple.withOpacity(.8), blurRadius: 16)])),
      GradText('X', style: st, colors: const [cyan, purple]),
    ]);
  }
}

// ======================= TARJETAS =======================
/// Tarjeta de vidrio con borde degradado y resplandor.
class Glass extends StatelessWidget {
  final Widget child;
  final double r;
  final EdgeInsets p;
  final List<Color> border;
  final Color? fill;
  final bool glow;
  final VoidCallback? onTap;
  const Glass({super.key, required this.child, this.r = 20, this.p = const EdgeInsets.all(14), this.border = gBorder, this.fill, this.glow = true, this.onTap});

  @override
  Widget build(BuildContext c) {
    final box = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: LinearGradient(colors: border, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: glow ? [BoxShadow(color: border.first.withOpacity(.28), blurRadius: 18, spreadRadius: -2), BoxShadow(color: border.last.withOpacity(.18), blurRadius: 22, offset: const Offset(4, 6))] : null,
      ),
      padding: const EdgeInsets.all(1.3),
      child: Container(
        padding: p,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r - 1.3),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [fill ?? card2.withOpacity(.95), (fill ?? card).withOpacity(.97)]),
        ),
        child: child,
      ),
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

// ======================= BOTONES =======================
class GradBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;
  final List<Color> colors;
  final double h, fs;
  final bool busy;
  const GradBtn(this.label, this.onTap, {super.key, this.icon, this.leading, this.colors = gMain, this.h = 58, this.fs = 20, this.busy = false});
  @override
  State<GradBtn> createState() => _GradBtnState();
}

class _GradBtnState extends State<GradBtn> {
  bool down = false;
  @override
  Widget build(BuildContext c) => GestureDetector(
    onTapDown: (_) => setState(() => down = true),
    onTapCancel: () => setState(() => down = false),
    onTapUp: (_) => setState(() => down = false),
    onTap: widget.busy ? null : widget.onTap,
    child: AnimatedScale(
      scale: down ? .97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        height: widget.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.colors),
          borderRadius: BorderRadius.circular(widget.h / 2),
          border: Border.all(color: Colors.white.withOpacity(.35), width: 1.2),
          boxShadow: [
            BoxShadow(color: widget.colors.first.withOpacity(.55), blurRadius: 22, offset: const Offset(-6, 4)),
            BoxShadow(color: widget.colors.last.withOpacity(.55), blurRadius: 22, offset: const Offset(6, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (widget.busy)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          else ...[
            if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 14)],
            if (widget.icon != null) ...[Icon(widget.icon, size: widget.fs + 6, color: Colors.white), const SizedBox(width: 12)],
            Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: widget.fs, fontWeight: FontWeight.w700, color: Colors.white))),
          ],
        ]),
      ),
    ),
  );
}

class OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final double h, fs;
  final Color? textColor;
  const OutlineBtn(this.label, this.onTap, {super.key, this.icon, this.leading, this.h = 56, this.fs = 18, this.textColor});
  @override
  Widget build(BuildContext c) => Glass(
    r: h / 2,
    p: EdgeInsets.zero,
    fill: bg,
    border: const [pink, purple, cyan],
    onTap: onTap,
    child: SizedBox(
      height: h - 2.6,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        if (icon != null) ...[Icon(icon, color: textColor ?? Colors.white, size: fs + 6), const SizedBox(width: 12)],
        Text(label, style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600, color: textColor ?? Colors.white)),
      ]),
    ),
  );
}

/// Logo "G" de Google dibujado con sus colores.
class GoogleG extends StatelessWidget {
  final double s;
  const GoogleG({super.key, this.s = 30});
  @override
  Widget build(BuildContext c) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => const SweepGradient(colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)], stops: [0, .25, .5, .75, 1]).createShader(r),
    child: Text('G', style: TextStyle(fontSize: s, fontWeight: FontWeight.w900, height: 1)),
  );
}

Widget glowIcon(IconData i, double s, {Color c = cyan}) => Icon(i, size: s, color: c, shadows: [Shadow(color: c, blurRadius: 18), Shadow(color: c.withOpacity(.6), blurRadius: 34)]);

// ======================= CAMPOS DE TEXTO =======================
class NeonField extends StatefulWidget {
  final String hint;
  final IconData icon;
  final TextEditingController ctl;
  final bool pass;
  final TextInputType? type;
  final TextInputAction action;
  const NeonField(this.hint, this.icon, this.ctl, {super.key, this.pass = false, this.type, this.action = TextInputAction.next});
  @override
  State<NeonField> createState() => _NeonFieldState();
}

class _NeonFieldState extends State<NeonField> {
  bool hide = true;
  final f = FocusNode();
  @override
  void initState() {
    super.initState();
    f.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [if (f.hasFocus) BoxShadow(color: cyan.withOpacity(.35), blurRadius: 18)]),
    child: Glass(
      r: 30,
      glow: false,
      border: f.hasFocus ? const [pink, cyan] : const [purple, blue, cyan],
      p: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        focusNode: f,
        controller: widget.ctl,
        obscureText: widget.pass && hide,
        keyboardType: widget.type ?? (widget.pass ? TextInputType.visiblePassword : TextInputType.text),
        textInputAction: widget.action,
        style: const TextStyle(fontSize: 17),
        cursorColor: cyan,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          hintText: widget.hint,
          hintStyle: const TextStyle(color: soft, fontSize: 17),
          prefixIcon: Padding(padding: const EdgeInsets.only(right: 12), child: Icon(widget.icon, color: const Color(0xFFD9D4FF), size: 26)),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: widget.pass
              ? IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFFD9D4FF)), onPressed: () => setState(() => hide = !hide))
              : null,
        ),
      ),
    ),
  );
}

// ======================= AVATAR =======================
class Avatar extends StatelessWidget {
  final String name;
  final String? photo;
  final double size;
  final VoidCallback? onCamera;
  const Avatar({super.key, required this.name, this.photo, this.size = 110, this.onCamera});
  @override
  Widget build(BuildContext c) {
    final ini = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((e) => e[0].toUpperCase()).join();
    return SizedBox(
      width: size + 12,
      height: size + 12,
      child: Stack(children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(colors: [cyan, purple, pink, cyan]),
            boxShadow: [BoxShadow(color: cyan.withOpacity(.5), blurRadius: 24), BoxShadow(color: purple.withOpacity(.5), blurRadius: 30)],
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: card2,
              image: photo != null ? DecorationImage(image: NetworkImage(photo!), fit: BoxFit.cover) : null,
            ),
            alignment: Alignment.center,
            child: photo == null ? GradText(ini, style: TextStyle(fontSize: size * .38, fontWeight: FontWeight.w800), colors: const [cyan, pink]) : null,
          ),
        ),
        if (onCamera != null)
          Positioned(
            right: 0,
            bottom: 2,
            child: GestureDetector(
              onTap: onCamera,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [pink, purple]), border: Border.all(color: Colors.white, width: 1.5), boxShadow: [BoxShadow(color: pink.withOpacity(.6), blurRadius: 12)]),
                child: Icon(Icons.edit, size: size * .16, color: Colors.white),
              ),
            ),
          ),
      ]),
    );
  }
}

// ======================= GRÁFICOS =======================
/// Anillo de progreso con degradado y brillo.
class RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final List<Color> colors;
  RingPainter(this.v, {this.stroke = 14, this.colors = const [purple, blue, cyan, green, lime]});
  @override
  void paint(Canvas cv, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.shortestSide / 2 - stroke);
    cv.drawArc(r, 0, 2 * m.pi, false, Paint()..color = const Color(0xFF1E1B4A)..style = PaintingStyle.stroke..strokeWidth = stroke);
    final val = v.clamp(0.0, 1.0);
    if (val <= 0) return;
    final sh = SweepGradient(colors: colors, transform: const GradientRotation(-m.pi / 2)).createShader(r);
    final sweep = 2 * m.pi * val;
    cv.drawArc(r, -m.pi / 2, sweep, false, Paint()..shader = sh..style = PaintingStyle.stroke..strokeWidth = stroke + 8..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    cv.drawArc(r, -m.pi / 2, sweep, false, Paint()..shader = sh..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(RingPainter o) => o.v != v;
}

/// Barras de nivel (verde → rojo), como "Estado del movimiento".
class LevelBars extends StatelessWidget {
  final double v;
  final int n;
  final double h, w;
  const LevelBars(this.v, {super.key, this.n = 7, this.h = 46, this.w = 18});
  static const cols = [Color(0xFF00E5FF), Color(0xFF00E5A0), Color(0xFF39FF88), Color(0xFFC6FF1A), Color(0xFFFFE01A), Color(0xFFFF9A1A), Color(0xFFFF3B2F)];
  @override
  Widget build(BuildContext c) {
    final on = (v.clamp(0.0, 1.0) * n).ceil();
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < n; i++)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: w,
            height: h * (.3 + .7 * i / (n - 1)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i < on ? cols[(i * cols.length / n).floor()] : const Color(0xFF242046),
              boxShadow: i < on ? [BoxShadow(color: cols[(i * cols.length / n).floor()].withOpacity(.6), blurRadius: 10)] : null,
            ),
          ),
        ),
    ]);
  }
}

/// Gráfica de línea neón.
class LinePainter extends CustomPainter {
  final List<double> v;
  final Color col;
  LinePainter(this.v, this.col);
  @override
  void paint(Canvas cv, Size s) {
    final grid = Paint()..color = Colors.white.withOpacity(.06);
    for (var i = 1; i < 4; i++) {
      cv.drawLine(Offset(0, s.height * i / 4), Offset(s.width, s.height * i / 4), grid);
    }
    if (v.length < 2) return;
    final p = Path();
    for (var i = 0; i < v.length; i++) {
      final x = s.width * i / (v.length - 1), y = s.height * (1 - v[i].clamp(0.0, 1.0));
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    final fill = Path.from(p)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    cv.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [col.withOpacity(.35), col.withOpacity(0)]).createShader(Offset.zero & s));
    cv.drawPath(p, Paint()..color = col.withOpacity(.6)..style = PaintingStyle.stroke..strokeWidth = 5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    cv.drawPath(p, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_) => true;
}

/// Mini mapa neón para el historial (ruta lima sobre cuadrícula azul).
class RouteThumbPainter extends CustomPainter {
  final List<(double, double)> r;
  RouteThumbPainter(this.r);
  @override
  void paint(Canvas cv, Size s) {
    cv.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(colors: [Color(0xFF0B1450), Color(0xFF1A0E4A)]).createShader(Offset.zero & s));
    final g = Paint()..color = const Color(0xFF3D5BFF).withOpacity(.35)..strokeWidth = 1;
    final rnd = m.Random(r.length);
    for (var i = 0; i < 9; i++) {
      final x = rnd.nextDouble() * s.width, y = rnd.nextDouble() * s.height;
      cv.drawLine(Offset(x, 0), Offset(x + rnd.nextDouble() * 30 - 15, s.height), g);
      cv.drawLine(Offset(0, y), Offset(s.width, y + rnd.nextDouble() * 30 - 15), g);
    }
    final pts = <Offset>[];
    if (r.length >= 2) {
      final la = r.map((e) => e.$1), lo = r.map((e) => e.$2);
      final minLa = la.reduce(m.min), maxLa = la.reduce(m.max), minLo = lo.reduce(m.min), maxLo = lo.reduce(m.max);
      final dx = (maxLo - minLo) == 0 ? 1 : maxLo - minLo, dy = (maxLa - minLa) == 0 ? 1 : maxLa - minLa;
      for (final e in r) {
        pts.add(Offset(10 + (s.width - 20) * (e.$2 - minLo) / dx, 10 + (s.height - 20) * (1 - (e.$1 - minLa) / dy)));
      }
    } else {
      // Sin GPS: ruta decorativa
      pts.addAll([Offset(s.width * .15, s.height * .8), Offset(s.width * .35, s.height * .55), Offset(s.width * .5, s.height * .7), Offset(s.width * .7, s.height * .35), Offset(s.width * .85, s.height * .2)]);
    }
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    cv.drawPath(p, Paint()..color = lime.withOpacity(.6)..style = PaintingStyle.stroke..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    cv.drawPath(p, Paint()..color = lime..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
    cv.drawCircle(pts.first, 4, Paint()..color = lime);
    cv.drawCircle(pts.last, 5, Paint()..color = lime..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ======================= ENCABEZADOS =======================
class TopBar extends StatelessWidget {
  final String title;
  final Widget? right;
  final bool back;
  const TopBar(this.title, {super.key, this.right, this.back = true});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
    child: Row(children: [
      SizedBox(width: 48, child: back && Navigator.canPop(c) ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 22), onPressed: () => Navigator.pop(c)) : null),
      Expanded(child: Center(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)))),
      SizedBox(width: 48, child: right),
    ]),
  );
}

class Dot extends StatelessWidget {
  final String t;
  final Color col;
  const Dot(this.t, {super.key, this.col = green});
  @override
  Widget build(BuildContext c) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 9, height: 9, decoration: BoxDecoration(color: col, shape: BoxShape.circle, boxShadow: [BoxShadow(color: col, blurRadius: 8)])),
    const SizedBox(width: 6),
    Text(t, style: TextStyle(color: col, fontSize: 14, fontWeight: FontWeight.w600)),
  ]);
}

/// Tarjeta de métrica compacta (ícono + valor + etiqueta).
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color col;
  final String value, label;
  const StatTile(this.icon, this.col, this.value, this.label, {super.key});
  @override
  Widget build(BuildContext c) => Glass(
    r: 18,
    p: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
    child: Column(children: [
      glowIcon(icon, 30, c: col),
      const SizedBox(height: 6),
      FittedBox(child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      FittedBox(child: Text(label, style: const TextStyle(color: soft, fontSize: 13))),
    ]),
  );
}

// ======================= BARRA DE NAVEGACIÓN =======================
class NeonNav extends StatelessWidget {
  final int i;
  final ValueChanged<int> onTap;
  const NeonNav(this.i, this.onTap, {super.key});
  static const items = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.fitness_center, 'Entrenar'),
    (Icons.sensors, 'Sensores'),
    (Icons.history, 'Historial'),
    (Icons.person_outline, 'Perfil'),
  ];
  @override
  Widget build(BuildContext c) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Glass(
        r: 30,
        fill: const Color(0xFF080718),
        p: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          for (var k = 0; k < items.length; k++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    k == i ? glowIcon(items[k].$1, 28, c: lime) : Icon(items[k].$1, size: 26, color: Colors.white),
                    const SizedBox(height: 3),
                    FittedBox(
                      child: Text(items[k].$2,
                          style: TextStyle(fontSize: 12, fontWeight: k == i ? FontWeight.w700 : FontWeight.w400, color: k == i ? lime : Colors.white, shadows: k == i ? [const Shadow(color: lime, blurRadius: 10)] : null)),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ),
  );
}
