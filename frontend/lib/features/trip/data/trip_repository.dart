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

  Future<RouteSuggestions> suggest(TripPoint origen, TripPoint destino) async {
    Map<String, Object> coordenada(TripPoint p) =>
        {'lat': p.punto.latitude, 'lon': p.punto.longitude, 'nombre': p.nombre};
    final data = await api.post('/routes/suggest', {'origen': coordenada(origen), 'destino': coordenada(destino)});
    return RouteSuggestions.fromJson(data);
  }

  Future<List<Stop>> nearbyStops(LatLng punto) async {
    final data = await api.get('/stops/nearby', query: {
      'lat': punto.latitude.toStringAsFixed(6),
      'lon': punto.longitude.toStringAsFixed(6),
      'limite': '4',
    }) as List<dynamic>;
    return data.map((json) => Stop.fromJson(json)).toList();
  }
}
