import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';

/// Qué tan lleno va un bus, según quien va en él.
enum Ocupacion {
  conPuestos('con_puestos', 'Con puestos'),
  dePie('de_pie', 'De pie'),
  muyLleno('muy_lleno', 'Muy lleno');

  final String api;
  final String etiqueta;

  const Ocupacion(this.api, this.etiqueta);

  static Ocupacion? deApi(String? valor) => values.where((o) => o.api == valor).firstOrNull;
}

/// Cuánto le falta al próximo bus, según los viajeros. Sin observaciones, [minutos] es null.
class Llegada extends Equatable {
  final int? minutos;
  final int fuentes;
  final Ocupacion? ocupacion;
  final int? vistoHaceMin;

  const Llegada({this.minutos, this.fuentes = 0, this.ocupacion, this.vistoHaceMin});

  factory Llegada.fromJson(Map<String, dynamic> json) => Llegada(
        minutos: json['minutos'] as int?,
        fuentes: json['fuentes'] as int? ?? 0,
        ocupacion: Ocupacion.deApi(json['ocupacion'] as String?),
        vistoHaceMin: json['visto_hace_min'] as int?,
      );

  @override
  List<Object?> get props => [minutos, fuentes, ocupacion, vistoHaceMin];
}

/// El tiempo real de los viajeros: nada de lo que se envía lleva el nombre de quien lo envía.
class TiempoRealRepository {
  final ApiClient api;

  TiempoRealRepository({required this.api});

  Future<Llegada> llegada(String ruta, {required LatLng desde, required LatLng hasta}) async {
    final data = await api.get('/routes/$ruta/live', query: {
      'desde_lat': desde.latitude.toStringAsFixed(6),
      'desde_lon': desde.longitude.toStringAsFixed(6),
      'hasta_lat': hasta.latitude.toStringAsFixed(6),
      'hasta_lon': hasta.longitude.toStringAsFixed(6),
    });
    return Llegada.fromJson(data as Map<String, dynamic>);
  }

  /// «Vi pasar el T103» o, desde adentro, qué tan lleno va.
  Future<void> avistamiento(String ruta, LatLng punto, {Ocupacion? ocupacion}) => api.post('/sightings', {
        'ruta': ruta,
        'latitud': punto.latitude,
        'longitud': punto.longitude,
        'ocupacion': ?ocupacion?.api,
      }, auth: true);

  /// Empieza a compartir dónde va el bus; devuelve el identificador aleatorio del viaje.
  Future<String> iniciarViajeCompartido(String ruta, LatLng punto) async {
    final data = await api.post('/trips', {'ruta': ruta, 'latitud': punto.latitude, 'longitud': punto.longitude},
        auth: true);
    return (data as Map<String, dynamic>)['viaje'] as String;
  }

  /// Mueve el viaje compartido. Devuelve false si el servidor ya lo borró (venció): hay que empezar otro.
  Future<bool> moverViajeCompartido(String viaje, LatLng punto, {Ocupacion? ocupacion}) async {
    try {
      await api.put('/trips/$viaje', {
        'latitud': punto.latitude,
        'longitud': punto.longitude,
        'ocupacion': ?ocupacion?.api,
      }, auth: true);
      return true;
    } on ApiException catch (e) {
      if (e.codigo == 404) return false;
      rethrow;
    }
  }

  Future<void> terminarViajeCompartido(String viaje) => api.delete('/trips/$viaje', auth: true);
}
