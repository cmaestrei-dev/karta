import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/api_errors.dart';
import '../../../../core/config.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../domain/models/incident_models.dart';

class IncidentRepository {
  final AuthRepository authRepository;
  final String baseUrl = '$apiBaseUrl/incidents';

  IncidentRepository({required this.authRepository});

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
    final token = authRepository.token;
    if (token == null) throw SessionExpiredException();

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(incident.toJson()),
      );
    } catch (e) {
      throw Exception('Error de conexión con el servidor de Karta: $e');
    }

    if (response.statusCode == 401) throw SessionExpiredException();
    if (response.statusCode != 201) {
      throw Exception(apiErrorMessage(response, fallback: 'Fallo al registrar el incidente.'));
    }
  }
}
