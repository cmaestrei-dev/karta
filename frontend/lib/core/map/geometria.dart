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
