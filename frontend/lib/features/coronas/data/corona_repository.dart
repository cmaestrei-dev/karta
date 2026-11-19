import '../../../core/api_client.dart';
import '../domain/corona_models.dart';

/// Las coronas de las estaciones (docs/plan-juego.md, fase B).
class CoronaRepository {
  final ApiClient api;

  CoronaRepository({required this.api});

  Future<CoronaDeEstacion> corona(String estacion) async =>
      CoronaDeEstacion.fromJson(await api.get('/stations/$estacion/crown', sesionSiHay: true) as Map<String, dynamic>);

  /// Quien reina le pone el apodo del día. El servidor lo revisa: si no pasa, ApiException con el motivo.
  Future<CoronaDeEstacion> ponerApodo(String estacion, String texto) async => CoronaDeEstacion.fromJson(
      await api.put('/stations/$estacion/crown/nickname', {'texto': texto}, auth: true) as Map<String, dynamic>);

  /// Devuelve si con este reporte el apodo quedó oculto.
  Future<bool> reportarApodo(String estacion) async =>
      ((await api.post('/stations/$estacion/crown/nickname/reports', const {}, auth: true)) as Map)['oculto'] as bool;

  Future<AjustesDeCorona> ajustes() async =>
      AjustesDeCorona.fromJson(await api.get('/users/me/crown', auth: true) as Map<String, dynamic>);

  /// Participar (la autorización para esta finalidad) y cómo mostrarse. Lo que va en null no cambia; un apodo vacío
  /// lo quita.
  Future<AjustesDeCorona> ajustar({bool? participa, bool? visible, String? apodo}) async =>
      AjustesDeCorona.fromJson(await api.put('/users/me/crown', {
        'participa': ?participa,
        'visible': ?visible,
        'apodo': ?apodo,
      }, auth: true) as Map<String, dynamic>);
}
