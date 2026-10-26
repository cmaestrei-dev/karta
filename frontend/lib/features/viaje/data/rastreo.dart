import 'dart:async';
import 'dart:math' as math;

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

  /// Posiciones durante un viaje de mapeo: cada 2 s aunque el bus esté quieto, para saber cuándo se detiene.
  static Stream<LatLng> paraMapear(List<LatLng> recorrido, LatLng? desde) {
    if (simularViaje) return _simulacionDeMapeo(recorrido, desde);
    final LocationSettings ajustes = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 2),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Karta está mapeando la ruta',
              notificationText: 'Toca «paró aquí» en cada paradero',
              notificationIcon: AndroidResource(name: 'ic_notificacion', defType: 'drawable'),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
    return Geolocator.getPositionStream(locationSettings: ajustes).map((p) => LatLng(p.latitude, p.longitude));
  }

  /// Recorre el trazado desde el punto más cercano a [desde], rápido, y para 14 s cada ~350 m como en un paradero.
  static Stream<LatLng> _simulacionDeMapeo(List<LatLng> recorrido, LatLng? desde) async* {
    if (recorrido.length < 2) return;
    const distancia = Distance();
    var k = 0;
    if (desde != null) {
      var mejor = double.infinity;
      for (final (i, p) in recorrido.indexed) {
        final d = distancia.as(LengthUnit.Meter, p, desde);
        if (d < mejor) (k, mejor) = (i, d);
      }
    }
    var desdeLaParada = 0.0;
    for (; k + 1 < recorrido.length; k++) {
      final a = recorrido[k], b = recorrido[k + 1];
      final largo = distancia.as(LengthUnit.Meter, a, b);
      for (var hecho = 0.0; hecho < largo; hecho += 12) {
        final t = largo <= 0 ? 1.0 : hecho / largo;
        final punto = LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
        desdeLaParada += 12;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        yield punto;
        if (desdeLaParada >= 350) {
          desdeLaParada = 0;
          for (var i = 0; i < 28; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            yield punto;
          }
        }
      }
    }
  }

  /// Recorre cada tramo en orden, una posición cada medio segundo: caminando a ~20 m/s y en bus a ~80 m/s para no
  /// esperar, con una pausa corta en la parada. En los últimos 300 m el bus frena (~10 m/s), como uno de verdad al
  /// llegar: así se alcanzan a ver los avisos de bajarse y la pantalla de pedir la parada.
  static Stream<LatLng> _simulacion(RouteOption opcion) async* {
    const distancia = Distance();
    for (final tramo in opcion.tramos) {
      final puntos = tramo.puntos;
      if (puntos.isEmpty) continue;
      if (!tramo.esCaminata) {
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          yield puntos.first;
        }
      }
      final largos = [0.0];
      for (var k = 0; k + 1 < puntos.length; k++) {
        largos.add(largos.last + distancia.as(LengthUnit.Meter, puntos[k], puntos[k + 1]));
      }
      final total = largos.last;
      var avance = 0.0;
      var k = 0;
      while (avance < total) {
        final paso = tramo.esCaminata ? 10.0 : (total - avance <= 300 ? 5.0 : 40.0);
        avance = math.min(total, avance + paso);
        while (k < largos.length - 2 && largos[k + 1] < avance) {
          k++;
        }
        final largo = largos[k + 1] - largos[k];
        final t = largo <= 0 ? 1.0 : (avance - largos[k]) / largo;
        final a = puntos[k], b = puntos[k + 1];
        await Future<void>.delayed(const Duration(milliseconds: 500));
        yield LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
      }
    }
  }
}
