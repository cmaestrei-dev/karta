import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/incident_models.dart';

class IncidentRepository {
  final String baseUrl = 'http://127.0.0.1:8000/api/v1/incidents';

  Future<List<Incident>> getActiveIncidents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      
      if (response.statusCode == 200) {
        // Decodificamos usando utf8 para evitar problemas con las tildes (ej. "Tráfico")
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
    final url = Uri.parse('$baseUrl/incidents/');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(incident.toJson()),
      );

      if (response.statusCode != 201) {
        throw Exception('Fallo al registrar el incidente: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión con el servidor de Karta: $e');
    }
  }
}