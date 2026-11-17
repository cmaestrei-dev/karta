import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Cómo se sabe dónde está un paradero oficial.
enum EstadoDeParadero {
  estacion('estacion'),
  direccion('direccion'),
  estimado('estimado'),
  comunidad('comunidad'),
  porConfirmar('por_confirmar'),
  sinUbicar('sin_ubicar');

  final String api;

  const EstadoDeParadero(this.api);

  static EstadoDeParadero deApi(String? valor) =>
      values.firstWhere((e) => e.api == valor, orElse: () => EstadoDeParadero.sinUbicar);

  bool get ubicado => this == estacion || this == direccion || this == estimado || this == comunidad;
}

/// Una marca de la comunidad: dónde dice un Kartógrafo que está el paradero, y cuánto apoyo tiene.
class MarcaDeParadero extends Equatable {
  final String id;
  final LatLng punto;
  final int apoyo;
  final String estado; // por_confirmar | ubicada | descartada
  final bool mia;
  final bool? miVoto;

  const MarcaDeParadero({
    required this.id,
    required this.punto,
    required this.apoyo,
    required this.estado,
    this.mia = false,
    this.miVoto,
  });

  factory MarcaDeParadero.fromJson(Map<String, dynamic> json) => MarcaDeParadero(
        id: json['id'] as String,
        punto: LatLng((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
        apoyo: json['apoyo'] as int,
        estado: json['estado'] as String,
        mia: json['mia'] as bool? ?? false,
        miVoto: json['mi_voto'] as bool?,
      );

  @override
  List<Object?> get props => [id, punto, apoyo, estado, mia, miVoto];
}

class ParaderoDeRuta extends Equatable {
  final String id;
  final int orden;
  final String nombre;
  final EstadoDeParadero estado;
  final String? modulo;
  final LatLng? punto;
  final MarcaDeParadero? marca;

  const ParaderoDeRuta({
    required this.id,
    required this.orden,
    required this.nombre,
    required this.estado,
    this.modulo,
    this.punto,
    this.marca,
  });

  factory ParaderoDeRuta.fromJson(Map<String, dynamic> json) => ParaderoDeRuta(
        id: json['id'] as String,
        orden: json['orden'] as int,
        nombre: json['nombre'] as String,
        estado: EstadoDeParadero.deApi(json['estado'] as String?),
        modulo: json['modulo'] as String?,
        punto: json['latitud'] == null
            ? null
            : LatLng((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
        marca: json['marca'] == null ? null : MarcaDeParadero.fromJson(json['marca'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [id, orden, nombre, estado, modulo, punto, marca];
}

class SentidoDeRuta extends Equatable {
  final String sentido; // ida | vuelta | circular
  final String? hacia;
  final List<ParaderoDeRuta> paraderos;

  const SentidoDeRuta({required this.sentido, this.hacia, required this.paraderos});

  factory SentidoDeRuta.fromJson(Map<String, dynamic> json) => SentidoDeRuta(
        sentido: json['sentido'] as String,
        hacia: json['hacia'] as String?,
        paraderos: [for (final p in json['paraderos'] as List) ParaderoDeRuta.fromJson(p as Map<String, dynamic>)],
      );

  /// «Ida, hacia Blas de Lezo» o «Circular».
  String get etiqueta {
    final nombre = switch (sentido) { 'ida' => 'Ida', 'vuelta' => 'Vuelta', _ => 'Circular' };
    return hacia == null ? nombre : '$nombre · hacia $hacia';
  }

  /// Los dos vecinos ya ubicados más cercanos en el orden del recorrido: el anterior y el siguiente.
  ({ParaderoDeRuta? antes, ParaderoDeRuta? despues}) vecinos(ParaderoDeRuta paradero) {
    final k = paraderos.indexOf(paradero);
    final antes = paraderos.take(k).lastWhere((p) => p.punto != null, orElse: () => _nadie);
    final despues = paraderos.skip(k + 1).firstWhere((p) => p.punto != null, orElse: () => _nadie);
    return (antes: identical(antes, _nadie) ? null : antes, despues: identical(despues, _nadie) ? null : despues);
  }

  static const _nadie = ParaderoDeRuta(id: '', orden: 0, nombre: '', estado: EstadoDeParadero.sinUbicar);

  @override
  List<Object?> get props => [sentido, hacia, paraderos];
}

/// Varias subidas a la ruta en el mismo lugar: casi seguro hay un paradero.
class PistaDeSubida extends Equatable {
  final LatLng punto;
  final int subidas;

  const PistaDeSubida({required this.punto, required this.subidas});

  @override
  List<Object?> get props => [punto, subidas];
}

class ParaderosDeRuta extends Equatable {
  final String ruta;
  final int ubicados;
  final int total;
  final List<SentidoDeRuta> sentidos;
  final List<PistaDeSubida> pistas;

  const ParaderosDeRuta({
    required this.ruta,
    required this.ubicados,
    required this.total,
    required this.sentidos,
    required this.pistas,
  });

  factory ParaderosDeRuta.fromJson(Map<String, dynamic> json) => ParaderosDeRuta(
        ruta: json['ruta'] as String,
        ubicados: json['ubicados'] as int,
        total: json['total'] as int,
        sentidos: [for (final s in json['sentidos'] as List) SentidoDeRuta.fromJson(s as Map<String, dynamic>)],
        pistas: [
          for (final p in json['pistas'] as List)
            PistaDeSubida(
              punto: LatLng((p['latitud'] as num).toDouble(), (p['longitud'] as num).toDouble()),
              subidas: p['subidas'] as int,
            ),
        ],
      );

  @override
  List<Object?> get props => [ruta, ubicados, total, sentidos, pistas];
}
