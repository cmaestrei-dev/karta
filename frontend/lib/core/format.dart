/// Formatos en español de Colombia para distancias y tiempos. La cifra y su unidad van unidas por un
/// espacio que no se parte ([nbsp]): con letra grande, «90 m» nunca queda partido en dos renglones.
const nbsp = '\u00A0';

String metros(num distancia) {
  if (distancia < 1000) return '${(distancia / 10).round() * 10}${nbsp}m';
  final km = (distancia / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '$km${nbsp}km';
}

String minutos(num cuantos) => '$cuantos${nbsp}min';

String haceCuanto(DateTime fecha, {DateTime? ahora}) {
  final diferencia = (ahora ?? DateTime.now()).difference(fecha);
  if (diferencia.inMinutes < 1) return 'hace un momento';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  return 'hace ${diferencia.inHours} h';
}

String dentroDe(DateTime fecha, {DateTime? ahora}) {
  final restante = fecha.difference(ahora ?? DateTime.now());
  if (restante.inMinutes < 60) return '${restante.inMinutes.clamp(1, 59)} min';
  final horas = restante.inHours;
  final minutos = restante.inMinutes % 60;
  return minutos == 0 ? '$horas h' : '$horas h $minutos min';
}

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

/// Cuándo sale el viajero: «Hoy 6:30 p. m.», «Mañana 5:30 a. m.» o «Vie 30 oct 8:00 a. m.».
String cuandoSale(DateTime salida, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final dias = DateTime(salida.year, salida.month, salida.day).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  final dia = switch (dias) {
    0 => 'Hoy',
    1 => 'Mañana',
    _ => '${_dias[salida.weekday - 1][0].toUpperCase()}${_dias[salida.weekday - 1].substring(1)} '
        '${salida.day} ${_meses[salida.month - 1]}',
  };
  final hora = salida.hour % 12 == 0 ? 12 : salida.hour % 12;
  return '$dia $hora:${salida.minute.toString().padLeft(2, '0')} ${salida.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// «05:30» → «5:30 a. m.», «21:00» → «9:00 p. m.» (formato de Colombia).
String horaLegible(String hhmm) {
  final partes = hhmm.split(':');
  final hora = int.parse(partes[0]);
  final hora12 = hora % 12 == 0 ? 12 : hora % 12;
  return '$hora12:${partes[1]}$nbsp${hora < 12 ? 'a.${nbsp}m.' : 'p.${nbsp}m.'}';
}
