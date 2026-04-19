import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart'; // <-- Importamos LatLng para el trazado
import '../../domain/models/route_models.dart';

class RouteRepository {

  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  Future<DecisionResponse> evaluateRoute(double distanceKm) async {
    final url = Uri.parse('$baseUrl/routes/evaluate');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'distancia_km': distanceKm}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DecisionResponse.fromJson(data);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión con el Cerebro Digital: $e');
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