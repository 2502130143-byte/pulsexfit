# PulseX 💜⚡ — Fitness App con sensores y GPS

Aplicación móvil de fitness hecha en **Flutter** para Android (Proyecto Final, Parcial 3 — Desarrollo de Aplicaciones Móviles, UPFIM).

## Funciones
- 🔐 **Huella dactilar** (local_auth) con PIN de respaldo y contraseña segura
- 👣 **Podómetro**: pasos del día y de cada sesión, distancia por zancada
- 📈 **Acelerómetro**: clasifica Descanso / Caminata / Trote
- 🌀 **Giroscopio**: velocidad angular (°/s), orientación e inclinación
- 🗺️ **GPS y mapa en tiempo real** (OpenStreetMap, sin API key)
- 👻 **Modo Fantasma**: compite en vivo contra tus entrenamientos anteriores
- 🗣️ **Entrenador de voz**: anuncia kilómetros, ritmo y el duelo
- 🤖 **PulseBot**: avatar animado que reacciona a tu movimiento
- 🧠 **Entrenador Pulse IA**: recomendaciones según tu historial
- 💾 Historial local (SharedPreferences) + respaldo en **Firebase** (Auth y Firestore)
- 🔋 Permisos con diálogos claros y liberación de sensores en segundo plano

## Tecnologías
Flutter · Dart · Firebase Auth · Cloud Firestore · local_auth · pedometer · sensors_plus · flutter_compass · geolocator · flutter_map · permission_handler · battery_plus · flutter_tts

## Cómo ejecutarlo
```bash
flutter pub get
flutter run
```
Requiere un teléfono Android 8.0+ con huella, acelerómetro, giroscopio, podómetro y GPS.

## Estructura
```
lib/
├── main.dart          # arranque y ciclo de vida
├── services.dart      # estado, sesión de entrenamiento y persistencia
├── permissions.dart   # permisos en tiempo de ejecución
├── ui.dart            # sistema de diseño neón
├── popups.dart        # ventanas emergentes
├── pulsebot.dart      # avatar animado
├── ghost.dart         # Modo Fantasma y entrenador de voz
├── auth.dart          # bienvenida, login, registro, huella
├── body_form.dart     # datos físicos
├── shell.dart         # navegación, inicio, Pulse IA, perfil
└── workout.dart       # entrenamiento, mapa, sensores, historial
```

**Autora:** Jolette Camargo Avendaño — UPFIM, Ingeniería en Tecnologías de la Información e Innovación Digital
