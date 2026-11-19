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

/// Lo que se le puede poner a la iguana. Cada uno se gana al llenar [tarjetas] tarjetas de sellos.
class Accesorio {
  final String clave;
  final String nombre;
  final int tarjetas;

  const Accesorio(this.clave, this.nombre, this.tarjetas);

  String get recurso => 'assets/iguana/$clave.svg';

  bool ganado(int llenas) => llenas >= tarjetas;
}

const accesorios = [
  Accesorio('gafas', 'Gafas de sol', 1),
  Accesorio('gorra', 'Gorra de Karta', 2),
  Accesorio('vueltiao', 'Sombrero vueltiao', 3),
  Accesorio('panoleta', 'Pañoleta', 4),
  Accesorio('audifonos', 'Audífonos', 5),
];

/// Todo lo que se juega en el teléfono: álbum, tarjeta de sellos, medallas de viaje y la iguana. Nada de esto va
/// al servidor.
class ProgresoDeJuego extends Equatable {
  final Album album;
  final TarjetaDeSellos tarjeta;
  final int madrugadas;
  final double kmTroncal;

  /// Lo que lleva puesto la iguana (la clave de un [Accesorio]); null, nada.
  final String? accesorio;

  /// Si la iguana acompaña el viaje. Se puede apagar para un viaje sin adornos.
  final bool iguanaEnElViaje;

  const ProgresoDeJuego({
    this.album = const Album(),
    this.tarjeta = const TarjetaDeSellos(),
    this.madrugadas = 0,
    this.kmTroncal = 0,
    this.accesorio,
    this.iguanaEnElViaje = true,
  });

  /// El accesorio puesto, si todavía lo tiene ganado.
  Accesorio? get puesto {
    for (final a in accesorios) {
      if (a.clave == accesorio && a.ganado(tarjeta.llenas)) return a;
    }
    return null;
  }

  double llevas(MedallaDeViaje medalla) => switch (medalla.clave) {
        'madrugador' => madrugadas.toDouble(),
        'troncalero' => kmTroncal,
        _ => 0,
      };

  /// [accesorio] es una función para poder quitarlo: `accesorio: () => null`.
  ProgresoDeJuego copyWith({
    Album? album,
    TarjetaDeSellos? tarjeta,
    int? madrugadas,
    double? kmTroncal,
    String? Function()? accesorio,
    bool? iguanaEnElViaje,
  }) =>
      ProgresoDeJuego(
        album: album ?? this.album,
        tarjeta: tarjeta ?? this.tarjeta,
        madrugadas: madrugadas ?? this.madrugadas,
        kmTroncal: kmTroncal ?? this.kmTroncal,
        accesorio: accesorio != null ? accesorio() : this.accesorio,
        iguanaEnElViaje: iguanaEnElViaje ?? this.iguanaEnElViaje,
      );

  factory ProgresoDeJuego.fromJson(Map<String, dynamic> json) => ProgresoDeJuego(
        album: Album.fromJson(json['album'] as Map<String, dynamic>? ?? const {}),
        tarjeta: TarjetaDeSellos.fromJson(json['tarjeta'] as Map<String, dynamic>? ?? const {}),
        madrugadas: json['madrugadas'] as int? ?? 0,
        kmTroncal: (json['km_troncal'] as num?)?.toDouble() ?? 0,
        accesorio: json['accesorio'] as String?,
        iguanaEnElViaje: json['iguana_en_el_viaje'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'album': album.toJson(),
        'tarjeta': tarjeta.toJson(),
        'madrugadas': madrugadas,
        'km_troncal': double.parse(kmTroncal.toStringAsFixed(2)),
        if (accesorio != null) 'accesorio': accesorio,
        'iguana_en_el_viaje': iguanaEnElViaje,
      };

  @override
  List<Object?> get props => [album, tarjeta, madrugadas, kmTroncal, accesorio, iguanaEnElViaje];
}
