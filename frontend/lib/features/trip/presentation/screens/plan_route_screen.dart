import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/movimiento.dart';
import '../../../../core/format.dart';
import '../../../../core/location_service.dart';
import '../../../../core/map/capa_bahia.dart';
import '../../../../core/widgets/karta_map.dart';
import '../../../../core/widgets/route_capsule.dart';
import '../../../incidents/domain/models/incident_models.dart';
import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/widgets/pin_de_reporte.dart';
import '../../../places/domain/place_models.dart';
import '../../../places/presentation/screens/place_search_screen.dart';
import '../../../viaje/presentation/viaje_screen.dart';
import '../../data/preferencia_de_caminata.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_models.dart';
import '../cubit/trip_cubits.dart';
import '../widgets/tarjeta_de_opcion.dart';
import 'route_detail_screen.dart';

/// «Cómo llegar»: las formas de llegar se comparan en el mapa (cada una con su burbuja de minutos) y en
/// tarjetas abajo. Arriba, el origen y el destino, la hora de salida y el criterio para ordenarlas.
class PlanRouteScreen extends StatelessWidget {
  final TripPoint destino;
  final TripPoint? origen;

  const PlanRouteScreen({super.key, required this.destino, this.origen});

  static Future<void> open(BuildContext context, {required TripPoint destino, TripPoint? origen}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanRouteScreen(destino: destino, origen: origen),
      ),
    );
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
  static const _altoDeCabecera = 150.0;

  /// En horizontal la pantalla es baja: la hoja empieza más abajo para que quede mapa a la vista.
  double _hojaInicial(BuildContext context) => MediaQuery.sizeOf(context).aspectRatio > 1 ? 0.3 : 0.46;

  /// Pantalla ancha y baja (teléfono en horizontal, tableta): las opciones van en un panel al lado del mapa.
  static bool _apaisado(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    return tamano.aspectRatio > 1.2 && tamano.width >= 600;
  }

  @override
  void dispose() {
    _lista.dispose();
    super.dispose();
  }

  final _mapa = MapController();
  final _lista = ScrollController(); // la lista del panel lateral, en horizontal
  late TripPoint _destino = widget.destinoInicial;
  late TripPoint? _origen = widget.origenInicial;
  String? _errorOrigen;
  CriterioDeRuta _criterio = CriterioDeRuta.rapida;
  DateTime? _salida; // null: ahora
  int? _caminataMaxima; // null: lo normal, hasta 1 km
  final _preferenciaDeCaminata = PreferenciaDeCaminata();
  int _elegida = 0;
  double? _hoja; // fracción de pantalla que ocupa la hoja; null hasta que se mueve

  @override
  void initState() {
    super.initState();
    _empezar();
  }

  Future<void> _empezar() async {
    final caminata = await _preferenciaDeCaminata.leer();
    if (!mounted) return;
    _caminataMaxima = caminata;
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
    if (origen == null) return;
    setState(() => _elegida = 0);
    context.read<TripPlanCubit>()
        .plan(origen, _destino, criterio: _criterio, salida: _salida, caminataMaximaM: _caminataMaxima);
  }

  Future<void> _cambiarOrigen() async {
    final nuevo = await PlaceSearchScreen.open(
      context,
      hint: '¿Desde dónde sales?',
      permitirMiUbicacion: true,
      centroDelMapa: _origen?.punto,
    );
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

  void _elegirCriterio(CriterioDeRuta criterio) {
    if (criterio == _criterio) return;
    setState(() => _criterio = criterio);
    _planear();
  }

  /// Cuánto quiere caminar hasta la ruta y desde ella; se recuerda para la próxima vez.
  Future<void> _elegirCaminata() async {
    final eleccion = await showModalBottomSheet<int>(
      context: context,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('¿Cuánto quieres caminar?'), subtitle: Text('Hasta la ruta y desde ella')),
            for (final metros in PreferenciaDeCaminata.opciones)
              ListTile(
                leading: const Icon(Icons.directions_walk),
                title: Text('Hasta $metros m'),
                selected: _caminataMaxima == metros,
                onTap: () => Navigator.of(hoja).pop(metros),
              ),
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: const Text('Lo normal, hasta 1 km'),
              selected: _caminataMaxima == null,
              onTap: () => Navigator.of(hoja).pop(0),
            ),
          ],
        ),
      ),
    );
    if (!mounted || eleccion == null) return;
    final metros = eleccion == 0 ? null : eleccion;
    if (metros == _caminataMaxima) return;
    setState(() => _caminataMaxima = metros);
    _preferenciaDeCaminata.guardar(metros);
    _planear();
  }

  /// Salir ahora, hoy a otra hora, mañana u otro día del próximo mes: los domingos y festivos operan menos rutas.
  Future<void> _elegirSalida() async {
    final ahora = DateTime.now();
    final hoy = DateUtils.dateOnly(ahora);
    final manana = DateUtils.addDaysToDate(hoy, 1);
    final diaElegido = _salida == null ? null : DateUtils.dateOnly(_salida!);
    final eleccion = await showModalBottomSheet<String>(
      context: context,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('¿Cuándo sales?'),
              subtitle: Text('Solo cuentan las rutas que operan ese día y a esa hora'),
            ),
            ListTile(
              leading: const Icon(Icons.near_me_outlined),
              title: const Text('Salir ahora'),
              selected: _salida == null,
              onTap: () => Navigator.of(hoja).pop('ahora'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Hoy, a otra hora'),
              selected: diaElegido == hoy,
              onTap: () => Navigator.of(hoja).pop('hoy'),
            ),
            ListTile(
              leading: const Icon(Icons.wb_twilight_outlined),
              title: const Text('Mañana'),
              selected: diaElegido == manana,
              onTap: () => Navigator.of(hoja).pop('mañana'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Otro día'),
              selected: diaElegido != null && diaElegido != hoy && diaElegido != manana,
              onTap: () => Navigator.of(hoja).pop('otro'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || eleccion == null) return;
    if (eleccion == 'ahora') {
      if (_salida == null) return;
      setState(() => _salida = null);
      _planear();
      return;
    }
    var dia = eleccion == 'hoy' ? hoy : manana;
    if (eleccion == 'otro') {
      final otro = await showDatePicker(
        context: context,
        initialDate: diaElegido != null && diaElegido.isAfter(manana) ? diaElegido : DateUtils.addDaysToDate(hoy, 2),
        firstDate: hoy,
        lastDate: DateUtils.addDaysToDate(hoy, 31),
        helpText: 'Día de salida',
      );
      if (!mounted || otro == null) return;
      dia = otro;
    }
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_salida ?? ahora),
      helpText: 'Hora de salida',
      // En español el selector muestra 24 horas, pero al escribir la hora Flutter la lee en 12 si el teléfono no
      // pide 24: «08» con la hora inicial de la tarde quedaba en las 8 p. m. Así se ve y se lee igual.
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (!mounted || hora == null) return;
    final salida = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);
    if (salida.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Esa hora ya pasó: elige una más tarde u otro día.')));
      return;
    }
    setState(() => _salida = salida);
    _planear();
  }

  void _verRecorrido(RouteOption opcion) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(opcion: opcion, origen: _origen!, destino: _destino),
      ),
    );
  }

  void _encuadrar(List<RouteOption> opciones) {
    final puntos = [for (final o in opciones) ...o.puntos, ?_origen?.punto, _destino.punto];
    if (puntos.length < 2) return;
    if (_apaisado(context)) {
      // El mapa está a la derecha del panel: nada lo tapa.
      _mapa.fitCamera(
        CameraFit.coordinates(
          coordinates: puntos,
          padding: const EdgeInsets.fromLTRB(80, 48, 80, 48),
          maxZoom: 16,
          minZoom: 11,
        ),
      );
      return;
    }
    final alto = MediaQuery.sizeOf(context).height;
    var arriba = MediaQuery.paddingOf(context).top + _altoDeCabecera + 24;
    var abajo = alto * (_hoja ?? _hojaInicial(context)) + 24;
    // Si la cabecera y la hoja casi no dejan mapa (pantalla baja, en horizontal), se encuadra en lo que queda:
    // pedir más margen que pantalla hace que el mapa se aleje hasta mostrar el mundo entero.
    const minimoVisible = 120.0;
    if (alto - arriba - abajo < minimoVisible) {
      final sobra = math.max(0.0, alto - minimoVisible);
      final escala = sobra / (arriba + abajo);
      arriba *= escala;
      abajo *= escala;
    }
    _mapa.fitCamera(
      CameraFit.coordinates(
        coordinates: puntos,
        // Margen a los lados para que las burbujas de minutos (hasta ~170 px de ancho) no se corten.
        padding: EdgeInsets.fromLTRB(64, arriba, 64, abajo),
        maxZoom: 16,
        minZoom: 11, // nunca más lejos que toda Cartagena
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TripPlanCubit, TripPlanState>(
      listener: (context, state) {
        if (state is TripPlanLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _encuadrar(state.sugerencias.opciones);
          });
        }
      },
      child: Scaffold(body: _apaisado(context) ? _conPanelLateral(context) : _conHoja(context)),
    );
  }

  Widget _elMapa(BuildContext context) {
    return FlutterMap(
      mapController: _mapa,
      options: MapOptions(
        initialCenter: _destino.punto,
        initialZoom: 13,
        backgroundColor: fondoDelMapa(Theme.of(context).brightness),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        const CapaBahia(),
        BlocBuilder<TripPlanCubit, TripPlanState>(
          builder: (context, state) {
            final opciones = state is TripPlanLoaded ? state.sugerencias.opciones : const <RouteOption>[];
            return _CapasDeOpciones(
              opciones: opciones,
              elegida: _elegida.clamp(0, opciones.isEmpty ? 0 : opciones.length - 1),
            );
          },
        ),
        MarkerLayer(
          markers: [
            if (_origen != null)
              Marker(
                point: _origen!.punto,
                width: 40,
                height: 40,
                child: UserLocationDot(etiqueta: 'Origen: ${_origen!.nombre}', pulso: _origen!.esMiUbicacion),
              ),
            Marker(
              point: _destino.punto,
              width: 36,
              height: 48,
              alignment: Alignment.topCenter,
              child: MapPin(etiqueta: 'Destino: ${_destino.nombre}'),
            ),
          ],
        ),
        // Las burbujas van encima de todo: se tocan para elegir la opción.
        BlocBuilder<TripPlanCubit, TripPlanState>(
          builder: (context, state) {
            final opciones = state is TripPlanLoaded ? state.sugerencias.opciones : const <RouteOption>[];
            return _Burbujas(
              opciones: opciones,
              elegida: _elegida.clamp(0, opciones.isEmpty ? 0 : opciones.length - 1),
              onElegir: (k) => setState(() => _elegida = k),
            );
          },
        ),
      ],
    );
  }

  Widget _laCabecera(BuildContext context, {bool flotante = true}) {
    return _Cabecera(
      flotante: flotante,
      origen: _origen,
      errorOrigen: _errorOrigen,
      destino: _destino,
      criterio: _criterio,
      salida: _salida,
      caminataMaxima: _caminataMaxima,
      onCaminata: _elegirCaminata,
      onVolver: () => Navigator.of(context).pop(),
      onOrigen: _cambiarOrigen,
      onDestino: _cambiarDestino,
      onInvertir: _origen == null ? null : _invertir,
      onCriterio: _elegirCriterio,
      onSalida: _elegirSalida,
    );
  }

  /// Lo que va en la hoja o en el panel: las opciones, o por qué no las hay.
  Widget _contenido(ScrollController controlador, {bool conAsa = true}) {
    return _errorOrigen != null
        ? _Aviso(
            controlador: controlador,
            conAsa: conAsa,
            icono: Icons.location_off_outlined,
            titulo: 'No sabemos desde dónde sales',
            detalle: _errorOrigen!,
            acciones: [
              FilledButton(onPressed: _ubicarOrigen, child: const Text('Reintentar')),
              TextButton(onPressed: _cambiarOrigen, child: const Text('Elegir el origen')),
            ],
          )
        : BlocBuilder<TripPlanCubit, TripPlanState>(
            builder: (context, state) => switch (state) {
              TripPlanLoading() => _Cargando(controlador: controlador, conAsa: conAsa),
              TripPlanFailed(:final mensaje) => _Aviso(
                controlador: controlador,
                conAsa: conAsa,
                icono: Icons.wifi_off_outlined,
                titulo: 'No pudimos buscar rutas',
                detalle: mensaje,
                acciones: [FilledButton(onPressed: _planear, child: const Text('Reintentar'))],
              ),
              TripPlanLoaded(:final sugerencias) when sugerencias.opciones.isEmpty => _sinOpciones(
                controlador,
                sugerencias,
                conAsa: conAsa,
              ),
              TripPlanLoaded(:final sugerencias) => _Opciones(
                controlador: controlador,
                conAsa: conAsa,
                sugerencias: sugerencias,
                elegida: _elegida.clamp(0, sugerencias.opciones.length - 1),
                onElegir: (k) => setState(() => _elegida = k),
                onVerRecorrido: _verRecorrido,
                onOtraHora: _elegirSalida,
                onCaminata: _elegirCaminata,
              ),
            },
          );
  }

  /// En vertical: el mapa a pantalla completa, la cabecera flotando arriba y las opciones en una hoja.
  Widget _conHoja(BuildContext context) {
    final b = Bahia.de(context);
    return Stack(
      children: [
        _elMapa(context),
        SafeArea(
          child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: _laCabecera(context)),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            _hoja = n.extent;
            return false;
          },
          child: DraggableScrollableSheet(
            initialChildSize: _hojaInicial(context),
            minChildSize: 0.22,
            maxChildSize: 0.86,
            snap: true,
            snapSizes: [_hojaInicial(context)],
            builder: (context, controlador) => Material(
              color: b.hoja,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.45),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
              clipBehavior: Clip.antiAlias,
              child: _contenido(controlador),
            ),
          ),
        ),
      ],
    );
  }

  /// En horizontal: la cabecera y las opciones en un panel a la izquierda, el mapa a la derecha.
  Widget _conPanelLateral(BuildContext context) {
    final b = Bahia.de(context);
    final ancho = math.min(420.0, MediaQuery.sizeOf(context).width * 0.48);
    return Row(
      children: [
        Material(
          color: b.hoja,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.45),
          child: SizedBox(
            width: ancho,
            child: SafeArea(
              right: false,
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), child: _laCabecera(context, flotante: false)),
                  Expanded(child: _contenido(_lista, conAsa: false)),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _elMapa(context)),
      ],
    );
  }

  Widget _sinOpciones(ScrollController controlador, RouteSuggestions sugerencias, {bool conAsa = true}) {
    if (sugerencias.aviso != null && sugerencias.motivoDelAviso == 'caminata') {
      return _Aviso(
        controlador: controlador,
        conAsa: conAsa,
        icono: Icons.directions_walk,
        titulo: 'Hay que caminar un poco más',
        detalle: sugerencias.aviso!,
        acciones: [FilledButton(onPressed: _elegirCaminata, child: const Text('Cambiar la caminata'))],
      );
    }
    if (sugerencias.aviso != null) {
      return _Aviso(
        controlador: controlador,
        conAsa: conAsa,
        icono: Icons.nights_stay_outlined,
        titulo: 'Transcaribe no opera a esa hora',
        detalle: sugerencias.aviso!,
        acciones: [FilledButton(onPressed: _elegirSalida, child: const Text('Elegir otra hora'))],
      );
    }
    if (_criterio == CriterioDeRuta.sinTransbordo) {
      return _Aviso(
        controlador: controlador,
        conAsa: conAsa,
        icono: Icons.sync_alt,
        titulo: 'Ninguna ruta te lleva sin cambiar de bus',
        detalle: sugerencias.nota,
        acciones: [
          FilledButton(
            onPressed: () => _elegirCriterio(CriterioDeRuta.rapida),
            child: const Text('Ver con transbordo'),
          ),
        ],
      );
    }
    return _Aviso(
      controlador: controlador,
      conAsa: conAsa,
      icono: Icons.wrong_location_outlined,
      titulo: 'Sin rutas por aquí',
      detalle: '${sugerencias.nota} Prueba con un punto más cerca de una estación o de una vía principal.',
      acciones: [TextButton(onPressed: _cambiarDestino, child: const Text('Cambiar el destino'))],
    );
  }
}

// ---------------------------------------------------------------- cabecera

class _Cabecera extends StatelessWidget {
  /// Sobre el mapa lleva sombra; dentro del panel lateral, no.
  final bool flotante;
  final TripPoint? origen;
  final String? errorOrigen;
  final TripPoint destino;
  final CriterioDeRuta criterio;
  final DateTime? salida;
  final int? caminataMaxima;
  final VoidCallback onCaminata;
  final VoidCallback onVolver;
  final VoidCallback onOrigen;
  final VoidCallback onDestino;
  final VoidCallback? onInvertir;
  final ValueChanged<CriterioDeRuta> onCriterio;
  final VoidCallback onSalida;

  const _Cabecera({
    this.flotante = true,
    required this.origen,
    required this.errorOrigen,
    required this.destino,
    required this.criterio,
    required this.salida,
    required this.caminataMaxima,
    required this.onCaminata,
    required this.onVolver,
    required this.onOrigen,
    required this.onDestino,
    required this.onInvertir,
    required this.onCriterio,
    required this.onSalida,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final nombreOrigen = origen?.nombre ?? (errorOrigen != null ? 'Elige el origen' : 'Buscando tu ubicación…');
    return Material(
      color: b.hoja,
      elevation: flotante ? 8 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _BotonRedondo(icono: Icons.arrow_back, tooltip: 'Volver', onPressed: onVolver),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    children: [
                      _Extremo(etiqueta: 'Desde', nombre: nombreOrigen, destacado: false, onTap: onOrigen),
                      _Extremo(etiqueta: 'Hasta', nombre: destino.nombre, destacado: true, onTap: onDestino),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _BotonRedondo(icono: Icons.swap_vert, tooltip: 'Intercambiar origen y destino', onPressed: onInvertir),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                children: [
                  _Ficha(
                    icono: Icons.schedule,
                    etiqueta: salida == null ? 'Ahora' : cuandoSale(salida!),
                    elegida: false,
                    onTap: onSalida,
                    semantica: salida == null ? 'Salida: ahora. Toca para elegir otra hora' : null,
                  ),
                  const SizedBox(width: 6),
                  _Ficha(
                    icono: Icons.directions_walk,
                    etiqueta: caminataMaxima == null ? 'Hasta 1 km' : 'Hasta $caminataMaxima m',
                    elegida: caminataMaxima != null,
                    onTap: onCaminata,
                    semantica: 'Caminar ${caminataMaxima == null ? 'hasta 1 km, lo normal' : 'hasta $caminataMaxima m'}. '
                        'Toca para cambiarlo',
                  ),
                  const SizedBox(width: 6),
                  for (final c in CriterioDeRuta.values) ...[
                    _Ficha(
                      icono: switch (c) {
                        CriterioDeRuta.rapida => null,
                        CriterioDeRuta.segura => Icons.shield_outlined,
                        CriterioDeRuta.sinTransbordo => Icons.sync_alt,
                      },
                      etiqueta: c.etiqueta,
                      elegida: c == criterio,
                      onTap: () => onCriterio(c),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _BotonRedondo extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;

  const _BotonRedondo({required this.icono, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: b.campo, foregroundColor: b.texto, fixedSize: const Size(44, 44)),
      icon: Icon(icono, size: 22),
    );
  }
}

class _Extremo extends StatelessWidget {
  final String etiqueta;
  final String nombre;
  final bool destacado;
  final VoidCallback onTap;

  const _Extremo({required this.etiqueta, required this.nombre, required this.destacado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final marca = destacado
        ? Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: b.acento, borderRadius: BorderRadius.circular(2)),
          )
        : Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: b.acento, width: 3),
            ),
          );
    return Semantics(
      button: true,
      label: '$etiqueta: $nombre. Toca para cambiar',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              const SizedBox(width: 6),
              marca,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: destacado ? texto.titleMedium : texto.bodyLarge?.copyWith(color: b.textoSuave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ficha extends StatelessWidget {
  final IconData? icono;
  final String etiqueta;
  final bool elegida;
  final VoidCallback onTap;
  final String? semantica;

  const _Ficha({
    required this.icono,
    required this.etiqueta,
    required this.elegida,
    required this.onTap,
    this.semantica,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final color = elegida ? b.sobreAcento : b.texto;
    final radio = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: elegida,
      label: semantica ?? etiqueta,
      excludeSemantics: true,
      child: Material(
        color: elegida ? b.acento : b.campo,
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (icono != null) ...[Icon(icono, size: 16, color: color), const SizedBox(width: 5)],
                Text(etiqueta, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- mapa

/// Todas las opciones en el mapa: las otras en trazo fino y atenuado, la elegida encima con sus colores
/// y los reportes de su camino.
class _CapasDeOpciones extends StatelessWidget {
  final List<RouteOption> opciones;
  final int elegida;

  const _CapasDeOpciones({required this.opciones, required this.elegida});

  @override
  Widget build(BuildContext context) {
    if (opciones.isEmpty) return const SizedBox.shrink();
    final b = Bahia.de(context);
    final elegidaOpcion = opciones[elegida];
    return Stack(
      children: [
        PolylineLayer(
          polylines: [
            for (final (k, o) in opciones.indexed)
              if (k != elegida)
                Polyline(
                  points: o.puntos,
                  strokeWidth: 5,
                  color: colorDeOpcion(context, o).withValues(alpha: 0.55),
                  borderStrokeWidth: 1.5,
                  borderColor: b.bordeDeRuta.withValues(alpha: 0.6),
                ),
            for (final tramo in elegidaOpcion.tramos)
              tramo.esCaminata
                  ? Polyline(
                      points: tramo.puntos,
                      strokeWidth: 5,
                      color: b.texto,
                      pattern: const StrokePattern.dotted(),
                    )
                  : Polyline(
                      points: tramo.puntos,
                      strokeWidth: 7,
                      color: RouteCapsule.colorDe(tramo.tipoRuta),
                      borderStrokeWidth: 2.5,
                      borderColor: b.bordeDeRuta,
                    ),
          ],
        ),
        BlocBuilder<IncidentBloc, IncidentState>(
          buildWhen: (_, actual) => actual is IncidentsLoaded,
          builder: (context, state) => MarkerLayer(
            markers: [
              if (state is IncidentsLoaded)
                for (final r in reportesEnElCamino(elegidaOpcion, state.incidents)) marcadorDeReporte(context, r),
            ],
          ),
        ),
      ],
    );
  }
}

/// Una burbuja de minutos por opción, en un punto de su recorrido; al tocarla se elige esa opción.
class _Burbujas extends StatelessWidget {
  final List<RouteOption> opciones;
  final int elegida;
  final ValueChanged<int> onElegir;

  const _Burbujas({required this.opciones, required this.elegida, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    if (opciones.isEmpty) return const SizedBox.shrink();
    final burbujas = _puntosDeBurbujas(opciones);
    return MarkerLayer(
      markers: [
        for (final (k, o) in opciones.indexed)
          Marker(
            key: ValueKey('burbuja-$k-${o.tiempoTotalMin}'),
            point: burbujas[k],
            width: 170,
            height: 44,
            child: Center(
              child: _BurbujaDeTiempo(
                opcion: o,
                etiqueta: etiquetaDeOpcion(opciones, k),
                elegida: k == elegida,
                retraso: Duration(milliseconds: 120 * k),
                onTap: () => onElegir(k),
              ),
            ),
          ),
      ],
    );
  }

  /// Dónde va la burbuja de cada opción: sobre su recorrido en bus, donde se separa de las demás opciones
  /// (varias suelen compartir el corredor de la troncal) y lejos de las burbujas ya puestas.
  static List<LatLng> _puntosDeBurbujas(List<RouteOption> opciones) {
    const distancia = Distance();
    double minimaA(LatLng p, List<LatLng> puntos) {
      var minima = double.infinity;
      for (final q in puntos) {
        final d = distancia.as(LengthUnit.Meter, p, q);
        if (d < minima) minima = d;
      }
      return minima;
    }

    List<LatLng> cada(List<LatLng> puntos, int cuantos) {
      final paso = (puntos.length / cuantos).ceil().clamp(1, 1 << 20);
      return [for (var i = paso ~/ 2; i < puntos.length; i += paso) puntos[i]];
    }

    // Las distancias se miden contra el tamaño del viaje: el mapa lo encuadra entero, así que una burbuja
    // de ~170 px ocupa una fracción fija de ese tamaño, sea el viaje de 3 km o de 15 km.
    final todos = [for (final o in opciones) ...o.puntos];
    if (todos.isEmpty) return [for (final _ in opciones) const LatLng(0, 0)];
    final caja = LatLngBounds.fromPoints(todos);
    final extension = distancia.as(LengthUnit.Meter, caja.southWest, caja.northEast);
    final separacionUtil = extension * 0.08;
    final entreBurbujas = extension * 0.35;

    final puestas = <LatLng>[];
    for (final (k, opcion) in opciones.indexed) {
      final propios = opcion.buses.expand((t) => t.puntos).toList();
      final candidatos = cada(propios.isNotEmpty ? propios : opcion.puntos, 24);
      if (candidatos.isEmpty) {
        puestas.add(opcion.puntos.isNotEmpty ? opcion.puntos.first : const LatLng(0, 0));
        continue;
      }
      final otras = cada([
        for (final (j, o) in opciones.indexed)
          if (j != k) ...o.puntos,
      ], 80);
      var mejor = candidatos[candidatos.length ~/ 2];
      var mejorPuntaje = -1.0;
      for (final p in candidatos) {
        final double separada = otras.isEmpty ? separacionUtil : math.min(minimaA(p, otras), separacionUtil);
        final double lejosDeBurbujas = puestas.isEmpty ? entreBurbujas : math.min(minimaA(p, puestas), entreBurbujas);
        final puntaje = separada + 2 * lejosDeBurbujas;
        if (puntaje > mejorPuntaje) {
          mejorPuntaje = puntaje;
          mejor = p;
        }
      }
      puestas.add(mejor);
    }
    return puestas;
  }
}

class _BurbujaDeTiempo extends StatelessWidget {
  final RouteOption opcion;
  final String? etiqueta;
  final bool elegida;
  final Duration retraso;
  final VoidCallback onTap;

  const _BurbujaDeTiempo({
    required this.opcion,
    required this.etiqueta,
    required this.elegida,
    required this.retraso,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final color = colorDeOpcion(context, opcion);
    final tinta = elegida ? Bahia.tintaSobre(color) : b.texto;
    final texto = Theme.of(context).textTheme;
    return Brote(
      retraso: retraso,
      child: Semantics(
        button: true,
        selected: elegida,
        label: '${opcion.tiempoTotalMin} minutos${etiqueta != null ? ', $etiqueta' : ''}. Toca para elegir esta opción',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Movimiento.rapido,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: elegida ? color : b.hoja,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: color, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 5))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${opcion.tiempoTotalMin} min',
                  style: texto.titleSmall?.copyWith(color: tinta, fontFeatures: tabularFigures),
                ),
                if (etiqueta != null) ...[
                  const SizedBox(width: 4),
                  Text('· $etiqueta', style: texto.labelMedium?.copyWith(color: elegida ? tinta : b.textoSuave)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- hoja

class _Asa extends StatelessWidget {
  const _Asa();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(color: Bahia.de(context).asa, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

class _Opciones extends StatelessWidget {
  final ScrollController controlador;
  final bool conAsa;
  final RouteSuggestions sugerencias;
  final int elegida;
  final ValueChanged<int> onElegir;
  final ValueChanged<RouteOption> onVerRecorrido;
  final VoidCallback onOtraHora;
  final VoidCallback onCaminata;

  const _Opciones({
    required this.controlador,
    this.conAsa = true,
    required this.sugerencias,
    required this.elegida,
    required this.onElegir,
    required this.onVerRecorrido,
    required this.onOtraHora,
    required this.onCaminata,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final opciones = sugerencias.opciones;
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<IncidentBloc, IncidentState>(
            buildWhen: (_, actual) => actual is IncidentsLoaded,
            builder: (context, state) {
              final reportes = state is IncidentsLoaded ? state.incidents : const <Incident>[];
              return ListView(
                controller: controlador,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  if (conAsa) const _Asa(),
                  if (sugerencias.aviso != null) ...[
                    if (sugerencias.motivoDelAviso == 'caminata_larga')
                      _AvisoEnLinea(
                          icono: Icons.directions_walk, texto: sugerencias.aviso!, accion: 'Caminata', onAccion: onCaminata)
                    else
                      _AvisoEnLinea(texto: sugerencias.aviso!, accion: 'Otra hora', onAccion: onOtraHora),
                    const SizedBox(height: 10),
                  ],
                  for (final (k, opcion) in opciones.indexed) ...[
                    TarjetaDeOpcion(
                      opcion: opcion,
                      enElCamino: reportesEnElCamino(opcion, reportes),
                      elegida: k == elegida,
                      onTap: () => onElegir(k),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    'Ordenadas por ${sugerencias.criterio == CriterioDeRuta.segura ? 'los reportes en el camino y el tiempo' : 'tiempo y por los reportes en el camino'}. '
                    '${sugerencias.nota} ${sugerencias.fuente}',
                    style: texto.bodySmall?.copyWith(color: b.textoSuave),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: Row(
            children: [
              OutlinedButton(onPressed: () => onVerRecorrido(opciones[elegida]), child: const Text('Detalle')),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ViajeScreen.open(context, opciones[elegida]),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Iniciar viaje'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvisoEnLinea extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String accion;
  final VoidCallback onAccion;

  const _AvisoEnLinea(
      {this.icono = Icons.nights_stay_outlined, required this.texto, required this.accion, required this.onAccion});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(color: b.viaSuave, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icono, color: b.texto),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: onAccion, child: Text(accion)),
        ],
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  final ScrollController controlador;
  final bool conAsa;

  const _Cargando({required this.controlador, this.conAsa = true});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return ListView(
      controller: controlador,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (conAsa) const _Asa(),
        Semantics(liveRegion: true, label: 'Buscando formas de llegar', child: const LinearProgressIndicator()),
        const SizedBox(height: 12),
        // Siluetas de las tarjetas que vienen: la hoja no salta cuando llegan.
        for (var k = 0; k < 3; k++) ...[
          Container(
            height: 96,
            decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final ScrollController controlador;
  final bool conAsa;
  final IconData icono;
  final String titulo;
  final String detalle;
  final List<Widget> acciones;

  const _Aviso({
    required this.controlador,
    this.conAsa = true,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return ListView(
      controller: controlador,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (conAsa) const _Asa(),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: b.acentoSuave,
              child: Icon(icono, color: b.acento),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: texto.titleLarge)),
          ],
        ),
        const SizedBox(height: 10),
        Text(detalle, style: texto.bodyLarge?.copyWith(color: b.textoSuave)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: acciones),
      ],
    );
  }
}
