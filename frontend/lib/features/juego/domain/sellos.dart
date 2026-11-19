import 'package:equatable/equatable.dart';

/// La tarjeta de sellos (docs/plan-juego.md): un sello por cada día en que compartió dónde iba su bus. Con 7 se
/// llena y empieza otra. Los días no tienen que ser seguidos ni caer en la misma semana: faltar un día no quita
/// nada (lo que Pokémon GO hace con su «investigación», no con sus rachas).
class TarjetaDeSellos extends Equatable {
  static const porTarjeta = 7;

  /// Los días sellados de la tarjeta actual (solo la fecha, hora local).
  final List<DateTime> dias;

  /// Cuántas tarjetas ha llenado.
  final int llenas;

  const TarjetaDeSellos({this.dias = const [], this.llenas = 0});

  int get sellos => dias.length;

  static DateTime _dia(DateTime momento) => DateTime(momento.year, momento.month, momento.day);

  bool selladoEl(DateTime momento) => dias.contains(_dia(momento));

  /// Sella el día de [momento]. Una vez por día; al séptimo, la tarjeta queda llena y empieza otra vacía.
  ({TarjetaDeSellos tarjeta, bool sellado, bool llena}) sellar(DateTime momento) {
    final dia = _dia(momento);
    if (dias.contains(dia)) return (tarjeta: this, sellado: false, llena: false);
    final nuevos = [...dias, dia];
    if (nuevos.length < porTarjeta) {
      return (tarjeta: TarjetaDeSellos(dias: nuevos, llenas: llenas), sellado: true, llena: false);
    }
    return (tarjeta: TarjetaDeSellos(llenas: llenas + 1), sellado: true, llena: true);
  }

  factory TarjetaDeSellos.fromJson(Map<String, dynamic> json) => TarjetaDeSellos(
        dias: [for (final d in json['dias'] as List<dynamic>? ?? const []) DateTime.parse(d as String)],
        llenas: json['llenas'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'dias': [for (final d in dias) '${d.year.toString().padLeft(4, '0')}-${_dos(d.month)}-${_dos(d.day)}'],
        'llenas': llenas,
      };

  static String _dos(int n) => n.toString().padLeft(2, '0');

  @override
  List<Object?> get props => [dias, llenas];
}
