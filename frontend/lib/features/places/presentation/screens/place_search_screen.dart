import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location_service.dart';
import '../../data/places_repository.dart';
import '../../domain/place_models.dart';
import '../cubit/place_search_cubit.dart';
import '../cubit/saved_places_cubit.dart';
import 'pick_on_map_screen.dart';

/// Buscar un lugar de Cartagena, elegirlo en el mapa o usar uno guardado. Devuelve un [TripPoint].
class PlaceSearchScreen extends StatelessWidget {
  final String hint;
  final bool permitirMiUbicacion;
  final LatLng? centroDelMapa;

  const PlaceSearchScreen({
    super.key,
    this.hint = '¿A dónde vas?',
    this.permitirMiUbicacion = false,
    this.centroDelMapa,
  });

  static Future<TripPoint?> open(BuildContext context,
      {String hint = '¿A dónde vas?', bool permitirMiUbicacion = false, LatLng? centroDelMapa}) {
    return Navigator.of(context).push<TripPoint>(MaterialPageRoute(
      builder: (_) => PlaceSearchScreen(hint: hint, permitirMiUbicacion: permitirMiUbicacion, centroDelMapa: centroDelMapa),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PlaceSearchCubit(repository: context.read<PlacesRepository>()),
      child: _PlaceSearchView(hint: hint, permitirMiUbicacion: permitirMiUbicacion, centroDelMapa: centroDelMapa),
    );
  }
}

class _PlaceSearchView extends StatefulWidget {
  final String hint;
  final bool permitirMiUbicacion;
  final LatLng? centroDelMapa;

  const _PlaceSearchView({required this.hint, required this.permitirMiUbicacion, required this.centroDelMapa});

  @override
  State<_PlaceSearchView> createState() => _PlaceSearchViewState();
}

class _PlaceSearchViewState extends State<_PlaceSearchView> {
  final _controller = TextEditingController();
  bool _ubicando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _usarMiUbicacion() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _ubicando = true);
    try {
      final ubicacion = await LocationService.getCurrentLocation();
      if (mounted) Navigator.of(context).pop(TripPoint.miUbicacion(ubicacion.point));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  Future<void> _elegirEnMapa() async {
    final elegido = await Navigator.of(context).push<TripPoint>(MaterialPageRoute(
      builder: (_) => PickOnMapScreen(centroInicial: widget.centroDelMapa),
    ));
    if (elegido != null && mounted) Navigator.of(context).pop(elegido);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: texto.titleMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (texto) {
            setState(() {});
            context.read<PlaceSearchCubit>().onQueryChanged(texto);
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() {});
                context.read<PlaceSearchCubit>().onQueryChanged('');
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocBuilder<PlaceSearchCubit, PlaceSearchState>(
            builder: (context, state) => state.status == PlaceSearchStatus.buscando || _ubicando
                ? const LinearProgressIndicator(minHeight: 3)
                : Divider(height: 3, thickness: 1, color: scheme.outlineVariant),
          ),
        ),
      ),
      body: BlocBuilder<PlaceSearchCubit, PlaceSearchState>(
        builder: (context, state) {
          if (state.consulta.length < 2) {
            return _SinConsulta(
              permitirMiUbicacion: widget.permitirMiUbicacion,
              onMiUbicacion: _ubicando ? null : _usarMiUbicacion,
              onElegirEnMapa: _elegirEnMapa,
            );
          }
          return switch (state.status) {
            PlaceSearchStatus.sinResultados => _Mensaje(
                titulo: 'No encontramos «${state.consulta}» en Cartagena',
                detalle: 'Prueba con un barrio, una estación de Transcaribe o un sitio conocido, o elige el punto en el mapa.',
                accion: TextButton.icon(onPressed: _elegirEnMapa, icon: const Icon(Icons.map_outlined), label: const Text('Elegir en el mapa')),
              ),
            PlaceSearchStatus.error => _Mensaje(
                titulo: 'No pudimos buscar',
                detalle: state.mensaje ?? '',
                accion: FilledButton.tonal(
                  onPressed: () => context.read<PlaceSearchCubit>().retry(),
                  child: const Text('Reintentar'),
                ),
              ),
            // La última fila siempre ofrece el mapa: si el lugar exacto no aparece, hay salida.
            _ => ListView.separated(
                itemCount: state.resultados.length + 1,
                separatorBuilder: (_, _) => const Divider(indent: 72),
                itemBuilder: (context, i) {
                  if (i == state.resultados.length) {
                    return ListTile(
                      minVerticalPadding: 12,
                      leading: const SizedBox(width: 40, child: Icon(Icons.map_outlined)),
                      title: const Text('Elegir en el mapa'),
                      subtitle: const Text('¿No aparece el punto exacto? Márcalo tú'),
                      onTap: _elegirEnMapa,
                    );
                  }
                  final lugar = state.resultados[i];
                  return ListTile(
                    minVerticalPadding: 12,
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Icon(lugar.icono),
                    ),
                    title: Text(lugar.nombre, style: texto.titleMedium),
                    subtitle: Text(lugar.tipo),
                    onTap: () => Navigator.of(context).pop(TripPoint.deLugar(lugar)),
                  );
                },
              ),
          };
        },
      ),
    );
  }
}

class _SinConsulta extends StatelessWidget {
  final bool permitirMiUbicacion;
  final VoidCallback? onMiUbicacion;
  final VoidCallback onElegirEnMapa;

  const _SinConsulta({required this.permitirMiUbicacion, required this.onMiUbicacion, required this.onElegirEnMapa});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return BlocBuilder<SavedPlacesCubit, SavedPlacesState>(
      builder: (context, guardados) {
        return ListView(
          children: [
            if (permitirMiUbicacion)
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Tu ubicación actual'),
                onTap: onMiUbicacion,
              ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Elegir en el mapa'),
              subtitle: const Text('Mueve el mapa hasta el punto exacto'),
              onTap: onElegirEnMapa,
            ),
            if (guardados.lugares.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text('Lugares guardados', style: texto.titleSmall),
              ),
              for (final lugar in guardados.lugares)
                ListTile(
                  leading: Icon(lugar.icono.icono),
                  title: Text(lugar.nombre, style: texto.titleMedium),
                  onTap: () => Navigator.of(context).pop(TripPoint.deGuardado(lugar)),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String titulo;
  final String detalle;
  final Widget accion;

  const _Mensaje({required this.titulo, required this.detalle, required this.accion});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: texto.titleMedium),
          const SizedBox(height: 8),
          Text(detalle, style: texto.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          accion,
        ],
      ),
    );
  }
}
