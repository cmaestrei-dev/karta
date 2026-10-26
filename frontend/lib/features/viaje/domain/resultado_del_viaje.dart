import 'package:equatable/equatable.dart';

import '../../../core/format.dart';

/// Lo que se midió de un bus del viaje: la espera en la parada y el tiempo a bordo, estimados y reales.
class BusMedido extends Equatable {
  final String ruta;
  final int esperaEstimadaMin;

  /// Null si no se pudo medir: el viaje empezó ya a bordo, o el GPS no lo vio esperando.
  final int? esperaRealMin;
  final int aBordoEstimadoMin;
  final int aBordoRealMin;

  const BusMedido({
    required this.ruta,
    required this.esperaEstimadaMin,
    required this.esperaRealMin,
    required this.aBordoEstimadoMin,
    required this.aBordoRealMin,
  });

  Map<String, dynamic> toJson() => {
        'ruta': ruta,
        'espera_estimada_min': esperaEstimadaMin,
        'espera_real_min': esperaRealMin,
        'a_bordo_estimado_min': aBordoEstimadoMin,
        'a_bordo_real_min': aBordoRealMin,
      };

  @override
  List<Object?> get props => [ruta, esperaEstimadaMin, esperaRealMin, aBordoEstimadoMin, aBordoRealMin];
}

/// Al llegar: cuánto estimó Karta al empezar y cuánto se tardó de verdad (D17). Se le muestra al viajero y, si
/// comparte sus viajes, se envía sin puntos ni paraderos para medir qué tan bien estima Karta.
class ResultadoDelViaje extends Equatable {
  final int estimadoMin;
  final int realMin;
  final List<BusMedido> buses;

  const ResultadoDelViaje({required this.estimadoMin, required this.realMin, required this.buses});

  /// Positivo: tardó más de lo estimado.
  int get diferenciaMin => realMin - estimadoMin;

  /// «Tardaste 37 min, 3 más de lo que estimó Karta.»
  String get enPalabras {
    final tardaste = 'Tardaste ${minutos(realMin)}';
    final d = diferenciaMin;
    if (d.abs() <= 1) return '$tardaste, justo lo que estimó Karta.';
    return '$tardaste, ${d.abs()} ${d > 0 ? 'más' : 'menos'} de lo que estimó Karta.';
  }

  Map<String, dynamic> toJson() => {
        'estimado_min': estimadoMin,
        'real_min': realMin,
        'buses': [for (final bus in buses) bus.toJson()],
      };

  @override
  List<Object?> get props => [estimadoMin, realMin, buses];
}

/// Minutos enteros de una duración, redondeados.
int minutosDe(Duration duracion) => (duracion.inSeconds / 60).round();
