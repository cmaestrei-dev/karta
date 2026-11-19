import 'package:equatable/equatable.dart';

/// Lo del viajero en la corona de una estación (solo con sesión).
class TuCorona extends Equatable {
  /// null: todavía no ha respondido si quiere participar.
  final bool? participas;

  /// Días con aportes en los últimos 30, contando hoy.
  final int llevas;

  /// Días que le faltan para la corona; 0: mañana puede ser suya; null: ya reina.
  final int? faltan;
  final bool puedesPonerApodo;
  final DateTime? otroApodoDesde;
  final bool reportasteElApodo;

  const TuCorona({
    required this.participas,
    required this.llevas,
    required this.faltan,
    required this.puedesPonerApodo,
    this.otroApodoDesde,
    this.reportasteElApodo = false,
  });

  factory TuCorona.fromJson(Map<String, dynamic> json) => TuCorona(
        participas: json['participas'] as bool?,
        llevas: json['llevas'] as int,
        faltan: json['faltan'] as int?,
        puedesPonerApodo: json['puedes_poner_apodo'] as bool,
        otroApodoDesde: json['otro_apodo_desde'] == null ? null : DateTime.parse(json['otro_apodo_desde'] as String),
        reportasteElApodo: json['reportaste_el_apodo'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [participas, llevas, faltan, puedesPonerApodo, otroApodoDesde, reportasteElApodo];
}

/// La corona de una estación (docs/plan-juego.md): quién reina, como «un karteño» o su apodo de karteño, y el
/// apodo del día.
class CoronaDeEstacion extends Equatable {
  final String estacion;
  final String? rey;
  final DateTime? desde;
  final bool eresRey;
  final String? apodo;
  final DateTime? apodoHasta;
  final TuCorona? tu;

  const CoronaDeEstacion({
    required this.estacion,
    this.rey,
    this.desde,
    this.eresRey = false,
    this.apodo,
    this.apodoHasta,
    this.tu,
  });

  factory CoronaDeEstacion.fromJson(Map<String, dynamic> json) {
    final rey = json['rey'] as Map<String, dynamic>?;
    final apodo = json['apodo_del_dia'] as Map<String, dynamic>?;
    return CoronaDeEstacion(
      estacion: json['estacion'] as String,
      rey: rey?['nombre'] as String?,
      desde: rey == null ? null : DateTime.parse(rey['desde'] as String),
      eresRey: json['eres_rey'] as bool? ?? false,
      apodo: apodo?['texto'] as String?,
      apodoHasta: apodo == null ? null : DateTime.parse(apodo['hasta'] as String),
      tu: json['tu'] == null ? null : TuCorona.fromJson(json['tu'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [estacion, rey, desde, eresRey, apodo, apodoHasta, tu];
}

/// Si participa en las coronas y cómo se muestra si reina.
class AjustesDeCorona extends Equatable {
  final bool? participa;
  final bool visible;
  final String? apodo;

  const AjustesDeCorona({this.participa, this.visible = false, this.apodo});

  factory AjustesDeCorona.fromJson(Map<String, dynamic> json) => AjustesDeCorona(
        participa: json['participa'] as bool?,
        visible: json['visible'] as bool? ?? false,
        apodo: json['apodo'] as String?,
      );

  @override
  List<Object?> get props => [participa, visible, apodo];
}
