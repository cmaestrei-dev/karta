import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/progreso.dart';

/// Guarda el progreso del juego en el teléfono. Las escrituras van en fila, para que dos avisos seguidos del viaje
/// (un sello y una lámina) no se pisen.
class ProgresoLocal {
  static const _clave = 'karta_juego';
  Future<void> _fila = Future.value();

  Future<ProgresoDeJuego> leer() async {
    final texto = (await SharedPreferences.getInstance()).getString(_clave);
    if (texto == null) return const ProgresoDeJuego();
    try {
      return ProgresoDeJuego.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } on FormatException {
      return const ProgresoDeJuego();
    } on TypeError {
      return const ProgresoDeJuego();
    }
  }

  /// Lee, cambia y guarda, en fila. Devuelve lo que [cambio] devuelva junto al progreso nuevo.
  Future<T> cambiar<T>(({ProgresoDeJuego progreso, T resultado}) Function(ProgresoDeJuego actual) cambio) {
    final hecho = _fila.then((_) async {
      final r = cambio(await leer());
      await (await SharedPreferences.getInstance()).setString(_clave, jsonEncode(r.progreso.toJson()));
      return r.resultado;
    });
    _fila = hecho.then((_) {}, onError: (_) {});
    return hecho;
  }

  /// Al borrar la cuenta: el álbum, los sellos y las medallas también se van.
  Future<void> borrar() async => (await SharedPreferences.getInstance()).remove(_clave);
}
