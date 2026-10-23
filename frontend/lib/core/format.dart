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
