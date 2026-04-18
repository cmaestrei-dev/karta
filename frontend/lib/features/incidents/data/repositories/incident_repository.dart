import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:latlong2/latlong.dart';

import '../../domain/models/incident_models.dart';
import '../../../routing/domain/models/route_risk.dart';

class IncidentRepository {
  final String baseUrl = 'http://127.0.0.1:8000/api/v1/incidents';

  Future<List<Incident>> getActiveIncidents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Incident.fromJson(json)).toList();
      } else {
        throw Exception('Fallo al obtener incidentes del servidor');
      }
    } catch (e) {
      throw Exception('Error de conexión con el Cerebro Digital: $e');
    }
  }

  Future<void> reportIncident(IncidentCreate incident) async {
    final url = Uri.parse('$baseUrl/');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(incident.toJson()),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Fallo al registrar el incidente: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión con el servidor de Karta: $e');
    }
  }

  Future<RouteRisk> evaluateRoute(List<LatLng> routePoints) async {
    final url = Uri.parse('$baseUrl/evaluate');
    
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
}