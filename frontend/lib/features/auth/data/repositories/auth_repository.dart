import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api_errors.dart';
import '../../../../core/config.dart';
import '../../domain/models/usuario.dart';

/// Inicia, recupera y cierra la sesión. El token se guarda en el almacenamiento
/// seguro de cada plataforma (Keystore en Android, Keychain en iOS, libsecret en Linux).
class AuthRepository {
  static const _tokenKey = 'karta_access_token';
  static const _timeout = Duration(seconds: 15);

  final FlutterSecureStorage _storage;
  String? _token;

  AuthRepository({FlutterSecureStorage storage = const FlutterSecureStorage()}) : _storage = storage;

  /// Token de la sesión activa, o null si no hay sesión.
  String? get token => _token;

  Future<Usuario> login({required String email, required String password}) {
    return _startSession('/auth/login', {'email': email, 'password': password});
  }

  Future<Usuario> register({
    required String nombre,
    required String email,
    required String password,
    required String tipoViajero,
  }) {
    return _startSession('/auth/register', {
      'nombre': nombre,
      'email': email,
      'password': password,
      'tipo_viajero': tipoViajero,
      'acepta_terminos': true,
    });
  }

  /// Recupera la sesión guardada. Devuelve null si no hay sesión o ya no es válida.
  Future<Usuario?> restoreSession() async {
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null) return null;

    final response = await _send(() => http.get(
          Uri.parse('$apiBaseUrl/users/me'),
          headers: {'Authorization': 'Bearer $saved'},
        ));

    if (response.statusCode == 401) {
      await logout();
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception(apiErrorMessage(response));
    }
    _token = saved;
    return Usuario.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<Usuario> _startSession(String path, Map<String, dynamic> body) async {
    final response = await _send(() => http.post(
          Uri.parse('$apiBaseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(apiErrorMessage(response));
    }
    final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    await _storage.write(key: _tokenKey, value: _token);
    return Usuario.fromJson(data['usuario']);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } catch (_) {
      throw Exception('No se pudo conectar con el servidor de Karta.');
    }
  }
}
