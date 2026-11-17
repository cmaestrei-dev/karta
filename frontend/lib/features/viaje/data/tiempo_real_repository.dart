import 'dart:math';

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

/// Un bus de la ruta varado antes de la subida: ya no cuenta como uno que viene.
class Varado extends Equatable {
  final String? lugar;
  final int metrosAntes;
  final int haceMin;
  final int confirmaciones;

  const Varado({this.lugar, required this.metrosAntes, required this.haceMin, this.confirmaciones = 0});

  factory Varado.fromJson(Map<String, dynamic> json) => Varado(
        lugar: json['lugar'] as String?,
        metrosAntes: json['metros_antes'] as int? ?? 0,
        haceMin: json['hace_min'] as int? ?? 0,
        confirmaciones: json['confirmaciones'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [lugar, metrosAntes, haceMin, confirmaciones];
}

/// Cuánto le falta al próximo bus, según los viajeros. Sin observaciones, [minutos] es null.
class Llegada extends Equatable {
  final int? minutos;
  final int fuentes;
  final Ocupacion? ocupacion;
  final int? vistoHaceMin;
  final Varado? varado;

  /// La última estimación que se pudo consultar, envejecida mientras el teléfono no tiene conexión.
  final bool sinConexion;

  const Llegada(
      {this.minutos, this.fuentes = 0, this.ocupacion, this.vistoHaceMin, this.varado, this.sinConexion = false});

  factory Llegada.fromJson(Map<String, dynamic> json) => Llegada(
        minutos: json['minutos'] as int?,
        fuentes: json['fuentes'] as int? ?? 0,
        ocupacion: Ocupacion.deApi(json['ocupacion'] as String?),
        vistoHaceMin: json['visto_hace_min'] as int?,
        varado: json['varado'] == null ? null : Varado.fromJson(json['varado'] as Map<String, dynamic>),
      );

  /// La misma llegada [transcurrido] después, sin poder volver a consultarla: el bus está más cerca y el dato es
  /// más viejo, y se dice.
  Llegada sinConexionDesde(Duration transcurrido) {
    final m = transcurrido.inMinutes;
    return Llegada(
      minutos: minutos == null ? null : max(0, minutos! - m),
      fuentes: fuentes,
      ocupacion: ocupacion,
      vistoHaceMin: vistoHaceMin == null ? null : vistoHaceMin! + m,
      varado: varado,
      sinConexion: true,
    );
  }

  @override
  List<Object?> get props => [minutos, fuentes, ocupacion, vistoHaceMin, varado, sinConexion];
}

/// Cómo pidió la parada quien se bajó en un paradero (D12).
enum ComoSePidio {
  timbre('timbre', 'Toqué el timbre'),
  paroSolo('paro_solo', 'Paró solo'),
  conductor('conductor', 'Le avisé al conductor');

  final String api;
  final String etiqueta;

  const ComoSePidio(this.api, this.etiqueta);

  static ComoSePidio? deApi(String? valor) => values.where((c) => c.api == valor).firstOrNull;
}

/// Lo que saben los viajeros de un paradero: cómo pidió la parada la mayoría, y cuántos.
class ComoSePideAqui extends Equatable {
  final ComoSePidio como;
  final int viajeros;

  const ComoSePideAqui({required this.como, required this.viajeros});

  @override
  List<Object> get props => [como, viajeros];
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

  /// Al bajarse en un paradero: cómo pidió la parada. Se envía el paradero, no el recorrido.
  Future<void> comoPediLaParada(String ruta, LatLng paradero, ComoSePidio como) => api.post('/stop-requests', {
        'ruta': ruta,
        'como': como.api,
        'latitud': paradero.latitude,
        'longitud': paradero.longitude,
      }, auth: true);

  /// Cómo se pide la parada en ese paradero según los viajeros; null si aún no hay suficientes respuestas.
  Future<ComoSePideAqui?> comoSePide(String ruta, LatLng paradero) async {
    final data = await api.get('/routes/$ruta/stop-request', query: {
      'latitud': paradero.latitude.toStringAsFixed(6),
      'longitud': paradero.longitude.toStringAsFixed(6),
    }) as Map<String, dynamic>;
    final como = ComoSePidio.deApi(data['como'] as String?);
    return como == null ? null : ComoSePideAqui(como: como, viajeros: data['viajeros'] as int? ?? 0);
  }

  /// Un reporte de la comunidad desde el viaje («bus_varado» del T103, «trancon» detenido).
  Future<void> reportar(String tipo, Map<String, String> detalles, LatLng punto) => api.post('/incidents/', {
        'tipo': tipo,
        'detalles': detalles,
        'latitud': punto.latitude,
        'longitud': punto.longitude,
      }, auth: true);
}
