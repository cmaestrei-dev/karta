import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../domain/place_models.dart';

class PlacesRepository {
  final ApiClient api;

  PlacesRepository({required this.api});

  Future<List<Place>> search(String consulta) async {
    final data = await api.get('/places/search', query: {'q': consulta, 'limite': '8'}) as List<dynamic>;
    return data.map((json) => Place.fromJson(json)).toList();
  }

  /// Nombre del punto elegido en el mapa ("Cerca de Getsemaní").
  Future<Place> reverse(LatLng punto) async {
    final data = await api.get('/places/reverse', query: {
      'lat': punto.latitude.toStringAsFixed(6),
      'lon': punto.longitude.toStringAsFixed(6),
    });
    return Place.fromJson(data);
  }

  Future<List<SavedPlace>> listSaved() async {
    final data = await api.get('/users/me/places', auth: true) as List<dynamic>;
    return data.map((json) => SavedPlace.fromJson(json)).toList();
  }

  Future<SavedPlace> addSaved({required String nombre, required SavedPlaceIcon icono, required LatLng punto}) async {
    final data = await api.post('/users/me/places', {
      'nombre': nombre,
      'icono': icono.api,
      'latitud': punto.latitude,
      'longitud': punto.longitude,
    }, auth: true);
    return SavedPlace.fromJson(data);
  }

  Future<SavedPlace> updateSaved(String id, {String? nombre, SavedPlaceIcon? icono}) async {
    final data = await api.patch('/users/me/places/$id', {
      'nombre': ?nombre,
      'icono': ?icono?.api,
    }, auth: true);
    return SavedPlace.fromJson(data);
  }

  Future<void> deleteSaved(String id) => api.delete('/users/me/places/$id', auth: true);
}
