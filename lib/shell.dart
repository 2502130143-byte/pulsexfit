import 'dart:math' as m;
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services.dart';
import 'ui.dart';
import 'auth.dart';
import 'workout.dart';
import 'permissions.dart';
import 'body_form.dart';
import 'popups.dart';
import 'pulsebot.dart';
import 'ghost.dart';

/// Pestaña activa (permite saltar de una pestaña a otra desde cualquier pantalla).
final tab = ValueNotifier<int>(0);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  void initState() {
    super.initState();
    // Al entrar al dashboard se validan los permisos con diálogo informativo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Perms.ensure(context);
    });
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
    valueListenable: tab,
    builder: (_, i, __) => Scaffold(
      extendBody: true,
      drawer: const _Menu(),
      body: NeonBg(
        child: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(i),
              // Solo se construye la pestaña visible: los sensores y el GPS se apagan al salir.
              child: [const HomeTab(), const CoachTab(), const SensorsTab(), const HistoryTab(), const ProfileTab()][i],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NeonNav(i, (v) => tab.value = v),
    ),
  );
}

const _navSpace = SizedBox(height: 110);

class _Menu extends StatelessWidget {
  const _Menu();
  @override
  Widget build(BuildContext c) => Drawer(
    backgroundColor: const Color(0xFF07061A),
    child: SafeArea(
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(28), child: PulseLogo(size: 40)),
        _item(c, Icons.directions_run, 'Iniciar entrenamiento', () => go(c, const WorkoutPage())),
        _item(c, Icons.map_outlined, 'Mapa en tiempo real', () => go(c, const MapPage())),
        _item(c, Icons.settings_outlined, 'Configuración', () => go(c, const SettingsPage())),
        const Spacer(),
        _item(c, Icons.logout, 'Cerrar sesión', () => logout(c), col: red),
        const SizedBox(height: 12),
      ]),
    ),
  );

  Widget _item(BuildContext c, IconData i, String t, VoidCallback f, {Color col = cyan}) => ListTile(
    leading: Icon(i, color: col),
    title: Text(t, style: TextStyle(color: col == red ? red : Colors.white)),
    onTap: () {
      Navigator.pop(c);
      f();
    },
  );
}

Future<void> logout(BuildContext c) async {
  final ok = await popupLogout(c);
  if (ok != true) return;
  await S.logout();
  tab.value = 0;
  if (c.mounted) goRoot(c, const WelcomePage());
}

// ======================= INICIO =======================
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Widget pill(IconData i, Color col, String v, String unit, String l) => Glass(
    r: 22,
    p: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(children: [
      glowIcon(i, 30, c: col),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              TextSpan(text: unit, style: const TextStyle(fontSize: 15)),
            ])),
          ),
          Text(l, style: const TextStyle(color: soft, fontSize: 13)),
        ]),
      ),
    ]),
  );

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: S,
    builder: (_, __) {
      final now = DateTime.now();
      final mon = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final week = [for (var k = 0; k < 7; k++) S.stepsOn(mon.add(Duration(days: k)))];
      final mx = m.max(week.fold(0, m.max), 1000);
      final h = now.hour;
      final saludo = h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
      return ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 0), children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.menu_rounded, size: 32), onPressed: () => Scaffold.of(c).openDrawer()),
          const Expanded(child: Center(child: PulseLogo(size: 40))),
          IconButton(
            icon: Stack(children: [
              const Icon(Icons.notifications_none_rounded, size: 32),
              if (S.notif) Positioned(right: 2, top: 2, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: red, blurRadius: 6)]))),
            ]),
            onPressed: () => snack(c, S.todaySteps >= AppState.stepGoal ? '¡Meta diaria cumplida! 🎉' : 'Te faltan ${fnum(AppState.stepGoal - S.todaySteps)} pasos para tu meta de hoy'),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¡Hola, ${S.firstName}! 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text('$saludo · Supera tus límites hoy', style: const TextStyle(color: soft, fontSize: 15)),
            ]),
          ),
          GestureDetector(onTap: () => tab.value = 4, child: Avatar(name: S.name, photo: S.photo, size: 78)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            flex: 11,
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: RingPainter(S.todaySteps / AppState.stepGoal),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  glowIcon(Icons.directions_run, 34, c: cyan),
                  FittedBox(child: Text(fnum(S.todaySteps), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900))),
                  const Text('Pasos', style: TextStyle(fontSize: 17)),
                  Text('de ${fnum(AppState.stepGoal)}', style: const TextStyle(color: soft, fontSize: 13)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 10,
            child: Column(children: [
              pill(Icons.location_on, cyan, S.todayKm.toStringAsFixed(1), ' km', 'Distancia'),
              const SizedBox(height: 10),
              pill(Icons.local_fire_department, orange, '${S.todayCal}', '', 'Calorías'),
              const SizedBox(height: 10),
              pill(Icons.timer_outlined, blue, '${S.todayActiveMin}', ' min', 'Tiempo activo'),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        BotCard(
          mode: S.todaySteps >= AppState.stepGoal ? BotMode.happy : BotMode.idle,
          tips: [
            S.todaySteps >= AppState.stepGoal ? '¡Lo lograste! Superaste tu meta de ${fnum(AppState.stepGoal)} pasos hoy 🎉' : '¡Hola, ${S.firstName}! Te faltan ${fnum(AppState.stepGoal - S.todaySteps)} pasos para tu meta de hoy.',
            if (S.challenge.isNotEmpty) 'Tu reto es "${S.challenge}". ¡Cada entrenamiento te acerca más!',
            'Hidrátate: toma un vaso de agua antes y después de entrenar 💧',
            'Calienta 5 minutos antes de correr para evitar lesiones.',
            'Activa el modo ahorro si vas a entrenar mucho tiempo con poca batería ⚡',
            'Revisa al Entrenador Pulse IA para ver tu recomendación de hoy.',
          ],
        ),
        const SizedBox(height: 16),
        Glass(
          r: 24,
          child: Column(children: [
            Row(children: [
              glowIcon(Icons.bar_chart_rounded, 26, c: purple),
              const SizedBox(width: 8),
              const Text('Tu progreso semanal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(onTap: () => tab.value = 3, child: const Text('Ver más ›', style: TextStyle(color: cyan, fontSize: 15))),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                for (var k = 0; k < 7; k++)
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (k == now.weekday - 1) Container(width: 10, height: 10, margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: cyan, blurRadius: 10)])),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 22,
                      height: m.max(8.0, 82.0 * week[k] / mx),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: k == now.weekday - 1 ? const [blue, cyan] : const [purple, Color(0xFF6E8BFF)]),
                        boxShadow: [BoxShadow(color: (k == now.weekday - 1 ? cyan : purple).withOpacity(.6), blurRadius: 12)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(dayShort(k + 1), style: TextStyle(fontSize: 13, color: k == now.weekday - 1 ? cyan : Colors.white)),
                  ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        GradBtn('Iniciar Entrenamiento', () => go(c, const WorkoutPage()), icon: Icons.play_arrow_rounded, colors: const [Color(0xFF9B30FF), Color(0xFF5B4BFF), Color(0xFF3FD8FF)]),
        const SizedBox(height: 16),
        GhostCard(onTap: () async {
          final g = await pickGhost(c);
          if (g != null && c.mounted) go(c, WorkoutPage(ghost: g));
        }),
        const SizedBox(height: 16),
        Glass(
          r: 22,
          p: EdgeInsets.zero,
          child: SizedBox(
            height: 84,
            child: Stack(children: [
              Positioned(right: 0, top: 0, bottom: 0, child: ClipRRect(borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)), child: Opacity(opacity: .55, child: Image.asset('assets/img/hero_welcome.jpg', width: 140, fit: BoxFit.cover, alignment: Alignment.topCenter)))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  glowIcon(Icons.emoji_events, 40, c: const Color(0xFFFFC21A)),
                  const SizedBox(width: 14),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tú puedes lograrlo', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    Text(S.todaySteps >= AppState.stepGoal ? '¡Meta de hoy cumplida!' : 'Cada paso cuenta', style: const TextStyle(color: soft)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        _navSpace,
      ]);
    },
  );
}

// ======================= ENTRENADOR PULSE IA =======================
/// Recomendación generada en el dispositivo a partir de tu historial y tus pasos de hoy.
class Advice {
  final String title, detail, bubble;
  final int mins;
  final double kmh;
  const Advice(this.title, this.detail, this.bubble, this.mins, this.kmh);
  double get km => double.parse((kmh * mins / 60).toStringAsFixed(1));
  int get cal => (km * 1000 / S.strideM * S.calPerStep).round();
}

Advice pulseCoach() {
  final rec = S.history.where((w) => w.secs >= 60).take(5).toList();
  final name = S.firstName;
  if (rec.isEmpty) {
    return Advice('Empieza suave', 'Camina a 4.5 km/h durante 20 min.', '¡Hola, $name! 👋\nHoy empezamos tu reto. Una caminata ligera te ayudará a crear el hábito.', 20, 4.5);
  }
  final avgKmh = rec.fold(0.0, (a, w) => a + w.kmh) / rec.length;
  final avgMin = rec.fold(0, (a, w) => a + w.secs) / rec.length / 60;
  final last = rec.first;
  final rested = DateTime.now().difference(last.date).inHours;
  if (rested < 14 && last.secs > 40 * 60) {
    final k = (avgKmh * .8).clamp(3.5, 7.0);
    return Advice('Recuperación activa', 'Mantén ${k.toStringAsFixed(1)} km/h durante 20 min.', '¡Hola, $name! 👋\nAyer entrenaste fuerte. Hoy toca bajar la intensidad para recuperar.', 20, k);
  }
  if (last.kmh >= avgKmh || rec.length < 2) {
    final k = (avgKmh * 1.1).clamp(4.5, 13.0);
    final mins = (avgMin + 5).clamp(15, 60).round();
    return Advice('Aumenta tu ritmo', 'Mantén una velocidad de ${k.toStringAsFixed(1)} km/h durante $mins min.', '¡Hola, $name! 👋\nHoy puedes aumentar un poco tu ritmo. Tu rendimiento está mejorando.', mins, k);
  }
  final mins = (avgMin).clamp(15, 50).round();
  return Advice('Mantén tu constancia', 'Sostén ${avgKmh.clamp(4.0, 12.0).toStringAsFixed(1)} km/h durante $mins min.', '¡Hola, $name! 👋\nTu ritmo bajó un poco. Enfócate en mantener un paso constante.', mins, avgKmh.clamp(4.0, 12.0));
}

class CoachTab extends StatelessWidget {
  const CoachTab({super.key});

  Widget plan(IconData i, Color col, String l, String v) => Expanded(
    child: Glass(
      r: 18,
      p: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(children: [
        glowIcon(i, 30, c: col),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(l, style: const TextStyle(color: soft, fontSize: 12))),
            FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          ]),
        ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: S,
    builder: (_, __) {
      final a = pulseCoach();
      final reto = S.challenge;
      final prog = (S.todaySteps / AppState.stepGoal).clamp(0.0, 1.0);
      return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => tab.value = 0),
          const Expanded(child: Center(child: PulseLogo(size: 32))),
          IconButton(icon: const Icon(Icons.settings_outlined, size: 30), onPressed: () => go(c, const SettingsPage())),
        ]),
        SizedBox(
          height: 330,
          child: Stack(children: [
            Positioned(
              left: -10,
              top: 0,
              bottom: 0,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, .78, 1]).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Image.asset('assets/img/coach.jpg', fit: BoxFit.cover, width: MediaQuery.of(c).size.width * .5),
              ),
            ),
            Positioned(
              right: 0,
              top: 4,
              width: MediaQuery.of(c).size.width * .56,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                FittedBox(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  glowIcon(Icons.psychology_outlined, 54, c: cyan),
                  const SizedBox(width: 6),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Entrenador', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: Color(0xFFE9E2FF))),
                    GradText('Pulse IA', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1), colors: const [cyan, purple, pink]),
                  ]),
                ])),
                const SizedBox(height: 6),
                const Text('Tu asistente inteligente\nde entrenamiento', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFFE6E3FF))),
                const SizedBox(height: 14),
                Glass(
                  r: 22,
                  border: const [pink, purple, cyan],
                  p: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 6), child: PulseLine(width: 26, height: 18)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reto.isEmpty ? a.bubble : '${a.bubble}\nTu reto: $reto 💪', style: const TextStyle(fontSize: 14.5, height: 1.3))),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        Glass(
          r: 26,
          child: Column(children: [
            Row(children: [
              glowIcon(Icons.track_changes, 36),
              const SizedBox(width: 12),
              const Text('Recomendación de hoy', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Glass(
                  r: 20,
                  border: const [pink, purple],
                  child: Row(children: [
                    glowIcon(Icons.directions_run, 50, c: const Color(0xFFB57CFF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(a.detail, style: const TextStyle(color: Color(0xFFCFC6FF), fontSize: 14)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: Column(children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CustomPaint(
                      painter: RingPainter(prog, stroke: 8, colors: const [cyan, green, lime]),
                      child: Center(child: Text('${(prog * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Tu progreso', style: TextStyle(color: soft, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            GradBtn('Aplicar recomendación', () => go(c, WorkoutPage(advice: a)), icon: Icons.play_arrow_rounded, h: 54, fs: 18),
          ]),
        ),
        const SizedBox(height: 16),
        GhostCard(onTap: () async {
          final g = await pickGhost(c);
          if (g != null && c.mounted) go(c, WorkoutPage(ghost: g));
        }),
        const SizedBox(height: 16),
        Row(children: [glowIcon(Icons.auto_awesome, 28, c: const Color(0xFFB57CFF)), const SizedBox(width: 10), const Text('Tu plan personalizado', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 10),
        Row(children: [
          plan(Icons.timer_outlined, blue, 'Duración', '${a.mins} min'),
          const SizedBox(width: 8),
          plan(Icons.location_on, blue, 'Distancia meta', '${a.km} km'),
          const SizedBox(width: 8),
          plan(Icons.local_fire_department, orange, 'Calorías estimadas', '${a.cal} kcal'),
        ]),
        if (S.goals.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [for (final g in S.goals) Chip(label: Text(g), backgroundColor: card2, side: const BorderSide(color: purple), avatar: const Icon(Icons.check, size: 16, color: cyan))]),
        ],
        _navSpace,
      ]);
    },
  );
}

/// Acceso seguro al perfil: pide la huella antes de editar datos personales.
Future<void> openBodySecure(BuildContext c) async {
  final r = await popupAuthRequired(c, msg: 'Confirma tu identidad para ver y editar tus datos físicos.');
  if (r != 'huella' && r != 'pin') return;
  if (r == 'huella') {
    if (await S.biometric()) {
      if (c.mounted) go(c, const BodyFormPage(edit: true));
    } else if (c.mounted) {
      snack(c, '✖ Huella no reconocida');
    }
    return;
  }
  if (!c.mounted) return;
  final ctl = TextEditingController();
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(S.hasPin ? 'Ingresa tu PIN' : 'Aún no tienes PIN'),
      content: S.hasPin ? TextField(controller: ctl, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, autofocus: true, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 16)) : const Text('Usa tu huella digital.', style: TextStyle(color: soft)),
      actions: [TextButton(onPressed: () => Navigator.pop(d, S.hasPin && S.checkPin(ctl.text)), child: const Text('Aceptar'))],
    ),
  );
  if (!c.mounted) return;
  ok == true ? go(c, const BodyFormPage(edit: true)) : snack(c, 'No se pudo verificar tu identidad');
}

// ======================= PERFIL =======================
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> editName(BuildContext c) async {
    final t = TextEditingController(text: S.name);
    final v = await showDialog<String>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('Editar perfil'),
        content: TextField(controller: t, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre completo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (v != null && v.length >= 3) {
      await S.setName(v);
      if (c.mounted) snack(c, 'Perfil actualizado');
    }
  }

  static void showChallenges(BuildContext c) => showDialog(
    context: c,
    builder: (d) => AlertDialog(
      title: const Text('Mis retos'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in S.challenges.entries)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(e.value ? Icons.emoji_events : Icons.lock_outline, color: e.value ? const Color(0xFFFFC21A) : soft),
            title: Text(e.key, style: TextStyle(color: e.value ? Colors.white : soft)),
          ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cerrar'))],
    ),
  );

  Widget row(IconData i, Color col, String t, VoidCallback f, {Color? tc}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Glass(
      r: 18,
      glow: false,
      onTap: f,
      p: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        glowIcon(i, 26, c: col),
        const SizedBox(width: 16),
        Expanded(child: Text(t, style: TextStyle(fontSize: 17, color: tc ?? Colors.white))),
        const Icon(Icons.chevron_right, color: Colors.white70),
      ]),
    ),
  );

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: S,
    builder: (_, __) {
      final prog = (S.todaySteps / AppState.stepGoal).clamp(0.0, 1.0);
      return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), children: [
        Row(children: [const SizedBox(width: 48), const Expanded(child: Center(child: PulseLogo(size: 38))), IconButton(icon: const Icon(Icons.settings_outlined, size: 30), onPressed: () => go(c, const SettingsPage()))]),
        const SizedBox(height: 6),
        Row(children: [
          Avatar(name: S.name, photo: S.photo, size: 118, onCamera: () => editName(c)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mi Perfil', style: TextStyle(color: soft, fontSize: 14)),
              Text(S.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text(S.email, overflow: TextOverflow.ellipsis, style: const TextStyle(color: soft, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF2A1670), borderRadius: BorderRadius.circular(20), border: Border.all(color: purple)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, color: Color(0xFFFFC21A), size: 18), const SizedBox(width: 4), Text(S.level, style: const TextStyle(fontSize: 13))]),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: StatTile(Icons.directions_run, cyan, fnum(S.totalSteps), 'Pasos')),
          const SizedBox(width: 8),
          Expanded(child: StatTile(Icons.location_on, cyan, '${S.totalKm.toStringAsFixed(1)} km', 'Distancia')),
          const SizedBox(width: 8),
          Expanded(child: StatTile(Icons.local_fire_department, orange, fnum(S.totalCal), 'Calorías')),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: () => showChallenges(c), child: StatTile(Icons.emoji_events, const Color(0xFFFFC21A), '${S.challengesDone}', 'Retos'))),
        ]),
        const SizedBox(height: 14),
        Glass(
          r: 22,
          border: const [cyan, blue, purple],
          child: Row(children: [
            glowIcon(Icons.track_changes, 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(children: [
                Row(children: [
                  const Text('Tu objetivo diario', style: TextStyle(fontSize: 16, color: cyan, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${fnum(AppState.stepGoal)} pasos', style: const TextStyle(color: cyan, fontSize: 15)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Stack(children: [
                      Container(height: 12, decoration: BoxDecoration(color: const Color(0xFF1E1B4A), borderRadius: BorderRadius.circular(8))),
                      FractionallySizedBox(
                        widthFactor: m.max(prog, .03),
                        child: Container(height: 12, decoration: BoxDecoration(gradient: const LinearGradient(colors: [lime, green, cyan]), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: green.withOpacity(.7), blurRadius: 10)])),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Text('${(prog * 100).round()}%', style: const TextStyle(color: cyan, fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ]),
        ),
        if (S.hasBody) ...[
          const SizedBox(height: 14),
          Glass(
            r: 22,
            onTap: () => openBodySecure(c),
            child: Column(children: [
              Row(children: [
                glowIcon(Icons.accessibility_new, 26, c: purple),
                const SizedBox(width: 8),
                const Text('Mis datos físicos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                Dot('IMC ${S.imc.toStringAsFixed(1)} · ${S.imcLabel}', col: S.imc < 18.5 ? cyan : (S.imc < 25 ? green : (S.imc < 30 ? orange : red))),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                for (final d in [(S.sex, 'Sexo'), ('${S.age}', 'Años'), ('${S.weight.toStringAsFixed(S.weight % 1 == 0 ? 0 : 1)} kg', 'Peso'), ('${S.height} cm', 'Talla')])
                  Column(children: [Text(d.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(d.$2, style: const TextStyle(color: soft, fontSize: 12))]),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.emoji_events_outlined, color: lime, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Mi mayor reto: ${S.challenge}', style: const TextStyle(color: lime, fontWeight: FontWeight.w600))),
              ]),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        row(Icons.person_outline, cyan, 'Editar perfil', () => editName(c)),
        row(Icons.accessibility_new, cyan, 'Mis datos físicos', () => openBodySecure(c)),
        row(Icons.settings, cyan, 'Configuración', () => go(c, const SettingsPage())),
        row(Icons.shield_outlined, cyan, 'Privacidad y Seguridad', openAppSettings),
        row(Icons.notifications_none, cyan, 'Notificaciones', () => go(c, const SettingsPage())),
        row(Icons.info_outline, cyan, 'Acerca de PulseX', () => showAboutDialog(context: c, applicationName: 'PulseX', applicationVersion: '2.0.0', applicationLegalese: 'Entrena · Registra · Supera tus límites')),
        row(Icons.logout, orange, 'Cerrar sesión', () => logout(c), tc: red),
        _navSpace,
      ]);
    },
  );
}

// ======================= CONFIGURACIÓN =======================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget sw(IconData i, Color col, String t, String sub, bool v, ValueChanged<bool> f) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Glass(
      r: 20,
      glow: false,
      child: Row(children: [
        glowIcon(i, 30, c: col),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text(sub, style: const TextStyle(color: soft, fontSize: 13))])),
        Switch(value: v, onChanged: f, activeThumbColor: lime, activeTrackColor: green.withOpacity(.4)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: S,
          builder: (_, __) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
            const TopBar('Configuración'),
            const SizedBox(height: 10),
            sw(Icons.eco, green, 'Modo ahorro de batería', 'Sensores a 1 Hz, GPS de menor precisión y pasos en pausa en segundo plano.', S.saver, S.setSaver),
            sw(Icons.storage_rounded, cyan, 'Guardar historial local', 'Conserva tus entrenamientos en el teléfono (además de la nube).', S.keep, S.setKeep),
            sw(Icons.record_voice_over_outlined, pink, 'Entrenador de voz', 'Anuncia cada kilómetro, tu ritmo y el duelo contra tu fantasma.', S.voice, S.setVoice),
            sw(Icons.notifications_active_outlined, purple, 'Notificaciones', 'Avisos de meta diaria y recordatorios.', S.notif, S.setNotif),
            const SizedBox(height: 6),
            Glass(
              r: 20,
              glow: false,
              onTap: () async {
                if ((await Perms.missing()).isEmpty) {
                  if (c.mounted) snack(c, 'Todos los permisos están concedidos ✔');
                } else if (c.mounted) {
                  Perms.ensure(c, force: true);
                }
              },
              child: Row(children: [glowIcon(Icons.verified_user_outlined, 30, c: green), const SizedBox(width: 14), const Expanded(child: Text('Permisos del sistema', style: TextStyle(fontSize: 17))), const Icon(Icons.chevron_right, color: soft)]),
            ),
            const SizedBox(height: 10),
            Glass(
              r: 20,
              glow: false,
              onTap: () => showDialog(
                context: c,
                builder: (d) => AlertDialog(
                  title: const Text('PIN de respaldo'),
                  content: Text(S.hasPin ? 'Ya tienes un PIN configurado. Se pedirá cuando la huella no esté disponible.' : 'Aún no tienes PIN. Créalo la próxima vez que se te pida la huella, con el botón "Usar PIN".', style: const TextStyle(color: soft)),
                  actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Entendido'))],
                ),
              ),
              child: Row(children: [glowIcon(Icons.pin_outlined, 30, c: pink), const SizedBox(width: 14), const Expanded(child: Text('PIN de respaldo', style: TextStyle(fontSize: 17))), Dot(S.hasPin ? 'Activo' : 'Sin PIN', col: S.hasPin ? green : orange)]),
            ),
          ]),
        ),
      ),
    ),
  );
}
