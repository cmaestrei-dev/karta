import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/karta_theme.dart';
import '../../../../core/widgets/plaque.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../../core/widgets/route_capsule.dart';
import '../../domain/trip_models.dart';

/// Una forma de llegar, en su placa: minutos grandes a la izquierda (comparables entre placas),
/// la secuencia de tramos y el riesgo del recorrido.
class RouteOptionTile extends StatelessWidget {
  final RouteOption opcion;
  final VoidCallback onTap;

  const RouteOptionTile({super.key, required this.opcion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bus = opcion.bus;
    final aPie = '${metros(opcion.distanciaCaminataM)} a pie en total';
    final detalle = bus != null ? 'Sube en ${bus.desde} · $aPie' : aPie;

    return Plaque(
      onTap: onTap,
      semanticLabel: '${opcion.resumen}, ${opcion.tiempoTotalMin} minutos aproximados. $detalle',
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${opcion.tiempoTotalMin}',
                    style: texto.headlineMedium?.copyWith(fontFeatures: tabularFigures, height: 1, color: scheme.primary)),
                Text('min aprox.', style: texto.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LegSequence(tramos: opcion.tramos),
                const SizedBox(height: 6),
                Text(detalle, style: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                RiskBadge(nivel: opcion.riesgo.nivel, totalIncidentes: opcion.riesgo.totalIncidentes),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(Icons.chevron_right, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

/// "🚶 4 min › T103 › 🚶 3 min": los tramos en orden, con los minutos de cada caminata.
class LegSequence extends StatelessWidget {
  final List<Leg> tramos;

  const LegSequence({super.key, required this.tramos});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(fontFeatures: tabularFigures);
    final piezas = <Widget>[];
    for (final (i, tramo) in tramos.indexed) {
      if (i > 0) piezas.add(Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant));
      piezas.add(tramo.esCaminata
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_walk, size: 18, color: scheme.onSurface),
              Text(minutos(tramo.duracionMin), style: estilo),
            ])
          : RouteCapsule(codigo: tramo.ruta ?? '', tipo: tramo.tipoRuta));
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: piezas);
  }
}
