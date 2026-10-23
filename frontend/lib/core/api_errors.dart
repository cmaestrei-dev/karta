import 'dart:convert';
import 'package:http/http.dart' as http;

/// La API respondió 401: el token no existe, expiró o su usuario ya no existe.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Tu sesión expiró. Inicia sesión de nuevo.';
}

/// Extrae el mensaje que envía la API en `{"detail": "..."}`.
String apiErrorMessage(http.Response response, {String fallback = 'Ocurrió un error inesperado.'}) {
  try {
    final body = json.decode(utf8.decode(response.bodyBytes));
    final detail = body is Map ? body['detail'] : null;
    if (detail is String) return detail;
  } catch (_) {
    // Cuerpo vacío o no JSON: se usa el mensaje por defecto.
  }
  if (response.statusCode == 422) return 'Revisa los datos ingresados.';
  return fallback;
}
