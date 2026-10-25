import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

/// Radio alrededor de un recorrido en el que un reporte cuenta para su riesgo (RADIO_BUSQUEDA_M del backend).
const radioDeRiesgoM = 500.0;

/// Distancia aproximada en metros de un punto a una polilínea, en una proyección local plana:
/// a la escala de una ciudad el error es despreciable.
double distanciaALineaM(LatLng punto, List<LatLng> linea) {
  if (linea.isEmpty) return double.infinity;
  const metrosPorGradoLat = 110540.0;
  final metrosPorGradoLon = 111320.0 * math.cos(punto.latitude * math.pi / 180);
  Offset local(LatLng q) => Offset(
        (q.longitude - punto.longitude) * metrosPorGradoLon,
        (q.latitude - punto.latitude) * metrosPorGradoLat,
      );
  var minima = local(linea.first).distance;
  for (var k = 0; k + 1 < linea.length; k++) {
    final a = local(linea[k]);
    final ab = local(linea[k + 1]) - a;
    final largo2 = ab.distanceSquared;
    final t = largo2 == 0 ? 0.0 : (-(a.dx * ab.dx + a.dy * ab.dy) / largo2).clamp(0.0, 1.0);
    minima = math.min(minima, (a + ab * t).distance);
  }
  return minima;
}

/// Dónde cae un punto sobre una polilínea: cuántos metros desde el comienzo ([avanceM]), a qué distancia de
/// ella está ([distanciaM]) y cuánto mide la línea ([largoM]).
typedef Proyeccion = ({double avanceM, double distanciaM, double largoM});

/// Proyecta [punto] sobre [linea] en una proyección local plana. Con [desdeM] solo considera los tramos que
/// terminan después de ese avance: en una ruta de ida y vuelta, el bus no «salta» al carril del regreso.
Proyeccion proyectarEnLinea(LatLng punto, List<LatLng> linea, {double desdeM = 0}) {
  if (linea.length < 2) {
    final d = linea.isEmpty ? double.infinity : const Distance().as(LengthUnit.Meter, punto, linea.first);
    return (avanceM: 0, distanciaM: d, largoM: 0);
  }
  const metrosPorGradoLat = 110540.0;
  final metrosPorGradoLon = 111320.0 * math.cos(punto.latitude * math.pi / 180);
  Offset local(LatLng q) => Offset(
        (q.longitude - punto.longitude) * metrosPorGradoLon,
        (q.latitude - punto.latitude) * metrosPorGradoLat,
      );
  var acumulado = 0.0;
  var mejor = (avanceM: 0.0, distanciaM: double.infinity);
  for (var k = 0; k + 1 < linea.length; k++) {
    final a = local(linea[k]);
    final ab = local(linea[k + 1]) - a;
    final largo = ab.distance;
    if (acumulado + largo >= desdeM) {
      final t = largo == 0 ? 0.0 : (-(a.dx * ab.dx + a.dy * ab.dy) / (largo * largo)).clamp(0.0, 1.0);
      final distancia = (a + ab * t).distance;
      if (distancia < mejor.distanciaM) mejor = (avanceM: acumulado + largo * t, distanciaM: distancia);
    }
    acumulado += largo;
  }
  return (avanceM: mejor.avanceM, distanciaM: mejor.distanciaM, largoM: acumulado);
}
