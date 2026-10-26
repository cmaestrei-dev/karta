import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/format.dart';
import '../../../../core/widgets/route_capsule.dart';
import '../../../places/domain/place_models.dart';
import '../../../trip/domain/trip_models.dart';
import '../../../trip/presentation/cubit/trip_cubits.dart';
import '../../../trip/presentation/screens/plan_route_screen.dart';
import '../../../trip/presentation/screens/route_page_screen.dart';

/// Contenido de la hoja inferior del inicio: lo que va arriba ([encabezado]) y las estaciones cerca.
class NearbyStopsSheet extends StatelessWidget {
  final ScrollController controller;
  final VoidCallback onReintentar;
  final List<Widget> encabezado;

  const NearbyStopsSheet({super.key, required this.controller, required this.onReintentar, this.encabezado = const []});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;

    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: b.asa, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        ...encabezado,
        const SizedBox(height: 20),
        Semantics(header: true, child: Text('Cerca de ti', style: texto.titleLarge)),
        const SizedBox(height: 10),
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
            NearbyStopsLoaded(:final estaciones, :final rutas) when estaciones.isEmpty && rutas.isEmpty => Text(
                'No hay estaciones de Transcaribe a menos de 1,5 km. Busca tu destino arriba para ver otras rutas.',
                style: texto.bodyMedium?.copyWith(color: b.textoSuave),
              ),
            NearbyStopsLoaded(:final estaciones, :final rutas) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final estacion in estaciones)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: _TarjetaDeEstacion(estacion: estacion)),
                  if (rutas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Semantics(header: true, child: Text('Rutas que pasan cerca', style: texto.titleMedium)),
                    const SizedBox(height: 8),
                    for (final ruta in rutas)
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: _FilaDeRutaCercana(ruta: ruta)),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Es el punto de la calle por donde pasa la ruta: el paradero puede estar a unos metros.',
                        style: texto.bodySmall?.copyWith(color: b.textoSuave),
                      ),
                    ),
                  ],
                ],
              ),
          },
        ),
      ],
    );
  }
}

/// «A107 · Paradero Av. Kennedy con Calle 18 · 120 m»: tocarla abre la ruta con su horario y estaciones.
class _FilaDeRutaCercana extends StatelessWidget {
  final RutaCercana ruta;

  const _FilaDeRutaCercana({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final aPie = '${metros(ruta.caminataM)} · ${minutos(ruta.caminataMin)} a pie';
    final radio = BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: 'Ruta ${ruta.ruta}, se toma en ${ruta.paradero}, $aPie. Toca para ver su horario y estaciones',
      excludeSemantics: true,
      child: Material(
        color: b.tarjeta,
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          onTap: () => RoutePageScreen.open(context, ruta.ruta),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  SizedBox(width: 64, child: RouteCapsule(codigo: ruta.ruta, tipo: ruta.tipo)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ruta.paradero.replaceFirst('Paradero ', ''), style: texto.titleSmall, maxLines: 2),
                        Text(aPie, style: texto.bodySmall?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: b.textoSuave),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaDeEstacion extends StatelessWidget {
  final Stop estacion;

  const _TarjetaDeEstacion({required this.estacion});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final visibles = estacion.rutas.take(6).toList();
    final ocultas = estacion.rutas.length - visibles.length;
    final aPie = '${metros(estacion.caminataM)} · ${minutos(estacion.caminataMin)} a pie';
    final radio = BorderRadius.circular(18);

    return Semantics(
      button: true,
      label: 'Estación ${estacion.nombre}, $aPie. Rutas ${estacion.rutas.join(', ')}. Toca para ver cómo llegar',
      excludeSemantics: true,
      child: Material(
        color: b.tarjeta,
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          onTap: () => PlanRouteScreen.open(
            context,
            destino: TripPoint(nombre: 'Estación ${estacion.nombre}', punto: estacion.punto),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: b.acentoSuave, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.directions_bus_outlined, color: b.acento),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estación ${estacion.nombre}', style: texto.titleMedium),
                      Text(aPie, style: texto.bodySmall?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
                      const SizedBox(height: 8),
                      // Las rutas van en su propia línea: con letra grande bajan de renglón sin apretar el nombre.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final ruta in visibles) RouteCapsule(codigo: ruta, tipo: tipoDeRuta(ruta)),
                          if (ocultas > 0)
                            Text('+$ocultas más', style: texto.labelMedium?.copyWith(color: b.textoSuave)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Icon(Icons.chevron_right, color: b.textoSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
