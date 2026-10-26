import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../places/domain/place_models.dart';
import '../domain/trip_models.dart';

class TripRepository {
  final ApiClient api;

  TripRepository({required this.api});

  /// Los trazados casi nunca cambian: se piden una vez por tipo mientras la app está abierta.
  final _rutas = <String?, Future<List<RutaEnMapa>>>{};

  Future<List<RutaEnMapa>> rutas({String? tipo}) {
    return _rutas.putIfAbsent(tipo, () async {
      try {
        final data = await api.get('/routes/', query: {'tipo': ?tipo}) as List<dynamic>;
        return [for (final json in data) RutaEnMapa.fromJson(json as Map<String, dynamic>)];
      } catch (_) {
        _rutas.remove(tipo); // si falló, el próximo intento vuelve a pedirlas
        rethrow;
      }
    });
  }

  /// Formas de llegar ordenadas por [criterio]. Sin [salida] se sale ahora; con ella, solo cuentan las rutas
  /// que operan a esa hora.
  Future<RouteSuggestions> suggest(TripPoint origen, TripPoint destino,
      {CriterioDeRuta criterio = CriterioDeRuta.rapida, DateTime? salida, int? caminataMaximaM}) async {
    Map<String, Object> coordenada(TripPoint p) =>
        {'lat': p.punto.latitude, 'lon': p.punto.longitude, 'nombre': p.nombre};
    final data = await api.post('/routes/suggest', {
      'origen': coordenada(origen),
      'destino': coordenada(destino),
      'criterio': criterio.api,
      if (salida != null) 'salida': salida.toUtc().toIso8601String(),
      'caminata_maxima_m': ?caminataMaximaM,
    });
    return RouteSuggestions.fromJson(data);
  }

  Future<PaginaDeRuta> ruta(String codigo) async =>
      PaginaDeRuta.fromJson(await api.get('/routes/$codigo') as Map<String, dynamic>);

  Future<List<Stop>> nearbyStops(LatLng punto) async {
    final data = await api.get('/stops/nearby', query: {
      'lat': punto.latitude.toStringAsFixed(6),
      'lon': punto.longitude.toStringAsFixed(6),
      'limite': '4',
    }) as List<dynamic>;
    return data.map((json) => Stop.fromJson(json)).toList();
  }

  /// Las rutas que pasan a menos de 500 m y dónde tomarlas, fuera de las estaciones.
  Future<List<RutaCercana>> nearbyRoutes(LatLng punto) async {
    final data = await api.get('/routes/nearby', query: {
      'lat': punto.latitude.toStringAsFixed(6),
      'lon': punto.longitude.toStringAsFixed(6),
      'limite': '6',
    }) as List<dynamic>;
    return [for (final json in data) RutaCercana.fromJson(json as Map<String, dynamic>)];
  }
}
