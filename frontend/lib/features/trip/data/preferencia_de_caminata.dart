import 'package:shared_preferences/shared_preferences.dart';

/// Lo máximo que el viajero quiere caminar hasta la ruta o desde ella (D21). Null: lo normal, hasta 1 km.
class PreferenciaDeCaminata {
  static const _clave = 'karta_caminata_maxima_m';
  static const opciones = [300, 500, 800];

  Future<int?> leer() async => (await SharedPreferences.getInstance()).getInt(_clave);

  Future<void> guardar(int? metros) async {
    final preferencias = await SharedPreferences.getInstance();
    metros == null ? await preferencias.remove(_clave) : await preferencias.setInt(_clave, metros);
  }
}
