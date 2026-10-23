import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Obtiene la ubicación actual del viajero validando el GPS y los permisos.
///
/// Si el GPS no responde a tiempo usa la última ubicación conocida del teléfono.
/// En modo debug, si tampoco hay una (p. ej. en Linux de escritorio), devuelve una
/// coordenada de respaldo en Cartagena para poder probar la app.
/// En release nunca se inventa una ubicación.
class LocationService {
  static const LatLng _devFallback = LatLng(10.4225, -75.5410);
  static const Duration _timeout = Duration(seconds: 10);

  static Future<({LatLng point, bool isFallback})> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('El GPS está apagado. Enciéndelo para continuar.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Permisos de ubicación denegados.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Los permisos de GPS están bloqueados permanentemente.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(_timeout);
      return (point: LatLng(position.latitude, position.longitude), isFallback: false);
    } catch (e) {
      // Con el GPS en frío la lectura precisa puede tardar; la última conocida del teléfono sirve.
      final lastKnown = await _lastKnownPosition();
      if (lastKnown != null) {
        return (point: LatLng(lastKnown.latitude, lastKnown.longitude), isFallback: false);
      }
      if (!kDebugMode) {
        throw Exception('No se pudo obtener tu ubicación. Intenta de nuevo.');
      }
      debugPrint('GPS no disponible ($e). Usando coordenada de respaldo.');
      return (point: _devFallback, isFallback: true);
    }
  }

  static Future<Position?> _lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null; // No soportado en web ni en Linux de escritorio.
    }
  }
}
