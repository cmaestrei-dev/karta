import 'package:shared_preferences/shared_preferences.dart';

/// Compartir dónde va el bus viene activado: se avisa una sola vez, al empezar el primer viaje, y se apaga en
/// Perfil › Privacidad. Sin haber visto el aviso no se comparte nada (Ley 1581: autorización informada).
class PreferenciaDeCompartir {
  static const _clave = 'karta_compartir_bus';
  static const _aviso = 'karta_aviso_compartir_visto';
  static const _contador = 'karta_viajes_compartidos';

  /// Si comparte en sus viajes. Por defecto sí.
  Future<bool> compartir() async => (await SharedPreferences.getInstance()).getBool(_clave) ?? true;

  Future<void> guardar(bool si) async => (await SharedPreferences.getInstance()).setBool(_clave, si);

  Future<bool> avisoVisto() async => (await SharedPreferences.getInstance()).getBool(_aviso) ?? false;

  Future<void> marcarAvisoVisto() async => (await SharedPreferences.getInstance()).setBool(_aviso, true);

  /// Cuántos buses ha compartido. Solo vive en el teléfono: los viajes compartidos son anónimos en el servidor.
  Future<int> viajesCompartidos() async => (await SharedPreferences.getInstance()).getInt(_contador) ?? 0;

  Future<void> sumarViajeCompartido() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setInt(_contador, (preferencias.getInt(_contador) ?? 0) + 1);
  }
}
