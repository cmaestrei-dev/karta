import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/config.dart';
import '../../domain/models/route_risk.dart';

class RouteRepository {

  Future<RouteRisk> evaluateRisk(List<LatLng> routePoints) async {
    final url = Uri.parse('$apiBaseUrl/routes/risk');

    final List<Map<String, double>> formattedRoute = routePoints.map((point) {
      return {
        'lat': point.latitude,
        'lon': point.longitude,
      };
    }).toList();

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'route': formattedRoute}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return RouteRisk.fromJson(data);
      } else {
        throw Exception('Fallo en la evaluación táctica: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión al evaluar la ruta: $e');
    }
  }

  Future<List<LatLng>> getRealRoute(LatLng start, LatLng end) async {
    final String osrmUrl = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(osrmUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List coordinates = data['routes'][0]['geometry']['coordinates'];

          return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        } else {
          throw Exception('No se encontró una ruta terrestre posible.');
        }
      } else {
        throw Exception('Fallo satelital OSRM: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión al trazar la ruta: $e');
    }
  }
}
