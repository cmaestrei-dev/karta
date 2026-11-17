import 'package:flutter/material.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/ilustracion.dart';
import '../../../../core/design/movimiento.dart';
import '../../../../core/format.dart';
import '../../../../core/map/geometria.dart';
import '../../../../core/widgets/route_capsule.dart';
import '../../../incidents/domain/models/incident_models.dart';
import '../../domain/trip_models.dart';

/// Lo que distingue a una opción de las demás, para su burbuja en el mapa: «más rápida», «sin reportes»,
/// «sin transbordo». Null si no tiene nada que la distinga.
String? etiquetaDeOpcion(List<RouteOption> opciones, int k) {
  if (opciones.length < 2) return null;
  final opcion = opciones[k];
  final masRapida = opciones.map((o) => o.tiempoTotalMin).reduce((a, b) => a < b ? a : b);
  if (opcion.tiempoTotalMin == masRapida && opciones.indexWhere((o) => o.tiempoTotalMin == masRapida) == k) {
    return 'más rápida';
  }
  if (opcion.riesgo.totalIncidentes == 0 && opciones.any((o) => o.riesgo.totalIncidentes > 0)) return 'sin reportes';
  if (opcion.transbordos == 0 && opcion.buses.isNotEmpty && opciones.any((o) => o.transbordos > 0)) {
    return 'sin transbordo';
  }
  if (opcion.buses.isEmpty) return 'a pie';
  return null;
}

/// Los reportes vigentes a menos de 500 m del recorrido, los más graves primero (seguridad, vía, servicio)
/// y, entre iguales, los más confirmados.
List<Incident> reportesEnElCamino(RouteOption opcion, List<Incident> reportes) {
  const gravedad = {'seguridad': 0, 'via': 1, 'servicio': 2};
  final puntos = opcion.puntos;
  final cerca = [for (final r in reportes) if (distanciaALineaM(r.punto, puntos) <= radioDeRiesgoM) r];
  cerca.sort((a, b) {
    final porGrupo = (gravedad[a.grupo] ?? 3).compareTo(gravedad[b.grupo] ?? 3);
    return porGrupo != 0 ? porGrupo : b.votosSi.compareTo(a.votosSi);
  });
  return cerca;
}

/// Color de una opción en el mapa y en su tarjeta: el de su primera ruta, o el del texto si es a pie.
Color colorDeOpcion(BuildContext context, RouteOption opcion) {
  final bus = opcion.bus;
  return bus == null ? Bahia.de(context).textoSuave : RouteCapsule.colorDe(bus.tipoRuta);
}

/// Una forma de llegar: minutos grandes (comparables entre tarjetas), la secuencia de tramos, dónde subir,
/// el transbordo y qué reportó la comunidad en el camino. La elegida lleva el borde de su ruta.
class TarjetaDeOpcion extends StatelessWidget {
  final RouteOption opcion;
  final List<Incident> enElCamino;
  final bool elegida;
  final VoidCallback onTap;

  const TarjetaDeOpcion({
    super.key,
    required this.opcion,
    required this.enElCamino,
    required this.elegida,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final color = colorDeOpcion(context, opcion);
    final bus = opcion.bus;
    final radio = BorderRadius.circular(18);
    final transbordo = opcion.puntoDeTransbordo;
    final resumenReportes = switch (enElCamino.length) {
      0 => 'sin reportes en el camino',
      1 => '${enElCamino.first.ilustracion?.nombre ?? 'un reporte'} en el camino',
      final n => '$n reportes en el camino',
    };

    return Semantics(
      button: true,
      selected: elegida,
      label: [
        '${opcion.tiempoTotalMin} minutos',
        opcion.buses.isEmpty ? 'a pie' : 'en ${opcion.buses.map((b) => b.rutasEnTexto).join(' y luego ')}',
        if (bus != null) 'sube en ${bus.desde}',
        if (transbordo != null) 'cambias de bus en $transbordo',
        resumenReportes,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radio,
          onTap: onTap,
          child: AnimatedContainer(
            duration: Movimiento.rapido,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              // La elegida toma un velo del color de su ruta, el mismo de su borde y de su burbuja en el mapa.
              color: elegida ? Color.alphaBlend(color.withValues(alpha: 0.14), b.tarjeta) : b.tarjeta,
              borderRadius: radio,
              border: Border.all(color: elegida ? color : Colors.transparent, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${opcion.tiempoTotalMin}',
                          style: texto.displaySmall?.copyWith(fontSize: 32, height: 1, fontFeatures: tabularFigures)),
                      Text('min', style: texto.labelMedium?.copyWith(color: b.textoSuave)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LegSequence(tramos: opcion.tramos),
                      const SizedBox(height: 6),
                      if (bus != null)
                        _Linea(icono: Icons.directions_bus_outlined, texto: 'Sube en ${bus.desde}'),
                      if (transbordo != null)
                        _Linea(icono: Icons.sync_alt, texto: 'Cambias de bus en $transbordo'),
                      if (bus == null)
                        _Linea(icono: Icons.directions_walk, texto: '${metros(opcion.distanciaCaminataM)} a pie'),
                      const SizedBox(height: 6),
                      _ReportesEnElCamino(reportes: enElCamino),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Linea({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icono, size: 16, color: b.textoSuave)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: b.textoSuave)),
          ),
        ],
      ),
    );
  }
}

/// «Sin reportes en el camino» con un visto, o la ficha del reporte más grave con su ilustración.
class _ReportesEnElCamino extends StatelessWidget {
  final List<Incident> reportes;

  const _ReportesEnElCamino({required this.reportes});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    if (reportes.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check, size: 16, color: b.enVivo),
          const SizedBox(width: 6),
          Text('Sin reportes en el camino', style: texto.labelMedium?.copyWith(color: b.textoSuave)),
        ],
      );
    }
    final principal = reportes.first;
    final (_, suave) = b.delGrupo(principal.grupo);
    final tipo = principal.ilustracion;
    final otros = reportes.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
      decoration: BoxDecoration(color: suave, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tipo != null) Ilustracion(tipo, tamano: 22, conFondo: false) else const Icon(Icons.campaign_outlined, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${tipo?.nombre ?? 'Un reporte'} en el camino${otros > 0 ? ' y $otros más' : ''}',
              style: texto.labelMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// «🚶 4 › T103 › 🚶 3»: los tramos en orden, con los minutos de cada caminata. La caminata del transbordo
/// de una estación a sí misma no se muestra: ahí solo se cambia de bus.
class LegSequence extends StatelessWidget {
  final List<Leg> tramos;

  const LegSequence({super.key, required this.tramos});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(fontFeatures: tabularFigures);
    final piezas = <Widget>[];
    for (final tramo in tramos) {
      if (tramo.esCaminata && tramo.distanciaM < 30 && tramos.first != tramo && tramos.last != tramo) continue;
      if (piezas.isNotEmpty) piezas.add(Icon(Icons.chevron_right, size: 16, color: b.textoSuave));
      piezas.add(tramo.esCaminata
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_walk, size: 18, color: b.texto),
              Text('${tramo.duracionMin}', style: estilo),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              for (final (k, ruta) in tramo.rutas.indexed) ...[
                if (k > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text('o', style: estilo)),
                RouteCapsule(codigo: ruta, tipo: tramo.tipoRuta),
              ],
            ]));
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: piezas);
  }
}
