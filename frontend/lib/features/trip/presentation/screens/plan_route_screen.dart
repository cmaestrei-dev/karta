import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/location_service.dart';
import '../../../../core/widgets/plaque.dart';
import '../../../places/domain/place_models.dart';
import '../../../places/presentation/screens/place_search_screen.dart';
import '../../data/trip_repository.dart';
import '../cubit/trip_cubits.dart';
import '../widgets/route_option_tile.dart';
import 'route_detail_screen.dart';

/// "Cómo llegar": origen y destino en una placa, y las formas de llegar ordenadas por tiempo y riesgo.
class PlanRouteScreen extends StatelessWidget {
  final TripPoint destino;
  final TripPoint? origen;

  const PlanRouteScreen({super.key, required this.destino, this.origen});

  static Future<void> open(BuildContext context, {required TripPoint destino, TripPoint? origen}) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlanRouteScreen(destino: destino, origen: origen)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TripPlanCubit(repository: context.read<TripRepository>()),
      child: _PlanRouteView(destinoInicial: destino, origenInicial: origen),
    );
  }
}

class _PlanRouteView extends StatefulWidget {
  final TripPoint destinoInicial;
  final TripPoint? origenInicial;

  const _PlanRouteView({required this.destinoInicial, required this.origenInicial});

  @override
  State<_PlanRouteView> createState() => _PlanRouteViewState();
}

class _PlanRouteViewState extends State<_PlanRouteView> {
  late TripPoint _destino = widget.destinoInicial;
  late TripPoint? _origen = widget.origenInicial;
  String? _errorOrigen;

  @override
  void initState() {
    super.initState();
    if (_origen == null) {
      _ubicarOrigen();
    } else {
      _planear();
    }
  }

  Future<void> _ubicarOrigen() async {
    setState(() => _errorOrigen = null);
    try {
      final ubicacion = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() => _origen = TripPoint.miUbicacion(ubicacion.point));
      _planear();
    } catch (e) {
      if (mounted) setState(() => _errorOrigen = e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _planear() {
    final origen = _origen;
    if (origen != null) context.read<TripPlanCubit>().plan(origen, _destino);
  }

  Future<void> _cambiarOrigen() async {
    final nuevo = await PlaceSearchScreen.open(context,
        hint: '¿Desde dónde sales?', permitirMiUbicacion: true, centroDelMapa: _origen?.punto);
    if (nuevo == null) return;
    setState(() {
      _origen = nuevo;
      _errorOrigen = null;
    });
    _planear();
  }

  Future<void> _cambiarDestino() async {
    final nuevo = await PlaceSearchScreen.open(context, centroDelMapa: _destino.punto);
    if (nuevo == null) return;
    setState(() => _destino = nuevo);
    _planear();
  }

  void _invertir() {
    final origen = _origen;
    if (origen == null) return;
    setState(() {
      _origen = _destino;
      _destino = origen;
    });
    _planear();
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cómo llegar')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Plaque(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _Extremo(
                          etiqueta: 'Desde',
                          nombre: _origen?.nombre ?? (_errorOrigen != null ? 'Elige el origen' : 'Buscando tu ubicación…'),
                          icono: _origen?.esMiUbicacion ?? true ? Icons.my_location : Icons.trip_origin,
                          onTap: _cambiarOrigen,
                        ),
                        Divider(height: 1, color: scheme.primary.withValues(alpha: 0.25)),
                        _Extremo(etiqueta: 'Hasta', nombre: _destino.nombre, icono: Icons.place, onTap: _cambiarDestino),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Invertir origen y destino',
                    onPressed: _origen == null ? null : _invertir,
                    icon: const Icon(Icons.swap_vert),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _errorOrigen != null
                ? _Aviso(
                    titulo: 'No sabemos desde dónde sales',
                    detalle: _errorOrigen!,
                    acciones: [
                      FilledButton.tonal(onPressed: _ubicarOrigen, child: const Text('Reintentar')),
                      TextButton(onPressed: _cambiarOrigen, child: const Text('Elegir el origen')),
                    ],
                  )
                : BlocBuilder<TripPlanCubit, TripPlanState>(
                    builder: (context, state) => switch (state) {
                      TripPlanLoading() => const _Cargando(),
                      TripPlanFailed(:final mensaje) => _Aviso(
                          titulo: 'No pudimos buscar rutas',
                          detalle: mensaje,
                          acciones: [FilledButton.tonal(onPressed: _planear, child: const Text('Reintentar'))],
                        ),
                      TripPlanLoaded(:final sugerencias) when sugerencias.opciones.isEmpty => _Aviso(
                          titulo: 'Sin rutas directas',
                          detalle: '${sugerencias.nota} Prueba con un punto más cerca de una estación o de una vía principal.',
                          acciones: [TextButton(onPressed: _cambiarDestino, child: const Text('Cambiar el destino'))],
                        ),
                      TripPlanLoaded(:final sugerencias) => ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                sugerencias.opciones.length == 1
                                    ? '1 forma de llegar'
                                    : '${sugerencias.opciones.length} formas de llegar',
                                style: texto.titleMedium,
                              ),
                            ),
                            for (final opcion in sugerencias.opciones)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: RouteOptionTile(
                                  opcion: opcion,
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => RouteDetailScreen(opcion: opcion, origen: _origen!, destino: _destino),
                                  )),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: Text(
                                'Ordenadas por tiempo y por los incidentes reportados en el camino. ${sugerencias.nota} ${sugerencias.fuente}',
                                style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Extremo extends StatelessWidget {
  final String etiqueta;
  final String nombre;
  final IconData icono;
  final VoidCallback onTap;

  const _Extremo({required this.etiqueta, required this.nombre, required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$etiqueta: $nombre. Toca para cambiar',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Icon(icono, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(etiqueta, style: texto.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(nombre, style: texto.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Buscando rutas',
      child: const Column(
        children: [
          LinearProgressIndicator(),
          Padding(padding: EdgeInsets.all(24), child: Text('Buscando rutas de Transcaribe…')),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String titulo;
  final String detalle;
  final List<Widget> acciones;

  const _Aviso({required this.titulo, required this.detalle, required this.acciones});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(titulo, style: texto.titleLarge),
        const SizedBox(height: 8),
        Text(detalle, style: texto.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: acciones),
      ],
    );
  }
}
