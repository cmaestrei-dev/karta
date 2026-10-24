import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_errors.dart';
import 'config.dart';

/// Error que se le puede mostrar al viajero tal cual.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Cliente HTTP común: URL base, JSON, token Bearer, tiempo límite y errores en lenguaje claro.
class ApiClient {
  static const _timeout = Duration(seconds: 15);

  final String? Function() _token;
  final http.Client _http;

  ApiClient({required String? Function() token, http.Client? client})
      : _token = token,
        _http = client ?? http.Client();

  /// [sesionSiHay]: manda el token si existe, sin exigirlo (la API responde distinto con sesión).
  Future<dynamic> get(String path, {Map<String, String>? query, bool auth = false, bool sesionSiHay = false}) =>
      _send('GET', path, query: query, auth: auth, sesionSiHay: sesionSiHay);

  Future<dynamic> post(String path, Object body, {bool auth = false}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, Object body, {bool auth = false}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<void> delete(String path, {bool auth = false}) => _send('DELETE', path, auth: auth);

  Future<dynamic> _send(String metodo, String path,
      {Map<String, String>? query, Object? body, bool auth = false, bool sesionSiHay = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = _token();
      if (token == null) throw SessionExpiredException();
      headers['Authorization'] = 'Bearer $token';
    } else if (sesionSiHay) {
      final token = _token();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final request = http.Request(metodo, Uri.parse('$apiBaseUrl$path').replace(queryParameters: query))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException('La conexión está muy lenta. Intenta de nuevo.');
    } catch (_) {
      throw const ApiException('No hay conexión con Karta. Revisa tus datos o tu Wi-Fi.');
    }

    if (response.statusCode == 401 && auth) throw SessionExpiredException();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(response));
    }
    if (response.bodyBytes.isEmpty) return null;
    return json.decode(utf8.decode(response.bodyBytes));
  }
}
