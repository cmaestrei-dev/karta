import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/incident_models.dart';

class IncidentRepository {
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

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