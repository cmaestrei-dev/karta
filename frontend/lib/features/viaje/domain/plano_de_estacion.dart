import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../trip/domain/trip_models.dart';

/// En qué vagón de la estación parece estar el viajero, según su ubicación.
enum DondeEstas { enTuVagon, enElOtro, enLaMitad, noSeSabe }

/// El plano de una estación doble mientras se espera (D18): los dos vagones, de qué lado queda cada uno y dónde está
/// el viajero sobre el largo de la estación.
///
/// El eje va del vagón de enfrente (0) al del bus (1), entre los puntos donde esperan en promedio los viajeros de
/// cada uno: la mitad de la estación es 0,5.
class PlanoDeEstacion {
  final Vagon tuyo;
  final Vagon otro;

  /// Dónde está el viajero sobre el eje; null si no se sabe o está lejos de la estación.
  final double? posicion;
  final DondeEstas donde;

  /// Más lejos del eje que esto, no está en la estación.
  static const fueraDelEjeM = 40.0;

  /// A menos de esto de la mitad, el GPS no alcanza para decir en qué vagón está.
  static const dudaM = 8.0;

  const PlanoDeEstacion._(this.tuyo, this.otro, this.posicion, this.donde);

  /// Como en el mapa, con el norte arriba: el vagón más al oeste se dibuja a la izquierda.
  bool get tuyoALaIzquierda => tuyo.punto.longitude < otro.punto.longitude;

  /// Null si el tramo no sube en una estación doble cuyo lado ya enseñaron los viajeros.
  static PlanoDeEstacion? de(Leg bus, LatLng? yo) {
    if (bus.vagones.length != 2 || !bus.subeEnEstacion) return null;
    final [tuyo, otro] = bus.vagones;
    final eje = _metros(otro.punto, tuyo.punto);
    final largo = math.sqrt(eje.x * eje.x + eje.y * eje.y);
    if (largo < 5) return null;
    if (yo == null) return PlanoDeEstacion._(tuyo, otro, null, DondeEstas.noSeSabe);
    final v = _metros(otro.punto, yo);
    final t = (v.x * eje.x + v.y * eje.y) / (largo * largo);
    final fuera = (v.x * eje.y - v.y * eje.x).abs() / largo;
    if (fuera > fueraDelEjeM || t < -1 || t > 2) return PlanoDeEstacion._(tuyo, otro, null, DondeEstas.noSeSabe);
    final duda = dudaM / largo;
    final donde = t > 0.5 + duda
        ? DondeEstas.enTuVagon
        : t < 0.5 - duda
            ? DondeEstas.enElOtro
            : DondeEstas.enLaMitad;
    return PlanoDeEstacion._(tuyo, otro, t, donde);
  }

  /// «Parece que estás en el vagón B: el A queda en el extremo hacia el Centro». Null si no hay nada que decir.
  String? leyenda(String ruta) => switch (donde) {
        DondeEstas.enElOtro =>
          'Parece que estás en el vagón ${otro.letra}: el ${tuyo.letra} queda en el extremo hacia ${tuyo.hacia}.',
        DondeEstas.enTuVagon => 'Parece que ya estás en el vagón ${tuyo.letra}, donde para el $ruta.',
        _ => null,
      };

  /// El vector de `desde` a `hasta`, en metros hacia el este y hacia el norte.
  static ({double x, double y}) _metros(LatLng desde, LatLng hasta) {
    const porGrado = 111320.0;
    final coseno = math.cos(desde.latitude * math.pi / 180);
    return (
      x: (hasta.longitude - desde.longitude) * porGrado * coseno,
      y: (hasta.latitude - desde.latitude) * porGrado,
    );
  }
}
