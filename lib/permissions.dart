import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services.dart';
import 'ui.dart';
import 'popups.dart';

/// Permisos en tiempo de ejecución con diálogo informativo previo (RNF-02).
/// Ubicación → GPS y ruta · Actividad física → podómetro · Notificaciones → servicio de GPS en primer plano.
/// La huella (USE_BIOMETRIC) no requiere diálogo: la concede el sistema al instalar.
class Perms {
  static bool _shownThisLaunch = false;

  static List<(Permission, IconData, Color, String, String)> get _list => [
    (Permission.locationWhenInUse, Icons.location_on, cyan, 'Ubicación (GPS)', 'Para trazar tu ruta en el mapa y calcular distancia y velocidad.'),
    if (defaultTargetPlatform == TargetPlatform.android) (Permission.activityRecognition, Icons.directions_run, green, 'Actividad física', 'Para contar tus pasos con el podómetro del teléfono.'),
    if (defaultTargetPlatform == TargetPlatform.iOS) (Permission.sensors, Icons.directions_run, green, 'Movimiento y actividad física', 'Para contar tus pasos con el podómetro del teléfono.'),
    (Permission.notification, Icons.notifications_active_outlined, purple, 'Notificaciones', 'Para mostrar el aviso de entrenamiento en curso mientras usas el GPS.'),
  ];

  static Future<List<(Permission, IconData, Color, String, String)>> missing() async {
    final out = <(Permission, IconData, Color, String, String)>[];
    for (final p in _list) {
      try {
        if (!await p.$1.isGranted) out.add(p);
      } catch (_) {}
    }
    return out;
  }

  /// Muestra el diálogo informativo y solicita los permisos que falten.
  static Future<void> ensure(BuildContext c, {bool force = false}) async {
    if (_shownThisLaunch && !force) return;
    _shownThisLaunch = true;
    final miss = await missing();
    if (miss.isEmpty || !c.mounted) return;
    final ok = await popupPermissions(c, [
      (Icons.fingerprint, cyan, 'Biometría (huella)', 'Para proteger tu perfil. La huella la valida el sistema y nunca sale del teléfono.'),
      for (final p in miss) (p.$2, p.$3, p.$4, p.$5),
    ]);
    if (ok != true) {
      if (c.mounted) snack(c, 'Sin permisos algunas funciones no estarán disponibles');
      return;
    }
    var blocked = false;
    for (final p in miss) {
      try {
        final st = await p.$1.request();
        if (st.isPermanentlyDenied) blocked = true;
      } catch (_) {}
    }
    S.startSteps(); // reinicia el podómetro ya con permiso
    if (!c.mounted) return;
    final still = await missing();
    if (!c.mounted) return;
    if (still.isEmpty) {
      snack(c, 'Permisos concedidos ✔');
    } else if (blocked) {
      final go = await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(
          title: const Text('Permisos bloqueados'),
          content: Text('Activa manualmente: ${still.map((e) => e.$4).join(', ')}.', style: const TextStyle(color: soft)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Abrir ajustes')),
          ],
        ),
      );
      if (go == true) openAppSettings();
    } else {
      snack(c, 'Faltan permisos: ${still.map((e) => e.$4).join(', ')}');
    }
  }
}
