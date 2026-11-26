import 'package:material_ui/material_ui.dart';
import 'services.dart';
import 'ui.dart';
import 'body_form.dart';
import 'popups.dart';
import 'shell.dart' show tab;

final _mailRx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Reglas de contraseña segura: 8+ caracteres, minúscula, mayúscula, número y carácter especial.
final pwRules = <(String, bool Function(String))>[
  ('Mínimo 8 caracteres', (s) => s.length >= 8),
  ('Una letra minúscula (a-z)', (s) => RegExp(r'[a-z]').hasMatch(s)),
  ('Una letra MAYÚSCULA (A-Z)', (s) => RegExp(r'[A-Z]').hasMatch(s)),
  ('Un número (0-9)', (s) => RegExp(r'[0-9]').hasMatch(s)),
  ('Un carácter especial (!@#\$%&*?.)', (s) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(s)),
];
bool strongPw(String s) => pwRules.every((r) => r.$2(s));

/// Lista en vivo de requisitos de la contraseña.
class PwChecklist extends StatelessWidget {
  final TextEditingController ctl;
  const PwChecklist(this.ctl, {super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder(
    valueListenable: ctl,
    builder: (_, v, __) {
      final ok = pwRules.where((r) => r.$2(v.text)).length;
      final col = ok <= 2 ? red : (ok < 5 ? orange : green);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: ok / pwRules.length, minHeight: 7, backgroundColor: const Color(0xFF1E1B4A), color: col),
              ),
            ),
            const SizedBox(width: 10),
            Text(ok <= 2 ? 'Débil' : (ok < 5 ? 'Media' : 'Segura'), style: TextStyle(color: col, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          for (final r in pwRules)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                Icon(r.$2(v.text) ? Icons.check_circle : Icons.radio_button_unchecked, size: 17, color: r.$2(v.text) ? green : soft),
                const SizedBox(width: 8),
                Text(r.$1, style: TextStyle(fontSize: 13.5, color: r.$2(v.text) ? Colors.white : soft)),
              ]),
            ),
        ]),
      );
    },
  );
}

// ======================= BIENVENIDA =======================
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  Widget _circle(IconData i, Color col, double s) => Container(
    width: s,
    height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [card2, bg]),
      border: Border.all(color: col.withOpacity(.6), width: 1.4),
      boxShadow: [BoxShadow(color: col.withOpacity(.35), blurRadius: 22)],
    ),
    child: Center(child: glowIcon(i, s * .42, c: col)),
  );

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (_, k) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: k.maxHeight),
              child: Column(children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, .85, 1]).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset('assets/img/hero_welcome.jpg', width: double.infinity, height: k.maxHeight * .52, fit: BoxFit.cover, alignment: Alignment.topCenter),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(children: [
                    const SizedBox(height: 18),
                    GradBtn('Iniciar Sesión', () => go(c, S.remembered ? const FingerprintPage() : const LoginPage()), icon: Icons.fingerprint),
                    const SizedBox(height: 18),
                    OutlineBtn('Crear Cuenta', () => go(c, const RegisterPage()), icon: Icons.person_add_alt_1_outlined, fs: 22),
                    const SizedBox(height: 26),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Tu salud en tus manos', style: TextStyle(fontSize: 20, fontStyle: FontStyle.italic, color: Color(0xFFE6E3FF))),
                      const SizedBox(width: 10),
                      glowIcon(Icons.favorite_border, 28),
                    ]),
                    const SizedBox(height: 26),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _circle(Icons.fitness_center, purple, 76),
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: _circle(Icons.directions_run, pink, 92)),
                      _circle(Icons.location_on_outlined, cyan, 76),
                    ]),
                    const SizedBox(height: 40),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}

// ======================= INICIAR SESIÓN =======================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool remember = true, busy = false;
  late final em = TextEditingController(text: S.lastEmail);
  final pw = TextEditingController();

  Future<void> submit() async {
    final e = em.text.trim(), p = pw.text;
    if (!_mailRx.hasMatch(e)) return snack(context, 'Correo no válido');
    if (p.length < 6) return snack(context, 'La contraseña debe tener al menos 6 caracteres');
    setState(() => busy = true);
    final err = await S.login(e, p, remember);
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) return snack(context, err);
    goRoot(context, const FingerprintPage());
  }

  Future<void> finger() async {
    if (S.user == null) return snack(context, 'Inicia sesión una vez con tu correo para vincular tu huella');
    if (await S.biometric()) {
      if (!mounted) return;
      snack(context, '✔ Huella verificada. ¡Bienvenido, ${S.firstName}!');
      goHome(context);
    } else if (mounted) {
      snack(context, '✖ Huella no reconocida');
    }
  }

  Future<void> google() async {
    setState(() => busy = true);
    final e = await S.google();
    if (!mounted) return;
    setState(() => busy = false);
    e == null ? goHome(context) : snack(context, e);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: ListView(padding: EdgeInsets.zero, children: [
          Stack(children: [
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, .8, 1]).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset('assets/img/hero_login.jpg', width: double.infinity, fit: BoxFit.fitWidth),
            ),
            if (Navigator.canPop(c)) Positioned(left: 4, top: 4, child: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(c))),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Iniciar ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                GradText('Sesión', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic), colors: const [cyan, Color(0xFF6CF6FF)]),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Bienvenido de nuevo', style: TextStyle(fontSize: 19)),
                const SizedBox(width: 10),
                glowIcon(Icons.favorite_border, 26, c: blue),
              ]),
              const SizedBox(height: 18),
              NeonField('Correo electrónico', Icons.mail_outline, em, type: TextInputType.emailAddress),
              const SizedBox(height: 14),
              NeonField('Contraseña', Icons.lock, pw, pass: true, action: TextInputAction.done),
              const SizedBox(height: 6),
              Row(children: [
                GestureDetector(
                  onTap: () => setState(() => remember = !remember),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: remember ? const LinearGradient(colors: [pink, purple]) : null,
                        border: Border.all(color: purple, width: 1.5),
                        boxShadow: remember ? [BoxShadow(color: purple.withOpacity(.6), blurRadius: 10)] : null,
                      ),
                      child: remember ? const Icon(Icons.check, size: 18) : null,
                    ),
                    const SizedBox(width: 10),
                    const Text('Recordar mi cuenta', style: TextStyle(fontSize: 15)),
                  ]),
                ),
                const Spacer(),
                Flexible(
                  child: TextButton(
                    onPressed: () => resetDialog(c, em.text.trim()),
                    child: const FittedBox(child: Text('¿Olvidaste tu contraseña?', style: TextStyle(color: cyan, decoration: TextDecoration.underline, decorationColor: cyan, fontSize: 14))),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              GradBtn('Iniciar con Huella Digital', finger,
                  colors: const [Color(0xFF8E2DE2), Color(0xFF3D2BFF), Color(0xFF00C6FF)],
                  fs: 18,
                  leading: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white70), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.fingerprint, size: 34, color: Colors.white),
                  )),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(children: [
                  Expanded(child: Container(height: 1, color: soft.withOpacity(.4))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('o', style: TextStyle(fontSize: 18))),
                  Expanded(child: Container(height: 1, color: soft.withOpacity(.4))),
                ]),
              ),
              OutlineBtn('Continuar con Google', google, leading: const GoogleG()),
              const SizedBox(height: 16),
              GradBtn('Iniciar Sesión', submit, icon: Icons.login_rounded, busy: busy, fs: 22),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('¿No tienes una cuenta?', style: TextStyle(fontSize: 16)),
                TextButton(
                  onPressed: () => go(c, const RegisterPage()),
                  child: const Text('Regístrate aquí', style: TextStyle(color: pink, fontSize: 17, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: pink)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    ),
  );
}

Future<void> resetDialog(BuildContext c, String mail) {
  final e = TextEditingController(text: mail);
  return showDialog(
    context: c,
    builder: (d) => AlertDialog(
      title: const Text('Restablecer contraseña'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Te enviaremos un enlace a tu correo.', style: TextStyle(color: soft)),
        const SizedBox(height: 10),
        TextField(controller: e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo electrónico')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        TextButton(
          onPressed: () async {
            if (!_mailRx.hasMatch(e.text.trim())) return snack(c, 'Correo no válido');
            final err = await S.resetPass(e.text.trim());
            if (!c.mounted) return;
            Navigator.pop(d);
            snack(c, err ?? 'Revisa tu correo para restablecer tu contraseña');
          },
          child: const Text('Enviar'),
        ),
      ],
    ),
  );
}

// ======================= REGISTRO =======================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController(), em = TextEditingController(), pw = TextEditingController(), pw2 = TextEditingController();
  final goals = <String>{'Resistencia'};
  bool terms = false, bio = false, busy = false;

  Future<void> regBio() async {
    final ok = await S.biometric();
    if (!mounted) return;
    setState(() => bio = ok);
    snack(context, ok ? 'Huella registrada correctamente' : 'No se pudo registrar la huella');
  }

  Future<void> submit() async {
    final n = name.text.trim(), e = em.text.trim();
    if (n.length < 3) return snack(context, 'Escribe tu nombre completo');
    if (!_mailRx.hasMatch(e)) return snack(context, 'Correo no válido');
    if (!strongPw(pw.text)) {
      final f = pwRules.firstWhere((r) => !r.$2(pw.text)).$1;
      return snack(context, 'Contraseña insegura: falta ${f.toLowerCase()}');
    }
    if (pw.text != pw2.text) return snack(context, 'Las contraseñas no coinciden');
    if (!terms) return snack(context, 'Acepta los Términos y la Política de Privacidad');
    setState(() => busy = true);
    final err = await S.register(e, pw.text, name: n);
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) return snack(context, err);
    S.setGoals(goals.toList());
    final r = await popupAccountCreated(context);
    if (!mounted) return;
    // Siguiente paso: formulario de datos físicos (si ya validó huella) o validar huella primero.
    final t = r == 'perfil' ? 4 : 0;
    if (bio) {
      goHome(context, t: t);
    } else {
      tab.value = t;
      goRoot(context, const FingerprintPage());
    }
  }

  void legal(String t) => showDialog(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(t),
      content: const Text(
        'PulseX usa tu ubicación, sensores y podómetro solo para registrar tus entrenamientos. '
        'Tus datos se guardan en tu cuenta de Firebase y en tu dispositivo, y puedes borrarlos en cualquier momento desde Configuración. '
        'Tu huella dactilar nunca sale de tu teléfono: la verifica el sistema operativo.',
        style: TextStyle(color: soft, height: 1.4),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Entendido'))],
    ),
  );

  Widget chip(String t) {
    final on = goals.contains(t);
    return GestureDetector(
      onTap: () => setState(() => on ? goals.remove(t) : goals.add(t)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: on ? const LinearGradient(colors: [Color(0xFF5B0FB8), purple]) : null,
          color: on ? null : card2,
          border: Border.all(color: on ? pink : purple.withOpacity(.5), width: on ? 1.6 : 1),
          boxShadow: on ? [BoxShadow(color: pink.withOpacity(.5), blurRadius: 14)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t, style: const TextStyle(fontSize: 14)),
          if (on) ...[const SizedBox(width: 4), const Icon(Icons.check, size: 16, color: cyan)],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 6, 22, 28), children: [
          Row(children: [IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(c)), const Spacer()]),
          const Center(child: PulseLine(width: 160, height: 34)),
          const Center(child: PulseLogo(size: 58)),
          const SizedBox(height: 4),
          const Center(child: Text('Regístrate y comienza tu reto', style: TextStyle(fontSize: 19, fontStyle: FontStyle.italic))),
          const SizedBox(height: 16),
          Center(
            child: ValueListenableBuilder(
              valueListenable: name,
              builder: (_, v, __) => v.text.trim().isEmpty
                  ? Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: card2, border: Border.all(color: purple, width: 2), boxShadow: [BoxShadow(color: blue.withOpacity(.5), blurRadius: 24)]),
                      child: const Icon(Icons.person, size: 84, color: Color(0xFFB7B0F0)),
                    )
                  : Avatar(name: v.text, size: 118),
            ),
          ),
          const SizedBox(height: 18),
          NeonField('Nombre completo', Icons.person_outline, name),
          const SizedBox(height: 12),
          NeonField('Correo electrónico', Icons.mail_outline, em, type: TextInputType.emailAddress),
          const SizedBox(height: 12),
          NeonField('Contraseña', Icons.lock, pw, pass: true),
          PwChecklist(pw),
          const SizedBox(height: 12),
          NeonField('Confirmar contraseña', Icons.lock, pw2, pass: true, action: TextInputAction.done),
          ValueListenableBuilder(
            valueListenable: pw2,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(children: [
                      Icon(v.text == pw.text ? Icons.check_circle : Icons.cancel, size: 17, color: v.text == pw.text ? green : red),
                      const SizedBox(width: 8),
                      Text(v.text == pw.text ? 'Las contraseñas coinciden' : 'Las contraseñas no coinciden', style: TextStyle(fontSize: 13.5, color: v.text == pw.text ? green : red)),
                    ]),
                  ),
          ),
          const SizedBox(height: 14),
          Glass(
            r: 24,
            onTap: regBio,
            border: bio ? const [green, cyan] : gBorder,
            child: Row(children: [
              glowIcon(Icons.fingerprint, 50, c: bio ? green : cyan),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bio ? 'Huella registrada' : 'Registrar Huella Dactilar', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Text('Accede de forma segura', style: TextStyle(color: soft)),
                ]),
              ),
              Icon(bio ? Icons.check_circle : Icons.chevron_right, color: bio ? green : Colors.white70),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [glowIcon(Icons.track_changes, 28), const SizedBox(width: 10), const Text('Tus objetivos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final g in ['Salud', 'Resistencia', 'Pérdida de peso', 'Rendimiento']) chip(g)]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: terms, onChanged: (v) => setState(() => terms = v!), activeColor: purple, side: const BorderSide(color: Colors.white, width: 1.5)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(children: [
                  const Text('Acepto los ', style: TextStyle(fontSize: 15)),
                  GestureDetector(onTap: () => legal('Términos y Condiciones'), child: const Text('Términos y Condiciones', style: TextStyle(color: cyan, fontSize: 15, decoration: TextDecoration.underline, decorationColor: cyan))),
                  const Text(' y la ', style: TextStyle(fontSize: 15)),
                  GestureDetector(onTap: () => legal('Política de Privacidad'), child: const Text('Política de Privacidad', style: TextStyle(color: cyan, fontSize: 15, decoration: TextDecoration.underline, decorationColor: cyan))),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          GradBtn('Registrarme', submit, icon: Icons.person_add_alt_1, busy: busy),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('¿Ya tienes cuenta?', style: TextStyle(fontSize: 15)),
            TextButton(
              onPressed: () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const LoginPage())),
              child: const Text('Iniciar Sesión', style: TextStyle(color: cyan, fontSize: 15, decoration: TextDecoration.underline, decorationColor: cyan)),
            ),
          ]),
        ]),
      ),
    ),
  );
}

// ======================= ACCESO SEGURO (HUELLA + PIN) =======================
class FingerprintPage extends StatefulWidget {
  const FingerprintPage({super.key});
  @override
  State<FingerprintPage> createState() => _FingerprintPageState();
}

class _FingerprintPageState extends State<FingerprintPage> with SingleTickerProviderStateMixin {
  String msg = '';
  late final anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => auth());
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  Future<void> auth() async {
    if (!await S.bioAvailable()) {
      if (mounted) setState(() => msg = 'Este dispositivo no tiene huella configurada. Usa tu PIN');
      return;
    }
    if (await S.biometric()) {
      if (!mounted) return;
      snack(context, '✔ Huella verificada. ¡Bienvenido, ${S.firstName}!');
      goHome(context);
    } else if (mounted) {
      snack(context, '✖ Huella no reconocida');
      setState(() => msg = 'No se pudo verificar la huella. Intenta de nuevo o usa tu PIN');
    }
  }

  Future<void> pin() async {
    final ctl = TextEditingController();
    final create = !S.hasPin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(create ? 'Crea tu PIN (4 dígitos)' : 'Ingresa tu PIN'),
        content: TextField(controller: ctl, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, autofocus: true, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (ctl.text.length != 4) return;
              if (create) {
                S.setPin(ctl.text);
                Navigator.pop(d, true);
              } else {
                Navigator.pop(d, S.checkPin(ctl.text));
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      goHome(context);
    } else if (ok == false && !create) {
      setState(() => msg = 'PIN incorrecto');
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: Column(children: [
          const TopBar('Acceso Seguro'),
          const Spacer(),
          const PulseLogo(size: 46),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: auth,
            child: AnimatedBuilder(
              animation: anim,
              builder: (_, __) => Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(colors: [cyan, purple, pink, cyan]),
                  boxShadow: [BoxShadow(color: cyan.withOpacity(.3 + .3 * anim.value), blurRadius: 30 + 20 * anim.value), BoxShadow(color: purple.withOpacity(.4), blurRadius: 40)],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: bg), child: Center(child: glowIcon(Icons.fingerprint, 120))),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text('Coloca tu huella dactilar\npara continuar', textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
          Padding(padding: const EdgeInsets.all(20), child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: orange))),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 30),
            child: Column(children: [
              GradBtn('Usar huella', auth, icon: Icons.fingerprint, h: 54, fs: 18),
              const SizedBox(height: 14),
              OutlineBtn('Usar PIN', pin, icon: Icons.lock_outline, h: 52, fs: 17),
            ]),
          ),
        ]),
      ),
    ),
  );
}
