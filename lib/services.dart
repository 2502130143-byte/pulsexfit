import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pedometer/pedometer.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppState get S => AppState.i;

class Workout {
  final DateTime date;
  final int secs, steps, cal;
  final double km;
  final List<LatLng> route;
  const Workout(this.date, this.secs, this.steps, this.km, this.cal, this.route);
  String get id => date.millisecondsSinceEpoch.toString();
  double get kmh => secs == 0 ? 0 : km / (secs / 3600);
  String get type => kmh < 1 ? 'Descanso' : (kmh < 6.5 ? 'Caminata' : 'Trote');
  Map<String, dynamic> toJson() => {
    'd': date.toIso8601String(), 's': secs, 'p': steps, 'k': km, 'c': cal,
    'r': [for (final l in route) ...[l.latitude, l.longitude]],
  };
  factory Workout.fromJson(Map<String, dynamic> j) {
    final r = (j['r'] as List?) ?? [];
    final pts = <LatLng>[];
    if (r.isNotEmpty && r.first is List) {
      for (final l in r) { pts.add(LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble())); }
    } else {
      for (var i = 0; i + 1 < r.length; i += 2) { pts.add(LatLng((r[i] as num).toDouble(), (r[i + 1] as num).toDouble())); }
    }
    return Workout(DateTime.parse(j['d']), j['s'], j['p'], (j['k'] as num).toDouble(), j['c'], pts);
  }
}

class AppState extends ChangeNotifier {
  static final i = AppState._();
  AppState._();
  late SharedPreferences prefs;
  List<Workout> history = [];
  bool saver = false, keep = true;
  int todaySteps = 0;
  /// null = esperando datos, true = podómetro funcionando, false = sin sensor o sin permiso.
  bool? stepsOk;
  Session? session;
  /// true cuando el usuario ya pasó la huella/PIN en esta ejecución (para el bloqueo al volver de segundo plano).
  bool unlocked = false;
  StreamSubscription<StepCount>? _ps;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    saver = prefs.getBool('saver') ?? false;
    keep = prefs.getBool('keep') ?? true;
    final raw = prefs.getString('history');
    if (raw != null) history = [for (final j in jsonDecode(raw)) Workout.fromJson(j)];
    // Los permisos se piden en main.dart (askPermissions), con diálogo informativo.
    startSteps();
    if (user != null) syncDown();
  }

  String _day() => DateTime.now().toIso8601String().substring(0, 10);

  void startSteps() {
    _ps?.cancel();
    try {
      _ps = Pedometer.stepCountStream.listen((e) {
        final key = 'base_${_day()}';
        var b = prefs.getInt(key);
        if (b == null || e.steps < b) {
          b = e.steps;
          prefs.setInt(key, b);
        }
        stepsOk = true;
        todaySteps = e.steps - b;
        prefs.setInt('steps_${_day()}', todaySteps);
        notifyListeners();
      }, onError: (_) {
        stepsOk = false;
        notifyListeners();
      });
    } catch (_) {
      stepsOk = false;
    }
  }

  void stopSteps() {
    _ps?.cancel();
    _ps = null;
  }

  static const stepGoal = 10000;
  double get todayKm => todaySteps * strideM / 1000;
  int get todayActiveMin => todaySteps ~/ 100;

  String _key(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Pasos de un día: hoy = podómetro; días anteriores = guardado diario o suma de entrenamientos.
  int stepsOn(DateTime d) {
    if (_key(d) == _day()) return todaySteps;
    final saved = prefs.getInt('steps_${_key(d)}');
    if (saved != null) return saved;
    return history.where((w) => _key(w.date) == _key(d)).fold(0, (a, w) => a + w.steps);
  }

  // ---- Perfil ----
  String get name {
    final n = user?.displayName ?? prefs.getString('name') ?? '';
    if (n.trim().isNotEmpty) return n.trim();
    return email.isNotEmpty ? email.split('@').first : 'Atleta';
  }

  String get firstName => name.split(' ').first;
  String? get photo => user?.photoURL;

  Future<void> setName(String n) async {
    prefs.setString('name', n);
    try {
      await user?.updateDisplayName(n);
      await user?.reload();
    } catch (_) {}
    notifyListeners();
  }

  List<String> get goals => prefs.getStringList('goals') ?? [];
  void setGoals(List<String> g) => prefs.setStringList('goals', g);

  bool get voice => prefs.getBool('voice') ?? true;
  void setVoice(bool v) {
    prefs.setBool('voice', v);
    notifyListeners();
  }

  bool get notif => prefs.getBool('notif') ?? true;
  void setNotif(bool v) {
    prefs.setBool('notif', v);
    notifyListeners();
  }

  double get totalKm => history.fold(0.0, (a, w) => a + w.km);
  int get totalSteps => history.fold(0, (a, w) => a + w.steps);
  int get totalCal => history.fold(0, (a, w) => a + w.cal);
  int get activeDays => history.map((w) => _key(w.date)).toSet().length;

  String get level => totalKm >= 100 ? 'Nivel Avanzado' : (totalKm >= 20 ? 'Nivel Intermedio' : 'Nivel Principiante');

  /// Retos (logros) desbloqueados.
  Map<String, bool> get challenges => {
    'Primer entrenamiento': history.isNotEmpty,
    '10,000 pasos en un día': todaySteps >= stepGoal || history.any((w) => w.steps >= 10000),
    'Reto 7 días activos': activeDays >= 7,
    '5 km en una sesión': history.any((w) => w.km >= 5),
    '50 km acumulados': totalKm >= 50,
    'Maestro del movimiento (100 km)': totalKm >= 100,
  };
  int get challengesDone => challenges.values.where((v) => v).length;
  int get todayCal => (todaySteps * calPerStep).round();

  // ---- Datos físicos (formulario inicial) ----
  String get sex => prefs.getString('sex') ?? '';
  double get weight => prefs.getDouble('weight') ?? 0;
  int get height => prefs.getInt('height') ?? 0; // talla / estatura en cm
  int get age => prefs.getInt('age') ?? 0;
  String get challenge => prefs.getString('challenge') ?? '';
  bool get hasBody => sex.isNotEmpty && weight > 0 && height > 0 && age > 0 && challenge.isNotEmpty;

  /// Longitud de zancada según estatura y sexo (fórmula estándar 0.413 / 0.415 × estatura).
  double get strideM => height > 0 ? height * (sex == 'Mujer' ? .413 : .415) / 100 : .75;

  /// Kcal por paso aproximadas según el peso (≈0.04 kcal/paso a 70 kg).
  double get calPerStep => weight > 0 ? weight * 0.00057 : 0.04;

  double get imc => height > 0 ? weight / ((height / 100) * (height / 100)) : 0;
  String get imcLabel => imc == 0 ? '' : (imc < 18.5 ? 'Bajo peso' : (imc < 25 ? 'Saludable' : (imc < 30 ? 'Sobrepeso' : 'Obesidad')));

  DocumentReference<Map<String, dynamic>>? get _userDoc => user == null ? null : FirebaseFirestore.instance.collection('users').doc(user!.uid);

  Future<void> saveBody({required String sex, required double weight, required int height, required int age, required String challenge}) async {
    prefs.setString('sex', sex);
    prefs.setDouble('weight', weight);
    prefs.setInt('height', height);
    prefs.setInt('age', age);
    prefs.setString('challenge', challenge);
    notifyListeners();
    try {
      await _userDoc?.set({'sex': sex, 'weight': weight, 'height': height, 'age': age, 'challenge': challenge, 'name': name, 'goals': goals}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Trae los datos físicos guardados en la nube (por si inicia sesión en otro teléfono).
  Future<void> _loadBody() async {
    try {
      final d = (await _userDoc?.get())?.data();
      if (d == null || d['weight'] == null) return;
      prefs.setString('sex', d['sex'] ?? '');
      prefs.setDouble('weight', (d['weight'] as num).toDouble());
      prefs.setInt('height', (d['height'] as num).toInt());
      prefs.setInt('age', (d['age'] as num).toInt());
      prefs.setString('challenge', d['challenge'] ?? '');
    } catch (_) {}
  }

  void _clearBody() {
    for (final k in ['sex', 'weight', 'height', 'age', 'challenge', 'name', 'goals']) {
      prefs.remove(k);
    }
  }

  void setSaver(bool v) {
    saver = v;
    prefs.setBool('saver', v);
    notifyListeners();
  }

  void setKeep(bool v) {
    keep = v;
    prefs.setBool('keep', v);
    v ? _save() : prefs.remove('history');
    notifyListeners();
  }

  void _save() => prefs.setString('history', jsonEncode([for (final w in history) w.toJson()]));

  void addWorkout(Workout w) {
    history.insert(0, w);
    if (keep) _save();
    _col?.doc(w.id).set(w.toJson()).catchError((_) {});
    notifyListeners();
  }

  void removeWorkout(Workout w) {
    history.remove(w);
    if (keep) _save();
    _col?.doc(w.id).delete().catchError((_) {});
    notifyListeners();
  }

  // ---- Autenticación local ----
  String _h(String s) => sha256.convert(utf8.encode(s)).toString();

  // ---- Firebase Auth + Firestore ----
  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? get user => _auth.currentUser;
  String get email => user?.email ?? '';
  String get lastEmail => prefs.getString('last_email') ?? '';
  bool get remembered => user != null && (prefs.getBool('remember') ?? true);

  String err(Object e) {
    if (e is String) return e;
    // Errores de Google Sign-In (Gmail)
    if (e is PlatformException) {
      final t = '${e.code} ${e.message}';
      if (t.contains('ApiException: 10') || t.contains('DEVELOPER_ERROR')) {
        return 'Google: falta registrar la huella SHA-1 de la app en Firebase y descargar de nuevo google-services.json';
      }
      if (t.contains('ApiException: 7') || e.code == 'network_error') return 'Google: sin conexión a internet';
      if (t.contains('12501') || e.code == 'sign_in_canceled') return 'Inicio de sesión cancelado';
      return 'Google: ${e.message ?? e.code}';
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Correo o contraseña incorrectos';
        case 'email-already-in-use':
          return 'Ese correo ya está registrado';
        case 'weak-password':
          return 'La contraseña es muy débil';
        case 'invalid-email':
          return 'Correo no válido';
        case 'network-request-failed':
          return 'Sin conexión a internet';
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento';
        case 'operation-not-allowed':
          return 'Activa el proveedor de Google en Firebase → Authentication → Método de acceso';
        case 'account-exists-with-different-credential':
          return 'Ese correo ya está registrado con contraseña. Inicia sesión con correo y contraseña';
        default:
          return e.message ?? e.code;
      }
    }
    return 'Error: $e';
  }

  Future<String?> _try(Future<void> Function() f) async {
    try {
      await f();
      await syncDown();
      return null;
    } catch (e) {
      return err(e);
    }
  }

  Future<String?> register(String e, String p, {String name = ''}) {
    prefs.setString('last_email', e);
    if (name.isNotEmpty) prefs.setString('name', name);
    return _try(() async {
      final c = await _auth.createUserWithEmailAndPassword(email: e, password: p);
      if (name.isNotEmpty) {
        try {
          await c.user?.updateDisplayName(name);
          await c.user?.reload();
        } catch (_) {}
      }
    });
  }

  Future<String?> login(String e, String p, bool remember) {
    prefs.setBool('remember', remember);
    prefs.setString('last_email', e);
    return _try(() => _auth.signInWithEmailAndPassword(email: e, password: p));
  }

  Future<String?> resetPass(String e) async {
    try {
      await _auth.sendPasswordResetEmail(email: e);
      return null;
    } catch (x) {
      return err(x);
    }
  }

  Future<String?> google() => _try(() async {
    final g = await GoogleSignIn().signIn();
    if (g == null) throw 'Inicio de sesión cancelado';
    final a = await g.authentication;
    await _auth.signInWithCredential(GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken));
  });

  Future<String?> apple() => _try(() async {
    final c = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email]);
    await _auth.signInWithCredential(OAuthProvider('apple.com').credential(idToken: c.identityToken, accessToken: c.authorizationCode));
  });

  Future<void> logout() async {
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    history = [];
    prefs.remove('history');
    _clearBody();
    unlocked = false;
    notifyListeners();
  }

  CollectionReference<Map<String, dynamic>>? get _col =>
      user == null ? null : FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('workouts');

  /// Descarga el historial de la nube y sube lo que solo existía local.
  Future<void> syncDown() async {
    final c = _col;
    if (c == null) return;
    await _loadBody();
    try {
      final snap = await c.get();
      final remote = {for (final d in snap.docs) d.id: Workout.fromJson(d.data())};
      for (final w in history) {
        if (!remote.containsKey(w.id)) {
          remote[w.id] = w;
          c.doc(w.id).set(w.toJson());
        }
      }
      history = remote.values.toList()..sort((a, b) => b.date.compareTo(a.date));
      if (keep) _save();
      notifyListeners();
    } catch (_) {}
  }

  bool get hasPin => prefs.containsKey('pin');
  void setPin(String p) => prefs.setString('pin', _h(p));
  bool checkPin(String p) => prefs.getString('pin') == _h(p);

  Future<bool> bioAvailable() async {
    try {
      final a = LocalAuthentication();
      return await a.isDeviceSupported() && await a.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> biometric() async {
    try {
      final a = LocalAuthentication();
      if (!await a.isDeviceSupported()) return false;
      return await a.authenticate(
        localizedReason: 'Coloca tu huella dactilar para continuar',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Sesión de entrenamiento: cronómetro + GPS + pasos reales.
class Session extends ChangeNotifier {
  int secs = 0;
  double km = 0, speed = 0;
  bool paused = false;
  final List<LatLng> route = [];
  final List<double> speeds = [];
  final int _base = S.todaySteps;
  Timer? _t;
  StreamSubscription<Position>? _g;

  int get steps {
    final real = S.todaySteps - _base;
    return real > 0 ? real : (km * 1000 / S.strideM).round(); // sin podómetro: estimación por GPS
  }

  int get cal => (steps * S.calPerStep).round();
  String get intensity => speed < .5 ? 'Descanso' : (speed < 1.8 ? 'Caminata' : 'Trote');

  /// Distancia estimada con el podómetro (zancada promedio 0.75 m), útil cuando no hay señal GPS.
  double get stepKm => steps * S.strideM / 1000;
  double get bestKm => km > 0.01 ? km : stepKm;
  /// Posición en vivo (se actualiza con cada lectura del GPS, aunque estés quieto).
  LatLng? live;
  double accuracy = 0, gpsHeading = 0;
  LatLng? get pos => live ?? (route.isEmpty ? null : route.last);

  /// GPS en primer plano: en Android usa un servicio con notificación
  /// persistente; en iOS habilita el indicador de ubicación en segundo plano.
  LocationSettings _settings() {
    final acc = S.saver ? LocationAccuracy.medium : LocationAccuracy.best;
    final filter = S.saver ? 10 : 0; // 0 = cada lectura → mapa en tiempo real
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: acc,
        distanceFilter: filter,
        intervalDuration: Duration(milliseconds: S.saver ? 4000 : 1000),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'PulseX - Entrenamiento en curso',
          notificationText: 'Registrando tu ruta con GPS',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: acc,
        activityType: ActivityType.fitness,
        distanceFilter: filter,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return LocationSettings(accuracy: acc, distanceFilter: filter);
  }

  void start() {
    var last = DateTime.now();
    var acc = 0.0;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (!paused) acc += now.difference(last).inMilliseconds / 1000;
      last = now;
      if (acc >= 1) {
        secs += acc.floor();
        acc -= acc.floor();
        notifyListeners();
      }
    });
    // Ubicación inmediata (última conocida) para que el mapa no espere el primer fix.
    Geolocator.getLastKnownPosition().then((p) {
      if (p != null && live == null) {
        live = LatLng(p.latitude, p.longitude);
        accuracy = p.accuracy;
        notifyListeners();
      }
    }).catchError((_) {});
    try {
      _g = Geolocator.getPositionStream(
        locationSettings: _settings(),
      ).listen((p) {
        final ll = LatLng(p.latitude, p.longitude);
        live = ll;
        accuracy = p.accuracy;
        if (p.speed > .5 && p.heading >= 0) gpsHeading = p.heading;
        if (paused) {
          notifyListeners();
          return;
        }
        // La ruta solo suma puntos confiables (precisión ≤ 25 m y desplazamiento ≥ 2 m) para evitar "saltos".
        if (p.accuracy <= 25) {
          if (route.isEmpty) {
            route.add(ll);
          } else {
            final d = Geolocator.distanceBetween(route.last.latitude, route.last.longitude, ll.latitude, ll.longitude);
            if (d >= 2) {
              km += d / 1000;
              route.add(ll);
            }
          }
        }
        speed = p.speed < 0 ? 0 : p.speed;
        speeds.add(speed);
        if (speeds.length > 40) speeds.removeAt(0);
        notifyListeners();
      }, onError: (_) {});
    } catch (_) {}
  }

  void toggle() {
    paused = !paused;
    notifyListeners();
  }

  Workout finish() {
    var r = route;
    if (r.length > 400) {
      final k = (r.length / 400).ceil();
      r = [for (var i = 0; i < r.length; i += k) r[i]];
    }
    return Workout(DateTime.now(), secs, steps, bestKm, cal, r);
  }

  @override
  void dispose() {
    _t?.cancel();
    _g?.cancel();
    super.dispose();
  }
}