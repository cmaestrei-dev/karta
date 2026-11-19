import 'package:equatable/equatable.dart';

import 'album.dart';

/// Algo que se ganó durante el viaje, para celebrarlo un momento en la pantalla sin interrumpir.
sealed class LogroDelViaje extends Equatable {
  const LogroDelViaje();
}

/// Pasó por primera vez por una estación: entra a su álbum.
class LaminaNueva extends LogroDelViaje {
  final EstacionDelAlbum estacion;
  final int conseguidas;
  final int total;

  const LaminaNueva(this.estacion, {required this.conseguidas, required this.total});

  @override
  List<Object?> get props => [estacion.id, conseguidas, total];
}

/// El primer bus compartido del día: un sello más en la tarjeta (o la tarjeta llena).
class SelloDelDia extends LogroDelViaje {
  final int sellos;
  final bool llena;

  const SelloDelDia({required this.sellos, required this.llena});

  @override
  List<Object?> get props => [sellos, llena];
}
