import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/movimiento.dart';
import '../../../../core/location_service.dart';
import '../../../../core/map/capa_bahia.dart';
import '../../../../core/widgets/karta_map.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../incidents/domain/models/incident_models.dart';
import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/widgets/hoja_de_reporte.dart';
import '../../../incidents/presentation/widgets/pin_de_reporte.dart';
import '../../../places/domain/place_models.dart';
import '../../../places/presentation/screens/place_search_screen.dart';
import '../../../trip/data/trip_repository.dart';
import '../../../trip/domain/trip_models.dart';
import '../../../trip/presentation/cubit/trip_cubits.dart';
import '../../../trip/presentation/screens/plan_route_screen.dart';
import '../widgets/accesos_guardados.dart';
import '../widgets/avatar_de_viajero.dart';
import '../widgets/nearby_stops_sheet.dart';
import '../widgets/profile_sheet.dart';

/// Inicio: el mapa propio con la troncal y los reportes de la comunidad. Lo que se toca va abajo,
/// al alcance del pulgar: la hoja con «¿A dónde vas?», los lugares guardados y lo que hay cerca.
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
  static const _hojaMinima = 0.2;
  static const _hojaInicial = 0.42;
  static const _hojaMaxima = 0.86;
  static const _refresco = Duration(minutes: 2);

  /// Radio de «cerca» para contar reportes en la píldora de la comunidad.
  static const _radioCercano = 2000.0;

  final _mapa = MapController();
  final _distancia = const Distance();
  Timer? _temporizador;
  LatLng? _miUbicacion;
  double _hoja = _hojaInicial;
  late final Future<List<RutaEnMapa>> _troncal = context.read<TripRepository>().rutas(tipo: 'troncal');

  @override
  void initState() {
    super.initState();
    _ubicar();
    // Los reportes viven entre 30 min y 12 h y la comunidad los confirma o desmiente: se refrescan seguido.
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

  TripPoint? get _origen => _miUbicacion != null ? TripPoint.miUbicacion(_miUbicacion!) : null;

  Future<void> _buscarDestino() async {
    final destino = await PlaceSearchScreen.open(context, centroDelMapa: _miUbicacion);
    if (destino != null && mounted) PlanRouteScreen.open(context, destino: destino, origen: _origen);
  }

  void _irA(TripPoint destino) => PlanRouteScreen.open(context, destino: destino, origen: _origen);

  Future<void> _reportar() async {
    final cercanas = context.read<NearbyStopsCubit>().state;
    final rutas = cercanas is NearbyStopsLoaded ? {for (final e in cercanas.estaciones) ...e.rutas}.toList() : <String>[];
    rutas.sort();
    final creado = await mostrarHojaDeReporte(
      context,
      punto: _miUbicacion ?? _mapa.camera.center,
      esMiUbicacion: _miUbicacion != null,
      rutasCercanas: rutas,
    );
    if (creado == null || !mounted) return;
    context.read<IncidentBloc>().add(LoadIncidentsEvent());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(creado.porConfirmar
          ? 'Listo: tu reporte queda por confirmar hasta que otro viajero lo vea. Con cuenta, sale al instante.'
          : 'Listo: tu reporte ya está en el mapa para los viajeros cercanos.'),
    ));
  }

  List<Incident> _cercanos(List<Incident> todos) {
    final centro = _miUbicacion;
    if (centro == null) return todos;
    return [for (final i in todos) if (_distancia(centro, i.punto) <= _radioCercano) i];
  }

  /// Encuadra los reportes cercanos (y al viajero) en el mapa.
  void _verReportes(List<Incident> cercanos) {
    final puntos = [for (final i in cercanos) i.punto, ?_miUbicacion];
    if (puntos.isEmpty) return;
    if (puntos.length == 1) {
      _mapa.move(puntos.first, 16);
      return;
    }
    final alto = MediaQuery.sizeOf(context).height;
    _mapa.fitCamera(CameraFit.coordinates(
      coordinates: puntos,
      // En una pantalla baja (horizontal) el margen de la hoja no puede comerse todo el mapa.
      padding: EdgeInsets.fromLTRB(48, 120, 48, (alto * _hoja + 48).clamp(0, (alto - 240).clamp(0, alto))),
      maxZoom: 16.5,
      minZoom: 11,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final alto = MediaQuery.sizeOf(context).height;
    final bordeDeHoja = alto * _hoja;
    // El botón de reportar se aparta cuando la hoja sube casi a pantalla completa.
    final fabVisible = _hoja < 0.62;

    return BlocListener<IncidentBloc, IncidentState>(
      listener: (context, state) {
        if (state is IncidentsLoadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('No pudimos actualizar los reportes; el mapa puede estar incompleto.'),
            action: SnackBarAction(label: 'Reintentar', onPressed: () => context.read<IncidentBloc>().add(LoadIncidentsEvent())),
          ));
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: centroDeCartagena,
                initialZoom: 14,
                backgroundColor: fondoDelMapa(Theme.of(context).brightness),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                const CapaBahia(),
                FutureBuilder<List<RutaEnMapa>>(
                  future: _troncal,
                  builder: (context, snap) => PolylineLayer(
                    polylines: [
                      for (final ruta in snap.data ?? const <RutaEnMapa>[])
                        Polyline(
                          points: ruta.puntos,
                          strokeWidth: 4.5,
                          color: b.troncal,
                          borderStrokeWidth: 2,
                          borderColor: b.bordeDeRuta,
                        ),
                    ],
                  ),
                ),
                BlocBuilder<IncidentBloc, IncidentState>(
                  // Mientras recarga, el mapa conserva los pines anteriores.
                  buildWhen: (_, actual) => actual is IncidentsLoaded,
                  builder: (context, state) => MarkerLayer(
                    markers: state is IncidentsLoaded
                        ? [for (final i in state.incidents) marcadorDeReporte(context, i)]
                        : const [],
                  ),
                ),
                // El punto del viajero va encima de los pines: es pequeño y siempre tiene que verse.
                if (_miUbicacion != null)
                  MarkerLayer(markers: [
                    Marker(point: _miUbicacion!, width: 56, height: 56, child: const UserLocationDot(pulso: true)),
                  ]),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) => state is AuthAuthenticated
                          ? Semantics(
                              button: true,
                              label: 'Tu perfil: ${state.usuario.nombre ?? 'sin cuenta'}, nivel ${state.usuario.nivel}',
                              excludeSemantics: true,
                              child: GestureDetector(
                                onTap: () => showProfileSheet(context),
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 14, offset: Offset(0, 4))],
                                  ),
                                  child: AvatarDeViajero(usuario: state.usuario),
                                ),
                              ),
                            )
                          : MapIconButton(icon: Icons.person_outline, tooltip: 'Tu cuenta', onPressed: () => showProfileSheet(context)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Center(
                        heightFactor: 1,
                        child: BlocBuilder<IncidentBloc, IncidentState>(
                          // La recarga periódica no la hace parpadear: mientras recarga muestra lo último que supo.
                          buildWhen: (antes, actual) => actual is! IncidentsLoading || antes is IncidentInitial,
                          builder: (context, state) => _PildoraDeComunidad(
                            cercanos: state is IncidentsLoaded ? _cercanos(state.incidents) : null,
                            fallo: state is IncidentsLoadFailed,
                            onTap: _verReportes,
                            onReintentar: () => context.read<IncidentBloc>().add(LoadIncidentsEvent()),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    MapIconButton(icon: Icons.my_location, tooltip: 'Centrar en mi ubicación', color: b.acento, onPressed: _ubicar),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 96,
              bottom: bordeDeHoja + 8,
              child: const Align(alignment: Alignment.bottomLeft, child: AtribucionDelMapa()),
            ),
            Positioned(
              right: 16,
              bottom: bordeDeHoja + 16,
              child: AnimatedScale(
                scale: fabVisible ? 1 : 0.6,
                duration: Movimiento.rapido,
                child: AnimatedOpacity(
                  opacity: fabVisible ? 1 : 0,
                  duration: Movimiento.rapido,
                  child: IgnorePointer(ignoring: !fabVisible, child: _BotonDeReportar(onPressed: _reportar)),
                ),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                setState(() => _hoja = n.extent);
                return false;
              },
              child: DraggableScrollableSheet(
                initialChildSize: _hojaInicial,
                minChildSize: _hojaMinima,
                maxChildSize: _hojaMaxima,
                snap: true,
                snapSizes: const [_hojaInicial],
                builder: (context, controlador) => _HojaDeInicio(
                  controlador: controlador,
                  onBuscar: _buscarDestino,
                  onIr: _irA,
                  onReintentar: _ubicar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «12 reportes cerca»: la comunidad está activa. Al tocarla, el mapa encuadra esos reportes.
class _PildoraDeComunidad extends StatelessWidget {
  final List<Incident>? cercanos;
  final bool fallo;
  final void Function(List<Incident>) onTap;
  final VoidCallback onReintentar;

  const _PildoraDeComunidad({required this.cercanos, required this.fallo, required this.onTap, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final lista = cercanos;
    final texto = switch (lista?.length) {
      _ when fallo => 'Sin conexión · Reintentar',
      null => 'Buscando reportes…',
      0 => 'Sin reportes cerca',
      1 => '1 reporte cerca',
      final n => '$n reportes cerca',
    };
    final activo = lista != null && lista.isNotEmpty;
    final alTocar = fallo ? onReintentar : (activo ? () => onTap(lista) : null);

    return Semantics(
      button: alTocar != null,
      label: fallo
          ? 'No pudimos cargar los reportes. Toca para reintentar'
          : (activo ? '$texto. Toca para verlos en el mapa' : texto),
      excludeSemantics: true,
      child: Material(
        color: b.hoja,
        borderRadius: BorderRadius.circular(24),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PuntoEnVivo(color: activo ? b.enVivo : b.asa, latiendo: activo),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: Movimiento.rapido,
                      child: Text(
                        texto,
                        key: ValueKey(texto),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontFeatures: tabularFigures),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PuntoEnVivo extends StatefulWidget {
  final Color color;
  final bool latiendo;

  const _PuntoEnVivo({required this.color, required this.latiendo});

  @override
  State<_PuntoEnVivo> createState() => _PuntoEnVivoState();
}

class _PuntoEnVivoState extends State<_PuntoEnVivo> with SingleTickerProviderStateMixin {
  late final _latido = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  void _sincronizar() {
    if (widget.latiendo && !Movimiento.reducido(context)) {
      if (!_latido.isAnimating) _latido.repeat();
    } else {
      _latido
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar();
  }

  @override
  void didUpdateWidget(_PuntoEnVivo anterior) {
    super.didUpdateWidget(anterior);
    _sincronizar();
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 10,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _latido,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_latido.value);
              return Transform.scale(
                scale: 1 + 1.6 * t,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.8 * (1 - t))),
                ),
              );
            },
          ),
          Container(decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ],
      ),
    );
  }
}

class _BotonDeReportar extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotonDeReportar({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 64,
      child: FloatingActionButton(
        heroTag: 'reportar',
        onPressed: onPressed,
        tooltip: 'Reportar algo',
        elevation: 8,
        child: const Icon(Icons.campaign_outlined, size: 30),
      ),
    );
  }
}

/// La hoja del inicio: buscar destino, lugares guardados y estaciones cerca.
class _HojaDeInicio extends StatelessWidget {
  final ScrollController controlador;
  final VoidCallback onBuscar;
  final void Function(TripPoint destino) onIr;
  final VoidCallback onReintentar;

  const _HojaDeInicio({required this.controlador, required this.onBuscar, required this.onIr, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Material(
      color: b.hoja,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      clipBehavior: Clip.antiAlias,
      child: NearbyStopsSheet(
        controller: controlador,
        onReintentar: onReintentar,
        encabezado: [
          _CampoDeDestino(onTap: onBuscar),
          const SizedBox(height: 12),
          AccesosGuardados(onIr: onIr),
        ],
      ),
    );
  }
}

class _CampoDeDestino extends StatelessWidget {
  final VoidCallback onTap;

  const _CampoDeDestino({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final radio = BorderRadius.circular(18);
    return Semantics(
      button: true,
      label: 'Buscar destino: ¿A dónde vas?',
      excludeSemantics: true,
      child: Material(
        color: b.campo,
        borderRadius: radio,
        child: InkWell(
          onTap: onTap,
          borderRadius: radio,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.search, size: 26, color: b.acento),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('¿A dónde vas?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
