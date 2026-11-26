import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services.dart';
import 'ui.dart';
import 'auth.dart';
import 'shell.dart';
import 'popups.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: bg));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await S.init();
  runApp(const PulseXApp());
}

class PulseXApp extends StatefulWidget {
  const PulseXApp({super.key});
  @override
  State<PulseXApp> createState() => _PulseXAppState();
}

class _PulseXAppState extends State<PulseXApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _pausedAt;
  bool _locking = false;

  // Batería: en segundo plano se libera el listener del podómetro (salvo durante un entrenamiento).
  // El contador del sistema es acumulativo, así que al volver no se pierde ningún paso.
  // Seguridad: si la app estuvo más de 1 minuto en segundo plano, pide la huella otra vez.
  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      if (S.session == null) S.stopSteps();
    }
    if (st == AppLifecycleState.resumed) {
      S.startSteps();
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away.inSeconds > 60 && S.unlocked && S.user != null && S.session == null) _lock();
    }
  }

  Future<void> _lock() async {
    if (_locking) return;
    _locking = true;
    while (true) {
      final c = navKey.currentState?.overlay?.context;
      if (c == null || !c.mounted) break;
      final r = await popupAuthRequired(c, closable: false);
      if (!c.mounted) break;
      if (r == 'pin') {
        goRoot(c, const FingerprintPage());
        break;
      }
      if (await S.biometric()) {
        if (c.mounted) snack(c, '✔ Identidad confirmada');
        break;
      }
      if (c.mounted) snack(c, '✖ Huella no reconocida');
    }
    _locking = false;
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: navKey,
    title: 'PulseX',
    theme: pulseTheme(),
    // Con sesión recordada pide la huella; si no, muestra la bienvenida.
    home: S.remembered ? const FingerprintPage() : const WelcomePage(),
    routes: {'/home': (_) => const Shell()},
  );
}
