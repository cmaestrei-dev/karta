import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api_errors.dart';
import '../../../../core/config.dart';
import '../../../legal/data/politica_repository.dart';
import '../../domain/models/usuario.dart';

/// Inicia, recupera y cierra la sesión. El token se guarda en el almacenamiento
/// seguro de cada plataforma (Keystore en Android, Keychain en iOS, libsecret en Linux).
///
/// Sin registrarse se usa la cuenta invisible del teléfono: un secreto aleatorio, generado la primera vez y
/// guardado aquí, que el servidor cambia por la sesión de esa cuenta (la misma siempre).
class AuthRepository {
  static const _tokenKey = 'karta_access_token';
  static const _usuarioKey = 'karta_usuario';
  static const _secretoKey = 'karta_secreto_del_telefono';
  static const _timeout = Duration(seconds: 15);
  static const _timeoutAlAbrir = Duration(seconds: 6);

  final FlutterSecureStorage _storage;
  String? _token;
  Usuario? _actual;

  AuthRepository({FlutterSecureStorage storage = const FlutterSecureStorage()}) : _storage = storage;

  /// Token de la sesión activa, o null si no hay sesión.
  String? get token => _token;

  /// Entra con la cuenta invisible del teléfono (la crea la primera vez). Con la versión de la política que se aceptó
  /// en el teléfono: el servidor guarda la prueba en la misma petición, sin depender de que después haya señal, y no
  /// recibe datos de una cuenta sin ella.
  Future<Usuario> entrarSinCuenta() async => _startSession('/auth/anonymous', {
        'secreto': await _secreto(),
        'politica': ?await PoliticaRepository.versionAceptada(),
      });

  /// Si la sesión que venció era la invisible, la renueva sin molestar al viajero. Devuelve si lo logró.
  Future<bool> renovarSiEsInvisible() async {
    if (_actual?.sinCuenta != true) return false;
    try {
      await entrarSinCuenta();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _secreto() async {
    final guardado = await _storage.read(key: _secretoKey);
    if (guardado != null) return guardado;
    final azar = Random.secure();
    final nuevo = base64UrlEncode([for (var i = 0; i < 32; i++) azar.nextInt(256)]).replaceAll('=', '');
    await _storage.write(key: _secretoKey, value: nuevo);
    return nuevo;
  }

  Future<Usuario> login({required String email, required String password}) async {
    return _startSession('/auth/login', {
      'email': email,
      'password': password,
      'politica': ?await PoliticaRepository.versionAceptada(),
    });
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
    }, conSesion: _actual?.sinCuenta == true);
  }

  /// Recupera la sesión guardada. Devuelve null si no hay sesión o el servidor la rechazó.
  /// Sin señal se entra con el perfil guardado: una mala conexión no debe cerrar la sesión.
  Future<Usuario?> restoreSession() async {
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null) return null;
    final guardado = await _storage.read(key: _usuarioKey);
    final usuarioGuardado = guardado == null ? null : Usuario.fromJson(json.decode(guardado));

    final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$apiBaseUrl/users/me'), headers: {'Authorization': 'Bearer $saved'})
          .timeout(_timeoutAlAbrir);
    } catch (_) {
      if (usuarioGuardado == null) throw Exception('No se pudo conectar con el servidor de Karta.');
      _token = saved;
      return _actual = usuarioGuardado;
    }

    if (response.statusCode == 401) {
      await logout();
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception(apiErrorMessage(response));
    }
    _token = saved;
    final usuario = _actual = Usuario.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    await _storage.write(key: _usuarioKey, value: json.encode(usuario.toJson()));
    return usuario;
  }

  /// Vuelve a pedir el perfil (la reputación cambia cuando la comunidad vota tus reportes).
  /// Devuelve null si no hay sesión o no hubo señal; lanza [SesionVencida] si el servidor ya no la acepta.
  Future<Usuario?> refresh() async {
    final token = _token;
    if (token == null) return null;
    final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$apiBaseUrl/users/me'), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
    } catch (_) {
      return null;
    }
    if (response.statusCode == 401) throw const SesionVencida();
    if (response.statusCode != 200) return null;
    final usuario = _actual = Usuario.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    await _storage.write(key: _usuarioKey, value: json.encode(usuario.toJson()));
    return usuario;
  }

  /// Borra la cuenta en el servidor (derecho de supresión, Ley 1581) y lo que este teléfono guarda de ella, el secreto
  /// incluido: la próxima cuenta invisible es otra, sin nada que la ligue a la borrada. Lanza [SesionVencida] si la
  /// sesión ya no sirve.
  Future<void> borrarCuenta() async {
    final token = _token;
    if (token == null) throw const SesionVencida();
    final response = await _send(() => http.delete(
          Uri.parse('$apiBaseUrl/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        ));
    if (response.statusCode == 401) throw const SesionVencida();
    if (response.statusCode != 204) throw Exception(apiErrorMessage(response));
    await logout();
    await _storage.delete(key: _secretoKey);
  }

  /// Cierra la sesión; el secreto del teléfono se queda para volver a su cuenta invisible.
  Future<void> logout() async {
    _token = null;
    _actual = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usuarioKey);
  }

  Future<Usuario> _startSession(String path, Map<String, dynamic> body, {bool conSesion = false}) async {
    final response = await _send(() => http.post(
          Uri.parse('$apiBaseUrl$path'),
          headers: {'Content-Type': 'application/json', if (conSesion && _token != null) 'Authorization': 'Bearer $_token'},
          body: jsonEncode(body),
        ));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(apiErrorMessage(response));
    }
    final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    final usuario = _actual = Usuario.fromJson(data['usuario']);
    await _storage.write(key: _tokenKey, value: _token);
    await _storage.write(key: _usuarioKey, value: json.encode(usuario.toJson()));
    return usuario;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } catch (_) {
      throw Exception('No se pudo conectar con el servidor de Karta.');
    }
  }
}

class SesionVencida implements Exception {
  const SesionVencida();
}
