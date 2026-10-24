import 'package:latlong2/latlong.dart';

import '../../../../core/api_client.dart';
import '../../domain/models/incident_models.dart';

class IncidentRepository {
  final ApiClient api;
  Future<CatalogoDeReportes>? _catalogo;

  IncidentRepository({required this.api});

  /// El catálogo cambia solo con una nueva versión del backend: se pide una vez por sesión de la app.
  Future<CatalogoDeReportes> catalogo() {
    return _catalogo ??= api
        .get('/incidents/types')
        .then((data) => CatalogoDeReportes.fromJson(data as List<dynamic>))
        .catchError((Object e) {
      _catalogo = null; // si falló, el próximo intento vuelve a pedirlo
      throw e;
    });
  }

  Future<List<Incident>> getActiveIncidents() async {
    final data = await api.get('/incidents/') as List<dynamic>;
    return [for (final json in data) Incident.fromJson(json as Map<String, dynamic>)];
  }

  /// Lanza SessionExpiredException si el token ya no es válido.
  Future<Incident> report({required String tipo, required Map<String, String> detalles, required LatLng punto}) async {
    final data = await api.post(
      '/incidents/',
      {'tipo': tipo, 'detalles': detalles, 'latitud': punto.latitude, 'longitud': punto.longitude},
      auth: true,
    );
    return Incident.fromJson(data as Map<String, dynamic>);
  }

  Future<IncidentDetail> detail(String id) async {
    final data = await api.get('/incidents/$id', sesionSiHay: true);
    return IncidentDetail.fromJson(data as Map<String, dynamic>);
  }

  /// Devuelve el reporte actualizado y si este voto lo retiró del mapa.
  Future<(Incident, bool)> vote(String id, {required bool sigue}) async {
    final data = await api.post('/incidents/$id/votes', {'sigue': sigue}, auth: true) as Map<String, dynamic>;
    return (Incident.fromJson(data['incidente'] as Map<String, dynamic>), data['retirado'] as bool);
  }
}
