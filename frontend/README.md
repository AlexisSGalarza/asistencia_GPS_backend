# frontend — Asistencia GPS

## Probar en celular (WiFi y ubicación)

Para probar en un **celular real** (y que funcione la detección de WiFi y la ubicación):

1. **API en tu computadora:** en la carpeta del backend ejecuta:
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```
2. **Misma red WiFi:** el celular y la PC/Mac deben estar en la misma red.
3. **URL del backend en la app:** en `lib/services/api_service.dart`:
   - Pon `_usarCelularReal = true`.
   - En `_ipServidor` escribe la **IP local** de tu computadora (ej. `192.168.1.100`). En Mac: Preferencias del Sistema → Red; en Windows: `ipconfig`.
4. **Permisos:** la app pide ubicación al entrar a "Marcar asistencia". En Android 9+ la lectura del WiFi también requiere permiso de ubicación; ya está contemplado. Acepta los permisos cuando el sistema los pida.
5. **WiFi:** para que "Red autorizada" funcione, en el backend (admin) debes tener configurado al menos un perímetro/red con el SSID o BSSID de la red a la que se conecta el celular.

**Roles:** Solo los **maestros** registran entrada/salida en "Marcar asistencia". Los **supervisores** usan incidencias, historial de equipo y reportes; no marcan asistencia. Si en el futuro los supervisores también deben marcar, se puede habilitar la misma pantalla para ese rol.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
