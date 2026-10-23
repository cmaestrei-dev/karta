import '../../../../core/api_client.dart';
import '../../domain/models/incident_models.dart';

class IncidentRepository {
  final ApiClient api;

  IncidentRepository({required this.api});

  Future<List<Incident>> getActiveIncidents() async {
    final data = await api.get('/incidents/') as List<dynamic>;
    return data.map((json) => Incident.fromJson(json)).toList();
  }

  /// Lanza SessionExpiredException si el token ya no es válido.
  Future<void> reportIncident(IncidentCreate incident) async {
    await api.post('/incidents/', incident.toJson(), auth: true);
  }
}
