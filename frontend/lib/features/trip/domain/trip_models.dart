import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class RiskSummary extends Equatable {
  final int score;
  final String nivel;
  final int totalIncidentes;

  const RiskSummary({required this.score, required this.nivel, required this.totalIncidentes});

  factory RiskSummary.fromJson(Map<String, dynamic> json) => RiskSummary(
        score: json['score'] as int,
        // Sin nivel no se asume "BAJO": se muestra como riesgo sin datos.
        nivel: json['nivel'] as String? ?? 'DESCONOCIDO',
        totalIncidentes: json['total_incidentes'] as int,
      );

  @override
  List<Object?> get props => [score, nivel, totalIncidentes];
}

/// Tramo de un viaje: una caminata o un recorrido en una ruta de Transcaribe.
class Leg extends Equatable {
  final String modo; // "caminata" | "bus"
  final String desde;
  final String hasta;
  final int distanciaM;
  final int duracionMin;
  final int esperaMin;
  final String? ruta;
  final String? nombreRuta;
  final String? tipoRuta;
  final List<LatLng> puntos;

  const Leg({
    required this.modo,
    required this.desde,
    required this.hasta,
    required this.distanciaM,
    required this.duracionMin,
    required this.esperaMin,
    required this.puntos,
    this.ruta,
    this.nombreRuta,
    this.tipoRuta,
  });

  bool get esCaminata => modo == 'caminata';

  factory Leg.fromJson(Map<String, dynamic> json) => Leg(
        modo: json['modo'] as String,
        desde: json['desde'] as String,
        hasta: json['hasta'] as String,
        distanciaM: json['distancia_m'] as int,
        duracionMin: json['duracion_min'] as int,
        esperaMin: json['espera_min'] as int? ?? 0,
        ruta: json['ruta'] as String?,
        nombreRuta: json['nombre_ruta'] as String?,
        tipoRuta: json['tipo_ruta'] as String?,
        // GeoJSON trae los pares en orden [longitud, latitud].
        puntos: (json['geometria']['coordinates'] as List<dynamic>)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList(),
      );

  @override
  List<Object?> get props => [modo, desde, hasta, distanciaM, duracionMin, esperaMin, ruta, puntos];
}

class RouteOption extends Equatable {
  final String resumen;
  final int tiempoTotalMin;
  final int distanciaCaminataM;
  final List<Leg> tramos;
  final RiskSummary riesgo;

  const RouteOption({
    required this.resumen,
    required this.tiempoTotalMin,
    required this.distanciaCaminataM,
    required this.tramos,
    required this.riesgo,
  });

  Leg? get bus => tramos.where((t) => !t.esCaminata).firstOrNull;

  List<LatLng> get puntos => [for (final tramo in tramos) ...tramo.puntos];

  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
        resumen: json['resumen'] as String,
        tiempoTotalMin: json['tiempo_total_min'] as int,
        distanciaCaminataM: json['distancia_caminata_m'] as int,
        tramos: (json['tramos'] as List<dynamic>).map((t) => Leg.fromJson(t)).toList(),
        riesgo: RiskSummary.fromJson(json['riesgo']),
      );

  @override
  List<Object?> get props => [resumen, tiempoTotalMin, distanciaCaminataM, tramos, riesgo];
}

class RouteSuggestions extends Equatable {
  final List<RouteOption> opciones;
  final String nota;
  final String fuente;

  const RouteSuggestions({required this.opciones, required this.nota, required this.fuente});

  factory RouteSuggestions.fromJson(Map<String, dynamic> json) => RouteSuggestions(
        opciones: (json['opciones'] as List<dynamic>).map((o) => RouteOption.fromJson(o)).toList(),
        nota: json['nota'] as String,
        fuente: json['fuente'] as String,
      );

  @override
  List<Object?> get props => [opciones, nota, fuente];
}

/// Estación de Transcaribe cercana.
class Stop extends Equatable {
  final String id;
  final String nombre;
  final LatLng punto;
  final List<String> rutas;

  /// Distancia y minutos a pie estimados por el backend con la misma regla de los tramos de caminata.
  final int caminataM;
  final int caminataMin;

  const Stop({
    required this.id,
    required this.nombre,
    required this.punto,
    required this.rutas,
    required this.caminataM,
    required this.caminataMin,
  });

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        punto: LatLng((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
        rutas: (json['rutas'] as List<dynamic>).cast<String>(),
        caminataM: json['caminata_m'] as int,
        caminataMin: json['caminata_min'] as int,
      );

  @override
  List<Object?> get props => [id, nombre, punto, rutas, caminataM, caminataMin];
}

/// Tipo de ruta según el código: T troncal, X pretroncal, A alimentadora, C complementaria.
String? tipoDeRuta(String codigo) => switch (codigo.isEmpty ? '' : codigo[0]) {
      'T' => 'troncal',
      'X' => 'pretroncal',
      'A' => 'alimentadora',
      'C' => 'complementaria',
      _ => null,
    };
