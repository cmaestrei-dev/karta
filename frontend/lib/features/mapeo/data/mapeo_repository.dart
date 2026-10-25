import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../domain/mapeo_models.dart';

/// «Marca este paradero»: los paraderos de cada ruta, las marcas de los Kartógrafos y sus confirmaciones.
class MapeoRepository {
  final ApiClient api;

  MapeoRepository({required this.api});

  Future<ParaderosDeRuta> paraderos(String ruta) async =>
      ParaderosDeRuta.fromJson(await api.get('/routes/$ruta/stops', sesionSiHay: true) as Map<String, dynamic>);

  /// Marca dónde está un paradero sin ubicar; el servidor lo lleva a la calle por donde pasa la ruta.
  Future<MarcaDeParadero> marcar(String paradero, LatLng punto) async => MarcaDeParadero.fromJson(await api.post(
      '/stops/$paradero/marks', {'latitud': punto.latitude, 'longitud': punto.longitude}, auth: true) as Map<String, dynamic>);

  /// «¿Está aquí?», respondido desde donde está el viajero (hay que estar a menos de 300 m).
  Future<MarcaDeParadero> votar(String marca, {required bool estaAqui, required LatLng desde}) async =>
      MarcaDeParadero.fromJson(await api.post('/stops/marks/$marca/votes',
          {'esta_aqui': estaAqui, 'latitud': desde.latitude, 'longitud': desde.longitude}, auth: true) as Map<String, dynamic>);
}
