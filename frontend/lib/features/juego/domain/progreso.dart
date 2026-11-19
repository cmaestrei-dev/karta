import 'package:equatable/equatable.dart';

import 'album.dart';
import 'sellos.dart';

/// Niveles de una medalla de viaje, como las de Pokémon GO (docs/plan-juego.md).
enum NivelDeMedalla { ninguno, bronce, plata, oro, platino }

/// Una medalla que sube de nivel con lo que se hizo en viajes compartidos.
class MedallaDeViaje {
  final String clave;
  final String nombre;
  final String descripcion;
  final String unidad;

  /// Lo que pide cada nivel, de bronce a platino.
  final List<double> metas;

  const MedallaDeViaje(this.clave, this.nombre, this.descripcion, this.unidad, this.metas);

  NivelDeMedalla nivel(double llevas) {
    var nivel = NivelDeMedalla.ninguno;
    for (final (k, meta) in metas.indexed) {
      if (llevas >= meta) nivel = NivelDeMedalla.values[k + 1];
    }
    return nivel;
  }

  /// Lo que pide el nivel siguiente; null en platino.
  double? siguienteMeta(double llevas) {
    for (final meta in metas) {
      if (llevas < meta) return meta;
    }
    return null;
  }
}

/// Premia a quien ya viaja temprano, cuando menos datos hay; no invita a salir de noche.
const madrugador = MedallaDeViaje('madrugador', 'Madrugador',
    'Compartiste buses en la primera hora de servicio, antes de las 6:00 a. m.', 'buses antes de las 6', [1, 5, 15, 40]);

const troncalero = MedallaDeViaje(
    'troncalero', 'Troncalero', 'Kilómetros que compartiste en las troncales', 'km por la troncal', [10, 50, 150, 400]);

const medallasDeViaje = [madrugador, troncalero];

/// La primera hora de servicio: los primeros buses salen hacia las 4:30.
const horaDelMadrugador = 6;

/// Todo lo que se juega en el teléfono: álbum, tarjeta de sellos y medallas de viaje. Nada de esto va al servidor.
class ProgresoDeJuego extends Equatable {
  final Album album;
  final TarjetaDeSellos tarjeta;
  final int madrugadas;
  final double kmTroncal;

  const ProgresoDeJuego({
    this.album = const Album(),
    this.tarjeta = const TarjetaDeSellos(),
    this.madrugadas = 0,
    this.kmTroncal = 0,
  });

  double llevas(MedallaDeViaje medalla) => switch (medalla.clave) {
        'madrugador' => madrugadas.toDouble(),
        'troncalero' => kmTroncal,
        _ => 0,
      };

  ProgresoDeJuego copyWith({Album? album, TarjetaDeSellos? tarjeta, int? madrugadas, double? kmTroncal}) =>
      ProgresoDeJuego(
        album: album ?? this.album,
        tarjeta: tarjeta ?? this.tarjeta,
        madrugadas: madrugadas ?? this.madrugadas,
        kmTroncal: kmTroncal ?? this.kmTroncal,
      );

  factory ProgresoDeJuego.fromJson(Map<String, dynamic> json) => ProgresoDeJuego(
        album: Album.fromJson(json['album'] as Map<String, dynamic>? ?? const {}),
        tarjeta: TarjetaDeSellos.fromJson(json['tarjeta'] as Map<String, dynamic>? ?? const {}),
        madrugadas: json['madrugadas'] as int? ?? 0,
        kmTroncal: (json['km_troncal'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'album': album.toJson(),
        'tarjeta': tarjeta.toJson(),
        'madrugadas': madrugadas,
        'km_troncal': double.parse(kmTroncal.toStringAsFixed(2)),
      };

  @override
  List<Object?> get props => [album, tarjeta, madrugadas, kmTroncal];
}
