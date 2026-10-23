import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/karta_theme.dart';
import '../../../../core/widgets/plaque.dart';
import '../../../../core/widgets/route_capsule.dart';
import '../../../places/domain/place_models.dart';
import '../../../trip/domain/trip_models.dart';
import '../../../trip/presentation/cubit/trip_cubits.dart';
import '../../../trip/presentation/screens/plan_route_screen.dart';

/// Contenido de la hoja inferior del inicio: estaciones de Transcaribe cerca, cada una en su placa.
class NearbyStopsSheet extends StatelessWidget {
  final ScrollController controller;
  final VoidCallback onReintentar;

  const NearbyStopsSheet({super.key, required this.controller, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 32,
            height: 4,
            decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text('Estaciones cerca', style: texto.titleLarge),
        Text('de Transcaribe, desde donde estás', style: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        BlocBuilder<NearbyStopsCubit, NearbyStopsState>(
          builder: (context, state) => switch (state) {
            NearbyStopsLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            NearbyStopsFailed(:final mensaje) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mensaje, style: texto.bodyMedium),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: onReintentar, child: const Text('Reintentar')),
                ],
              ),
            NearbyStopsLoaded(:final estaciones) when estaciones.isEmpty => Text(
                'No hay estaciones de la troncal a menos de 1,5 km. Busca tu destino arriba para ver otras rutas.',
                style: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            NearbyStopsLoaded(:final estaciones) => Column(
                children: [
                  for (final estacion in estaciones)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: _PlacaDeEstacion(estacion: estacion)),
                ],
              ),
          },
        ),
      ],
    );
  }
}

class _PlacaDeEstacion extends StatelessWidget {
  final Stop estacion;

  const _PlacaDeEstacion({required this.estacion});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final visibles = estacion.rutas.take(6).toList();
    final ocultas = estacion.rutas.length - visibles.length;
    final aPie = '${metros(estacion.caminataM)} · ${minutos(estacion.caminataMin)} a pie';

    return Plaque(
      semanticLabel: 'Estación ${estacion.nombre}, $aPie. Rutas ${estacion.rutas.join(', ')}. Toca para ver cómo llegar',
      onTap: () => PlanRouteScreen.open(
        context,
        destino: TripPoint(nombre: 'Estación ${estacion.nombre}', punto: estacion.punto),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.directions_bus, color: scheme.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(estacion.nombre, style: texto.titleMedium?.copyWith(color: scheme.primary)),
                Text(aPie, style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures)),
                const SizedBox(height: 8),
                // Las rutas van en su propia línea: con letra grande bajan de renglón sin apretar el nombre.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final ruta in visibles) RouteCapsule(codigo: ruta, tipo: tipoDeRuta(ruta)),
                    if (ocultas > 0)
                      Text('+$ocultas más', style: texto.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
