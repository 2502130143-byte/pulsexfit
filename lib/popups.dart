import 'package:material_ui/material_ui.dart';
import 'ui.dart';
import 'pulsebot.dart';

// =====================================================================
//  VENTANAS EMERGENTES NEÓN DE PULSEX
//  éxito de registro · entrenamiento completado · batería baja ·
//  permisos · autenticación · nuevo logro · cerrar sesión
// =====================================================================

/// Muestra una ventana emergente con animación (zoom + desvanecido).
Future<T?> showNeon<T>(BuildContext c, Widget popup, {bool dismissible = true}) => showGeneralDialog<T>(
  context: c,
  barrierDismissible: dismissible,
  barrierLabel: 'PulseX',
  barrierColor: Colors.black.withOpacity(.72),
  transitionDuration: const Duration(milliseconds: 320),
  pageBuilder: (_, __, ___) => popup,
  transitionBuilder: (_, a, __, child) => FadeTransition(
    opacity: a,
    child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
  ),
);

/// Marco base: logo PulseX + botón cerrar + contenido.
class NeonPopup extends StatelessWidget {
  final Widget child;
  final bool close;
  final VoidCallback? onClose;
  const NeonPopup({super.key, required this.child, this.close = true, this.onClose});
  @override
  Widget build(BuildContext c) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Glass(
            r: 30,
            border: const [pink, purple, cyan],
            fill: const Color(0xFF07061A),
            p: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const PulseLogo(size: 30),
                const Spacer(),
                if (close) GestureDetector(onTap: onClose ?? () => Navigator.pop(c), child: const Icon(Icons.close_rounded, size: 34, color: Colors.white)),
              ]),
              const SizedBox(height: 12),
              child,
            ]),
          ),
        ),
      ),
    ),
  );
}

/// Ilustración con bordes difuminados para fundirse con el fondo.
Widget fadedArt(String asset, double w, double h) => ShaderMask(
  blendMode: BlendMode.dstIn,
  shaderCallback: (r) => const RadialGradient(colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, .62, 1]).createShader(r),
  child: Image.asset(asset, width: w, height: h, fit: BoxFit.cover),
);

/// Panel interno: ícono/ilustración a la izquierda y texto a la derecha.
class _Panel extends StatelessWidget {
  final Widget art;
  final String title, msg;
  final Color titleCol;
  const _Panel(this.art, this.title, this.msg, {this.titleCol = Colors.white});
  @override
  Widget build(BuildContext c) => Glass(
    r: 22,
    glow: false,
    border: [purple.withOpacity(.6), blue.withOpacity(.5)],
    fill: const Color(0xFF0E0C2A),
    p: const EdgeInsets.all(14),
    child: Row(children: [
      art,
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: titleCol)),
          const SizedBox(height: 6),
          Text(msg, style: const TextStyle(fontSize: 15, color: Color(0xFFD6D2F5), height: 1.3)),
        ]),
      ),
    ]),
  );
}

/// Dos botones: secundario (contorno) y principal (degradado).
Widget _twoBtns(BuildContext c, String no, String yes, IconData yesIcon, VoidCallback onYes, {List<Color> colors = gMain}) => Padding(
  padding: const EdgeInsets.only(top: 18),
  child: Row(children: [
    Expanded(child: OutlineBtn(no, () => Navigator.pop(c, false), h: 54, fs: 17)),
    const SizedBox(width: 12),
    Expanded(child: GradBtn(yes, onYes, icon: yesIcon, h: 54, fs: 17, colors: colors)),
  ]),
);

// ---------------------------------------------------------------------
// 1) ¡Tu cuenta fue creada con éxito!   → devuelve 'perfil' o 'continuar'
// ---------------------------------------------------------------------
Future<String?> popupAccountCreated(BuildContext c) => showNeon<String>(
  c,
  dismissible: false,
  Builder(
    builder: (d) => NeonPopup(
      onClose: () => Navigator.pop(d, 'continuar'),
      child: Column(children: [
        SizedBox(
          height: 210,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const PulseBot(size: 150, mode: BotMode.happy),
            const SizedBox(width: 6),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cyan, width: 3),
                boxShadow: [BoxShadow(color: cyan.withOpacity(.6), blurRadius: 30), BoxShadow(color: purple.withOpacity(.5), blurRadius: 50)],
              ),
              child: Center(child: glowIcon(Icons.check_rounded, 76)),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        const Text('¡Tu cuenta fue', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('creada con ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1)),
          GradText('éxito!', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1), colors: const [cyan, pink]),
        ]),
        const SizedBox(height: 12),
        const Text('Ahora puedes disfrutar de todas las funciones de PulseX y comenzar tu entrenamiento.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFFE2DEFF), height: 1.35)),
        const SizedBox(height: 20),
        GradBtn('Continuar', () => Navigator.pop(d, 'continuar'), icon: Icons.check_rounded),
        TextButton(
          onPressed: () => Navigator.pop(d, 'perfil'),
          child: const Text('Ir a mi perfil  ›', style: TextStyle(color: Color(0xFFD8B4FF), fontSize: 17, decoration: TextDecoration.underline, decorationColor: Color(0xFFD8B4FF))),
        ),
      ]),
    ),
  ),
);

// ---------------------------------------------------------------------
// 2) ¡Excelente trabajo! (entrenamiento completado)
// ---------------------------------------------------------------------
Future<void> popupWorkoutDone(BuildContext c, {required double km, required int kcal, required int mins}) => showNeon(
  c,
  Builder(
    builder: (d) => NeonPopup(
      child: Column(children: [
        Row(children: [
          const PulseBot(size: 110, mode: BotMode.happy),
          const SizedBox(width: 8),
          Expanded(
            child: Glass(
              r: 20,
              glow: false,
              border: [purple.withOpacity(.6), cyan.withOpacity(.5)],
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('¡Excelente trabajo!', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('Has completado tu entrenamiento con éxito.', style: TextStyle(fontSize: 15, color: Color(0xFFD6D2F5))),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Glass(
          r: 18,
          glow: false,
          border: [purple.withOpacity(.4), blue.withOpacity(.4)],
          p: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            for (final s in [(Icons.directions_run, cyan, '${km.toStringAsFixed(1)} km'), (Icons.local_fire_department, orange, '$kcal kcal'), (Icons.timer_outlined, cyan, '$mins min')])
              Row(children: [glowIcon(s.$1, 26, c: s.$2), const SizedBox(width: 6), Text(s.$3, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(width: 230, child: GradBtn('Aceptar', () => Navigator.pop(d), icon: Icons.check_rounded, h: 54)),
      ]),
    ),
  ),
);

// ---------------------------------------------------------------------
// 3) Advertencia: batería baja   → true = activar modo ahorro
// ---------------------------------------------------------------------
Future<bool?> popupLowBattery(BuildContext c, int level) => showNeon<bool>(
  c,
  Builder(
    builder: (d) => NeonPopup(
      child: Column(children: [
        Glass(
          r: 22,
          glow: false,
          border: [purple.withOpacity(.6), blue.withOpacity(.5)],
          fill: const Color(0xFF0E0C2A),
          child: Row(children: [
            Column(children: [
              glowIcon(Icons.warning_amber_rounded, 64, c: pink),
              const SizedBox(height: 4),
              Icon(Icons.battery_alert_rounded, size: 40, color: red, shadows: [Shadow(color: red.withOpacity(.8), blurRadius: 12)]),
              Text('$level%', style: const TextStyle(color: red, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(children: [
                const Text('Advertencia', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Tu batería está baja ($level%).\nPara un mejor seguimiento de tu entrenamiento, activa el modo ahorro.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFFD6D2F5), height: 1.35)),
              ]),
            ),
          ]),
        ),
        _twoBtns(d, 'Cancelar', 'Activar modo ahorro', Icons.bolt, () => Navigator.pop(d, true)),
      ]),
    ),
  ),
);

// ---------------------------------------------------------------------
// 4) Permisos necesarios   → true = permitir
// ---------------------------------------------------------------------
Future<bool?> popupPermissions(BuildContext c, List<(IconData, Color, String, String)> items) => showNeon<bool>(
  c,
  dismissible: false,
  Builder(
    builder: (d) => NeonPopup(
      onClose: () => Navigator.pop(d, false),
      child: Column(children: [
        _Panel(
          SizedBox(
            width: 90,
            height: 96,
            child: Stack(alignment: Alignment.center, children: [
              Positioned(bottom: 6, child: Container(width: 84, height: 22, decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.elliptical(84, 22)), border: Border.all(color: blue, width: 2), boxShadow: [BoxShadow(color: blue.withOpacity(.6), blurRadius: 14)]))),
              Positioned(top: 0, child: glowIcon(Icons.location_on, 70, c: const Color(0xFF3DA9FF))),
            ]),
          ),
          'Permisos necesarios',
          'PulseX necesita acceso a tus sensores para registrar tus rutas, pasos y distancia.',
        ),
        const SizedBox(height: 12),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              glowIcon(i.$1, 24, c: i.$2),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i.$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), Text(i.$4, style: const TextStyle(color: soft, fontSize: 13))])),
            ]),
          ),
        _twoBtns(d, 'Cancelar', 'Permitir', Icons.location_on, () => Navigator.pop(d, true), colors: const [purple, blue, cyan]),
      ]),
    ),
  ),
);

// ---------------------------------------------------------------------
// 5) Autenticación requerida   → true = usar huella, 'pin' manejado por onPin
// ---------------------------------------------------------------------
Future<String?> popupAuthRequired(BuildContext c, {String msg = 'Confirma tu identidad para continuar con tu sesión.', bool closable = true}) => showNeon<String>(
  c,
  dismissible: false,
  Builder(
    builder: (d) => NeonPopup(
      close: closable,
      onClose: () => Navigator.pop(d, 'cancel'),
      child: Column(children: [
        _Panel(
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [purple.withOpacity(.35), Colors.transparent])),
            child: Center(child: ShaderMask(blendMode: BlendMode.srcIn, shaderCallback: (r) => const LinearGradient(colors: [pink, purple, cyan]).createShader(r), child: const Icon(Icons.fingerprint, size: 84))),
          ),
          'Autenticación requerida',
          msg,
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: GradBtn('Usar huella digital', () => Navigator.pop(d, 'huella'), icon: Icons.fingerprint, h: 54, fs: 18),
        ),
        TextButton(onPressed: () => Navigator.pop(d, 'pin'), child: const Text('Usar PIN', style: TextStyle(color: cyan, decoration: TextDecoration.underline, decorationColor: cyan))),
      ]),
    ),
  ),
);

// ---------------------------------------------------------------------
// 6) ¡Nuevo logro desbloqueado!   → true = ver mis logros
// ---------------------------------------------------------------------
Future<bool?> popupAchievement(BuildContext c, String what) => showNeon<bool>(
  c,
  Builder(
    builder: (d) => NeonPopup(
      child: Column(children: [
        Glass(
          r: 22,
          glow: false,
          border: [purple.withOpacity(.6), blue.withOpacity(.5)],
          fill: const Color(0xFF0E0C2A),
          child: Row(children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFFFB31A).withOpacity(.45), blurRadius: 36)]),
              child: fadedArt('assets/img/trophy.jpg', 110, 110),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(children: [
                const Text('¡Nuevo logro desbloqueado!', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(what, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Color(0xFFD6D2F5))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: OutlineBtn('Ver mis logros', () => Navigator.pop(d, true), leading: const Icon(Icons.emoji_events, color: Color(0xFFFFC21A), size: 26), h: 54),
        ),
      ]),
    ),
  ),
);

// ---------------------------------------------------------------------
// 7) ¿Cerrar sesión?   → true = cerrar sesión
// ---------------------------------------------------------------------
Future<bool?> popupLogout(BuildContext c) => showNeon<bool>(
  c,
  Builder(
    builder: (d) => NeonPopup(
      child: Column(children: [
        _Panel(
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cyan, width: 3), boxShadow: [BoxShadow(color: cyan.withOpacity(.5), blurRadius: 22)]),
            child: Center(child: glowIcon(Icons.question_mark_rounded, 56)),
          ),
          '¿Cerrar sesión?',
          '¿Estás seguro de que deseas cerrar tu sesión?',
        ),
        _twoBtns(d, 'Cancelar', 'Cerrar sesión', Icons.logout_rounded, () => Navigator.pop(d, true), colors: const [pink, purple, blue]),
      ]),
    ),
  ),
);
