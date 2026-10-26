import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';

/// La política de tratamiento de datos (Ley 1581), como la sirve la API.
class Politica {
  final String version;
  final String vigenteDesde;

  /// El correo para consultas y reclamos, que el aviso de privacidad muestra.
  final String correo;

  /// Markdown: títulos, párrafos, listas, negrillas y enlaces.
  final String texto;

  const Politica({
    required this.version,
    required this.vigenteDesde,
    required this.correo,
    required this.texto,
  });

  factory Politica.fromJson(Map<String, dynamic> json) => Politica(
        version: json['version'] as String,
        vigenteDesde: json['vigente_desde'] as String,
        correo: json['correo'] as String,
        texto: json['texto'] as String,
      );
}

/// Trae la política y guarda la autorización: en el teléfono (para no recoger nada antes de aceptarla) y en la
/// cuenta (la prueba que exige el Decreto 1074, art. 2.2.2.25.2.5).
class PoliticaRepository {
  static const _clave = 'karta_politica_aceptada';

  final ApiClient api;

  PoliticaRepository({required this.api});

  Future<Politica> politica() async => Politica.fromJson(await api.get('/legal/politica') as Map<String, dynamic>);

  /// La versión que se aceptó en este teléfono, o null si nunca se aceptó.
  Future<String?> aceptadaEnEsteTelefono() async => (await SharedPreferences.getInstance()).getString(_clave);

  Future<void> aceptarEnEsteTelefono(String version) async =>
      (await SharedPreferences.getInstance()).setString(_clave, version);

  /// Guarda en la cuenta que aceptó esa versión, y cuándo.
  Future<void> registrar(String version) => api.post('/users/me/autorizacion', {'version': version}, auth: true);
}
