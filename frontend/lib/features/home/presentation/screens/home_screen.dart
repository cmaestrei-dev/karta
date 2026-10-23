import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location_service.dart';
import '../../../../core/widgets/karta_map.dart';
import '../../../../core/widgets/plaque.dart';
import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/widgets/incident_bottom_sheet.dart';
import '../../../incidents/presentation/widgets/incident_marker.dart';
import '../../../places/domain/place_models.dart';
import '../../../places/presentation/cubit/saved_places_cubit.dart';
import '../../../places/presentation/screens/place_search_screen.dart';
import '../../../places/presentation/screens/saved_places_screen.dart';
import '../../../trip/data/trip_repository.dart';
import '../../../trip/presentation/cubit/trip_cubits.dart';
import '../../../trip/presentation/screens/plan_route_screen.dart';
import '../widgets/nearby_stops_sheet.dart';
import '../widgets/profile_sheet.dart';

/// Inicio: el mapa con los incidentes, la placa «¿A dónde vas?», los lugares guardados
/// y las estaciones cercanas. Reportar queda al alcance del pulgar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NearbyStopsCubit(repository: context.read<TripRepository>()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  static const _hojaInicial = 0.26;
  static const _refresco = Duration(minutes: 5);

  final _mapa = MapController();
  Timer? _temporizador;
  LatLng? _miUbicacion;
  double _hoja = _hojaInicial;

  @override
  void initState() {
    super.initState();
    _ubicar();
    // Los incidentes vencen a las 3 h o 12 h: se refrescan mientras el inicio está abierto.
    _temporizador = Timer.periodic(_refresco, (_) => context.read<IncidentBloc>().add(LoadIncidentsEvent()));
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _ubicar() async {
    final estaciones = context.read<NearbyStopsCubit>();
    try {
      final ubicacion = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() => _miUbicacion = ubicacion.point);
      _mapa.move(ubicacion.point, 15);
      estaciones.load(ubicacion.point);
    } catch (e) {
      estaciones.showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _buscarDestino() async {
    final destino = await PlaceSearchScreen.open(context, centroDelMapa: _miUbicacion);
    if (destino != null && mounted) {
      PlanRouteScreen.open(context, destino: destino, origen: _miUbicacion != null ? TripPoint.miUbicacion(_miUbicacion!) : null);
    }
  }

  void _irA(TripPoint destino) {
    PlanRouteScreen.open(context, destino: destino, origen: _miUbicacion != null ? TripPoint.miUbicacion(_miUbicacion!) : null);
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    final bordeDeHoja = alto * _hoja;

    return BlocListener<IncidentBloc, IncidentState>(
      listener: (context, state) {
        if (state is IncidentsLoadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('No pudimos actualizar los incidentes; el mapa puede estar incompleto.'),
            action: SnackBarAction(label: 'Reintentar', onPressed: () => context.read<IncidentBloc>().add(LoadIncidentsEvent())),
          ));
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapa,
              options: const MapOptions(initialCenter: centroDeCartagena, initialZoom: 14),
              children: [
                const KartaTiles(),
                BlocBuilder<IncidentBloc, IncidentState>(
                  // Mientras se envía o recarga, el mapa conserva los marcadores anteriores.
                  buildWhen: (_, actual) => actual is IncidentsLoaded,
                  builder: (context, state) => MarkerLayer(
                    markers: state is IncidentsLoaded ? [for (final i in state.incidents) incidentMarker(context, i)] : [],
                  ),
                ),
                if (_miUbicacion != null)
                  MarkerLayer(markers: [Marker(point: _miUbicacion!, width: 40, height: 40, child: const UserLocationDot())]),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _PlacaDeBusqueda(onTap: _buscarDestino)),
                        const SizedBox(width: 8),
                        MapIconButton(icon: Icons.person_outline, tooltip: 'Tu cuenta', onPressed: () => showProfileSheet(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _LugaresGuardados(onIr: _irA),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: bordeDeHoja + 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MapIconButton(icon: Icons.my_location, tooltip: 'Centrar en mi ubicación', onPressed: _ubicar),
                  const SizedBox(height: 8),
                  // Media pantalla como máximo: con letra grande baja de renglón en vez de quedar bajo «Reportar».
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
                    child: const OsmAttribution(),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: bordeDeHoja + 16,
              child: FloatingActionButton.extended(
                onPressed: () => IncidentBottomSheet.show(context),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Reportar'),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                setState(() => _hoja = n.extent);
                return false;
              },
              child: DraggableScrollableSheet(
                initialChildSize: _hojaInicial,
                minChildSize: 0.14,
                maxChildSize: 0.62,
                snap: true,
                builder: (context, controlador) => Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  child: NearbyStopsSheet(controller: controlador, onReintentar: _ubicar),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacaDeBusqueda extends StatelessWidget {
  final VoidCallback onTap;

  const _PlacaDeBusqueda({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Plaque(
        onTap: onTap,
        elevated: true,
        semanticLabel: 'Buscar destino: ¿A dónde vas?',
        child: Row(
          children: [
            Icon(Icons.search, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text('¿A dónde vas?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LugaresGuardados extends StatelessWidget {
  final void Function(TripPoint destino) onIr;

  const _LugaresGuardados({required this.onIr});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedPlacesCubit, SavedPlacesState>(
      builder: (context, state) {
        final lugares = state.lugares;
        return SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final lugar in lugares)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MiniPlaque(
                    icon: lugar.icono.icono,
                    label: lugar.nombre,
                    onTap: () => onIr(TripPoint.deGuardado(lugar)),
                    onLongPress: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedPlacesScreen())),
                  ),
                ),
              MiniPlaque(
                icon: Icons.add,
                label: lugares.isEmpty ? 'Guardar Casa' : 'Guardar',
                onTap: () => addSavedPlaceFlow(
                  context,
                  icono: lugares.isEmpty ? SavedPlaceIcon.casa : SavedPlaceIcon.favorito,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
