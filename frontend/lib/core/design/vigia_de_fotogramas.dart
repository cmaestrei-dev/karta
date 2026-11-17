import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo ligero, sugerencia automática (D13): mira los primeros fotogramas que dibuja la app y, si muchos van lentos,
/// avisa una sola vez en la vida de la app para ofrecer el modo ligero. En depuración no mide: ahí todo va lento.
class VigiaDeFotogramas {
  static const _clave = 'karta_modo_ligero_sugerido';

  /// Un fotograma que tarda más que esto se nota: la app va a menos de 30 por segundo.
  static const lento = Duration(milliseconds: 33);

  /// Fotogramas para decidir. Solo se dibujan cuando algo se mueve, así que es el uso real del mapa.
  static const muestra = 240;

  /// Desde esta proporción de fotogramas lentos se ofrece el modo ligero.
  static const proporcionLenta = 0.25;

  final VoidCallback alNotarLentitud;
  int _total = 0;
  int _lentos = 0;
  bool _midiendo = false;

  VigiaDeFotogramas({required this.alNotarLentitud});

  static bool esLento({required int total, required int lentos}) =>
      total >= muestra && lentos / total >= proporcionLenta;

  Future<void> empezar() async {
    if (kDebugMode || _midiendo) return;
    if ((await SharedPreferences.getInstance()).getBool(_clave) ?? false) return;
    _midiendo = true;
    SchedulerBinding.instance.addTimingsCallback(_medir);
  }

  void detener() {
    if (!_midiendo) return;
    SchedulerBinding.instance.removeTimingsCallback(_medir);
    _midiendo = false;
  }

  void _medir(List<FrameTiming> tiempos) {
    for (final t in tiempos) {
      _total++;
      if (t.totalSpan > lento) _lentos++;
    }
    if (_total < muestra) return;
    detener();
    if (esLento(total: _total, lentos: _lentos)) {
      SharedPreferences.getInstance().then((p) => p.setBool(_clave, true));
      alNotarLentitud();
    }
  }
}
