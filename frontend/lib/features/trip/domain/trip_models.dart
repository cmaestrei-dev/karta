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

  /// Estaciones por las que pasa el bus en este tramo, en orden, de la subida a la bajada.
  /// Vacía fuera de la troncal: ahí el bus para en paraderos sin coordenadas publicadas.
  final List<({String nombre, LatLng punto})> paradas;

  /// En la caminata de un transbordo integrado, cómo hacer el cambio
  /// («Sal de Santa Lucía y cruza por la cebra hasta Madre Bernarda: 40 m. …»).
  final String? indicacion;

  /// En qué módulo de la estación para el bus en este sentido («A1») y hacia dónde va («Bocagrande»).
  final String? modulo;
  final String? hacia;

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
    this.paradas = const [],
    this.indicacion,
    this.modulo,
    this.hacia,
  });

  /// «módulo A1, hacia Bocagrande»: dónde hacer la fila y en qué sentido. Null si no se sabe.
  String? get comoAbordar {
    final partes = [if (modulo != null) 'módulo $modulo', if (hacia != null) 'hacia $hacia'];
    return partes.isEmpty ? null : partes.join(', ');
  }

  /// La primera frase de la indicación, para la franja del viaje: «Sal de Santa Lucía y cruza por la cebra…».
  String? get indicacionCorta {
    final texto = indicacion;
    if (texto == null) return null;
    final fin = texto.indexOf('. ');
    return fin < 0 ? texto.replaceAll(RegExp(r'\.$'), '') : texto.substring(0, fin);
  }

  bool get esCaminata => modo == 'caminata';

  /// Se baja en una estación de la troncal: ahí sí se pueden contar paradas. Si la bajada es un paradero de la vía
  /// (sin coordenadas publicadas), contar las estaciones del camino engaña: después de la última aún faltaría.
  bool get bajaEnEstacion =>
      paradas.isNotEmpty && puntos.isNotEmpty && const Distance().as(LengthUnit.Meter, paradas.last.punto, puntos.last) <= 150;

  /// Sube en una estación de la troncal, donde se hace la fila de cada ruta.
  bool get subeEnEstacion =>
      paradas.isNotEmpty && puntos.isNotEmpty && const Distance().as(LengthUnit.Meter, paradas.first.punto, puntos.first) <= 150;

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
        indicacion: json['indicacion'] as String?,
        modulo: json['modulo'] as String?,
        hacia: json['hacia'] as String?,
        paradas: [
          for (final p in json['paradas'] as List<dynamic>? ?? const [])
            (nombre: p['nombre'] as String, punto: LatLng((p['latitud'] as num).toDouble(), (p['longitud'] as num).toDouble())),
        ],
        // GeoJSON trae los pares en orden [longitud, latitud].
        puntos: (json['geometria']['coordinates'] as List<dynamic>)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList(),
      );

  @override
  List<Object?> get props => [modo, desde, hasta, distanciaM, duracionMin, esperaMin, ruta, puntos, paradas];
}

class RouteOption extends Equatable {
  final String resumen;
  final int tiempoTotalMin;
  final int distanciaCaminataM;
  final int transbordos;
  final List<Leg> tramos;
  final RiskSummary riesgo;

  const RouteOption({
    required this.resumen,
    required this.tiempoTotalMin,
    required this.distanciaCaminataM,
    this.transbordos = 0,
    required this.tramos,
    required this.riesgo,
  });

  /// Los tramos en bus, en orden: uno, o dos con transbordo.
  List<Leg> get buses => [for (final t in tramos) if (!t.esCaminata) t];

  Leg? get bus => buses.firstOrNull;

  /// Dónde se cambia de bus («Estación La Castellana»), si hay transbordo.
  String? get puntoDeTransbordo => buses.length > 1 ? buses[1].desde : null;

  List<LatLng> get puntos => [for (final tramo in tramos) ...tramo.puntos];

  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
        resumen: json['resumen'] as String,
        tiempoTotalMin: json['tiempo_total_min'] as int,
        distanciaCaminataM: json['distancia_caminata_m'] as int,
        transbordos: json['transbordos'] as int? ?? 0,
        tramos: (json['tramos'] as List<dynamic>).map((t) => Leg.fromJson(t)).toList(),
        riesgo: RiskSummary.fromJson(json['riesgo']),
      );

  @override
  List<Object?> get props => [resumen, tiempoTotalMin, distanciaCaminataM, transbordos, tramos, riesgo];
}

/// Cómo ordenar las formas de llegar.
enum CriterioDeRuta {
  rapida('rapida', 'Más rápida'),
  segura('segura', 'Más segura'),
  sinTransbordo('sin_transbordo', 'Sin transbordo');

  final String api;
  final String etiqueta;

  const CriterioDeRuta(this.api, this.etiqueta);

  static CriterioDeRuta deApi(String? valor) =>
      values.where((c) => c.api == valor).firstOrNull ?? CriterioDeRuta.rapida;
}

class RouteSuggestions extends Equatable {
  final List<RouteOption> opciones;
  final CriterioDeRuta criterio;
  final DateTime? salida;

  /// Por qué no hay opciones en bus cuando es por el horario («La primera sale mañana a las 5:30 a. m.»).
  final String? aviso;
  final String nota;
  final String fuente;

  const RouteSuggestions({
    required this.opciones,
    this.criterio = CriterioDeRuta.rapida,
    this.salida,
    this.aviso,
    required this.nota,
    required this.fuente,
  });

  factory RouteSuggestions.fromJson(Map<String, dynamic> json) => RouteSuggestions(
        opciones: (json['opciones'] as List<dynamic>).map((o) => RouteOption.fromJson(o)).toList(),
        criterio: CriterioDeRuta.deApi(json['criterio'] as String?),
        salida: DateTime.tryParse(json['salida'] as String? ?? ''),
        aviso: json['aviso'] as String?,
        nota: json['nota'] as String,
        fuente: json['fuente'] as String,
      );

  @override
  List<Object?> get props => [opciones, criterio, salida, aviso, nota, fuente];
}

/// Una ruta de Transcaribe con su trazado, para dibujarla sobre el mapa.
class RutaEnMapa extends Equatable {
  final String codigo;
  final String nombre;
  final String tipo;
  final List<LatLng> puntos;

  const RutaEnMapa({required this.codigo, required this.nombre, required this.tipo, required this.puntos});

  factory RutaEnMapa.fromJson(Map<String, dynamic> json) => RutaEnMapa(
        codigo: json['codigo'] as String,
        nombre: json['nombre'] as String,
        tipo: json['tipo'] as String,
        // GeoJSON trae los pares en orden [longitud, latitud].
        puntos: [
          for (final c in json['geometria']['coordinates'] as List<dynamic>)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ],
      );

  @override
  List<Object?> get props => [codigo, nombre, tipo, puntos];
}

/// Primer y último despacho de un tipo de día, en hora de Colombia («05:00», «21:00»).
typedef FranjaDeServicio = ({String primera, String ultima});

/// La página de una ruta: su recorrido, sus estaciones en el orden en que las recorre y su horario.
class PaginaDeRuta extends Equatable {
  final String codigo;
  final String nombre;
  final String tipo;
  final String desde;
  final String hasta;
  final List<LatLng> puntos;
  final List<({String nombre, LatLng punto})> estaciones;

  /// Por tipo de día (lunes_a_viernes, sabado, domingo_y_festivos); null si ese día no opera.
  /// Vacío si Transcaribe no publica el horario de la ruta.
  final Map<String, FranjaDeServicio?> horario;
  final String hoy;
  final bool? operaAhora;

  const PaginaDeRuta({
    required this.codigo,
    required this.nombre,
    required this.tipo,
    required this.desde,
    required this.hasta,
    required this.puntos,
    required this.estaciones,
    required this.horario,
    required this.hoy,
    required this.operaAhora,
  });

  bool get tieneHorario => horario.isNotEmpty;

  factory PaginaDeRuta.fromJson(Map<String, dynamic> json) {
    final horario = json['horario'] as Map<String, dynamic>?;
    FranjaDeServicio? franja(dynamic f) =>
        f == null ? null : (primera: f['primera'] as String, ultima: f['ultima'] as String);
    return PaginaDeRuta(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      tipo: json['tipo'] as String,
      desde: json['desde'] as String? ?? '',
      hasta: json['hasta'] as String? ?? '',
      puntos: [
        for (final c in json['geometria']['coordinates'] as List<dynamic>)
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ],
      estaciones: [
        for (final e in json['estaciones'] as List<dynamic>)
          (nombre: e['nombre'] as String, punto: LatLng((e['latitud'] as num).toDouble(), (e['longitud'] as num).toDouble())),
      ],
      horario: horario == null ? const {} : {for (final dia in diasDeServicio) dia: franja(horario[dia])},
      hoy: json['hoy'] as String,
      operaAhora: json['opera_ahora'] as bool?,
    );
  }

  @override
  List<Object?> get props => [codigo, nombre, tipo, desde, hasta, puntos, estaciones, horario, hoy, operaAhora];
}

/// Tipos de día del horario de Transcaribe, en orden, con su nombre para mostrar.
const diasDeServicio = ['lunes_a_viernes', 'sabado', 'domingo_y_festivos'];
const nombreDeDia = {
  'lunes_a_viernes': 'Lunes a viernes',
  'sabado': 'Sábados',
  'domingo_y_festivos': 'Domingos y festivos',
};

/// Estación de Transcaribe cercana.
/// Una ruta que pasa cerca y dónde tomarla fuera de las estaciones («Paradero Av. Kennedy con Calle 18»).
/// Los paraderos oficiales no tienen coordenadas: es el punto de la vía más cercano donde la ruta recoge.
class RutaCercana extends Equatable {
  final String ruta;
  final String nombre;
  final String tipo;
  final String paradero;
  final LatLng punto;
  final int caminataM;
  final int caminataMin;

  const RutaCercana({
    required this.ruta,
    required this.nombre,
    required this.tipo,
    required this.paradero,
    required this.punto,
    required this.caminataM,
    required this.caminataMin,
  });

  factory RutaCercana.fromJson(Map<String, dynamic> json) => RutaCercana(
        ruta: json['ruta'] as String,
        nombre: json['nombre'] as String,
        tipo: json['tipo'] as String,
        paradero: json['paradero'] as String,
        punto: LatLng((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
        caminataM: json['caminata_m'] as int,
        caminataMin: json['caminata_min'] as int,
      );

  @override
  List<Object?> get props => [ruta, nombre, tipo, paradero, punto, caminataM, caminataMin];
}

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
