import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../places/domain/place_models.dart';
import '../domain/trip_models.dart';

class TripRepository {
  final ApiClient api;

  TripRepository({required this.api});

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
