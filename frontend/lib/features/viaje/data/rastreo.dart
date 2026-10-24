import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../trip/domain/trip_models.dart';

/// Viaje de prueba: con `--dart-define=KARTA_SIMULAR_VIAJE=true` el viaje recorre el trazado solo, más rápido,
/// para probar los avisos sin subirse a un bus. La pantalla lo dice siempre («Simulación»): nunca se mezcla
/// con un viaje real.
const simularViaje = bool.fromEnvironment('KARTA_SIMULAR_VIAJE');

/// Posiciones del viaje activo.
abstract final class Rastreo {
  /// En Android corre en un servicio en primer plano con su notificación fija: sigue con la pantalla apagada
  /// y aunque el viajero cambie de app.
  static Stream<LatLng> posiciones(RouteOption opcion) {
    if (simularViaje) return _simulacion(opcion);
    final LocationSettings ajustes = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 3),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Karta te acompaña en el viaje',
              notificationText: 'Te avisamos antes de bajarte',
              notificationIcon: AndroidResource(name: 'ic_notificacion', defType: 'drawable'),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    return Geolocator.getPositionStream(locationSettings: ajustes).map((p) => LatLng(p.latitude, p.longitude));
  }

  /// Recorre cada tramo en orden: caminando a ~10 m/s y en bus a ~40 m/s, con una espera corta en la parada.
  static Stream<LatLng> _simulacion(RouteOption opcion) async* {
    const distancia = Distance();
    for (final tramo in opcion.tramos) {
      final paso = tramo.esCaminata ? 10.0 : 40.0;
      if (!tramo.esCaminata && tramo.puntos.isNotEmpty) {
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          yield tramo.puntos.first;
        }
      }
      for (var k = 0; k + 1 < tramo.puntos.length; k++) {
        final a = tramo.puntos[k], b = tramo.puntos[k + 1];
        final pasos = (distancia.as(LengthUnit.Meter, a, b) / paso).ceil().clamp(1, 10000);
        for (var i = 1; i <= pasos; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final t = i / pasos;
          yield LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
        }
      }
    }
  }
}
