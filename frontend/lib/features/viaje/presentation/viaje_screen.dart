import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../../core/design/bahia.dart';
import '../../../core/design/movimiento.dart';
import '../../../core/format.dart';
import '../../../core/map/capa_bahia.dart';
import '../../../core/widgets/karta_map.dart';
import '../../../core/widgets/route_capsule.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../places/domain/place_models.dart';
import '../../trip/domain/trip_models.dart';
import '../../trip/presentation/screens/plan_route_screen.dart';
import '../data/avisos.dart';
import '../data/preferencia_de_compartir.dart';
import '../data/rastreo.dart';
import '../data/tiempo_real_repository.dart';
import '../domain/seguidor_de_viaje.dart';
import 'instrucciones.dart';
import 'viaje_cubit.dart';

/// El viaje activo: una instrucción grande arriba («Sube al T103», «Bájate en 3 paradas»), el mapa siguiendo al
/// viajero y abajo cuánto falta. Avanza solo con el GPS y avisa con notificaciones aunque la pantalla esté apagada.
class ViajeScreen extends StatelessWidget {
  final RouteOption opcion;

  const ViajeScreen({super.key, required this.opcion});

  /// La primera vez que se viaja en bus, antes de empezar, avisa que se comparte dónde va el bus.
  static Future<void> open(BuildContext context, RouteOption opcion) async {
    final preferencia = PreferenciaDeCompartir();
    final ruta = opcion.buses.firstOrNull?.ruta;
    final haySesion = context.read<AuthRepository>().token != null;
    if (haySesion && ruta != null && await preferencia.compartir() && !await preferencia.avisoVisto()) {
      if (!context.mounted) return;
      final empezar = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _AvisoDeCompartir(ruta: ruta),
      );
      if (empezar != true) return;
      await preferencia.marcarAvisoVisto();
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViajeScreen(opcion: opcion)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthRepository>();
    return BlocProvider(
      create: (context) => ViajeCubit(
        opcion: opcion,
        avisos: Avisos(),
        fuente: Rastreo.posiciones,
        tiempoReal: TiempoRealRepository(api: context.read<ApiClient>()),
        haySesion: () => auth.token != null,
      )..iniciar(),
      child: const _ViajeView(),
    );
  }
}

class _ViajeView extends StatefulWidget {
  const _ViajeView();

  @override
  State<_ViajeView> createState() => _ViajeViewState();
}

class _ViajeViewState extends State<_ViajeView> {
  final _mapa = MapController();

  /// El mapa sigue al viajero hasta que lo mueve con el dedo; el botón de ubicar lo vuelve a seguir.
  bool _siguiendo = true;

  Future<void> _terminar() async {
    final cubit = context.read<ViajeCubit>();
    if (cubit.state.estado.fase != Fase.llegaste) {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('¿Terminar el viaje?'),
          content: const Text('Dejaremos de seguir tu ubicación y de avisarte cuándo bajarte.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Seguir el viaje')),
            FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Terminar')),
          ],
        ),
      );
      if (seguro != true) return;
    }
    await cubit.terminar();
    if (mounted) Navigator.of(context).pop();
  }

  void _mensaje(Object texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto.toString().replaceAll('Exception: ', ''))));
  }

  Future<void> _contar(Ocupacion ocupacion) async {
    try {
      await context.read<ViajeCubit>().contarOcupacion(ocupacion);
    } catch (e) {
      if (mounted) _mensaje(e);
    }
  }

  Future<void> _pasoLleno(String ruta) async {
    try {
      await context.read<ViajeCubit>().pasoLleno();
      if (mounted) _mensaje('Gracias: quienes esperan el $ruta más adelante sabrán que viene lleno.');
    } catch (e) {
      if (mounted) _mensaje(e);
    }
  }

  /// Desde donde está, a donde iba: el planificador con las opciones de ahora.
  Future<void> _recalcular() async {
    final cubit = context.read<ViajeCubit>();
    final posicion = cubit.state.posicion;
    final ultimo = cubit.opcion.tramos.last;
    await cubit.terminar();
    if (!mounted || ultimo.puntos.isEmpty) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PlanRouteScreen(
        destino: TripPoint(nombre: cubit.destino, punto: ultimo.puntos.last),
        origen: posicion != null ? TripPoint.miUbicacion(posicion) : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final cubit = context.read<ViajeCubit>();
    final opcion = cubit.opcion;
    final inicio = opcion.puntos.isNotEmpty ? opcion.puntos.first : const LatLng(10.4236, -75.5480);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (seFue, _) {
        if (!seFue) _terminar();
      },
      child: Scaffold(
        body: BlocConsumer<ViajeCubit, ViajeState>(
          listenWhen: (antes, ahora) => ahora.posicion != antes.posicion,
          listener: (context, state) {
            if (_siguiendo && state.posicion != null) {
              _mapa.move(state.posicion!, state.estado.fase == Fase.aBordo ? 15.5 : 16.5);
            }
          },
          builder: (context, state) {
            final seguidor = cubit.seguidor;
            final bus = cubit.busQueViene;
            final llegada = state.llegada;
            final Widget? enVivo = state.estado.fase == Fase.aBordo && cubit.puedeContar
                ? _ComoVa(
                    ruta: seguidor.tramoActual.ruta!,
                    contada: state.ocupacion,
                    compartiendo: state.compartiendo,
                    onContar: _contar,
                  )
                : bus?.ruta != null && llegada != null
                    ? _EnVivo(
                        ruta: bus!.ruta!,
                        llegada: llegada,
                        onPasoLleno: state.estado.fase == Fase.esperando && cubit.haySesion()
                            ? () => _pasoLleno(bus.ruta!)
                            : null,
                      )
                    : null;
            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapa,
                  options: MapOptions(
                    initialCenter: inicio,
                    initialZoom: 16,
                    backgroundColor: fondoDelMapa(Theme.of(context).brightness),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onPositionChanged: (_, conElDedo) {
                      if (conElDedo && _siguiendo) setState(() => _siguiendo = false);
                    },
                  ),
                  children: [
                    const CapaBahia(),
                    PolylineLayer(polylines: [
                      for (final (k, tramo) in opcion.tramos.indexed)
                        tramo.esCaminata
                            ? Polyline(
                                points: tramo.puntos,
                                strokeWidth: 5,
                                color: b.texto.withValues(alpha: k < state.estado.tramo ? 0.3 : 1),
                                pattern: const StrokePattern.dotted(),
                              )
                            : Polyline(
                                points: tramo.puntos,
                                strokeWidth: 7,
                                color: RouteCapsule.colorDe(tramo.tipoRuta).withValues(alpha: k < state.estado.tramo ? 0.35 : 1),
                                borderStrokeWidth: 2.5,
                                borderColor: b.bordeDeRuta,
                              ),
                    ]),
                    MarkerLayer(markers: [
                      for (final tramo in opcion.buses)
                        for (final parada in tramo.paradas)
                          Marker(
                            point: parada.punto,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: b.hoja,
                                shape: BoxShape.circle,
                                border: Border.all(color: RouteCapsule.colorDe(tramo.tipoRuta), width: 3.5),
                              ),
                            ),
                          ),
                      if (opcion.tramos.last.puntos.isNotEmpty)
                        Marker(
                          point: opcion.tramos.last.puntos.last,
                          width: 36,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: MapPin(etiqueta: 'Destino: ${cubit.destino}'),
                        ),
                      if (state.posicion != null)
                        Marker(
                          point: state.posicion!,
                          width: 56,
                          height: 56,
                          child: const UserLocationDot(pulso: true),
                        ),
                    ]),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _Franja(seguidor: seguidor, destino: cubit.destino, error: state.error),
                ),
                // Lo que flota sobre el mapa va encima de la barra de abajo, que crece con lo que saben los viajeros.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_siguiendo)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16, bottom: 12),
                            child: MapIconButton(
                              icon: Icons.my_location,
                              tooltip: 'Seguir mi ubicación',
                              color: b.acento,
                              onPressed: () {
                                setState(() => _siguiendo = true);
                                if (state.posicion != null) _mapa.move(state.posicion!, 16);
                              },
                            ),
                          ),
                        ),
                      if (state.estado.desviado)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _Desvio(onRecalcular: _recalcular),
                        ),
                      state.estado.fase == Fase.llegaste
                          ? _Llegaste(destino: cubit.destino, onTerminar: _terminar)
                          : _BarraDeLlegada(seguidor: seguidor, arriba: enVivo, onTerminar: _terminar),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// La instrucción grande, en el acento, como un letrero de la vía.
class _Franja extends StatelessWidget {
  final SeguidorDeViaje seguidor;
  final String destino;
  final String? error;

  const _Franja({required this.seguidor, required this.destino, required this.error});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final instruccion = instruccionDe(seguidor, destino);
    final avance = avanceEnParadas(seguidor);
    final fondo = error != null ? b.seguridad : b.acento;
    final tinta = Bahia.tintaSobre(fondo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: fondo,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Semantics(
                liveRegion: true,
                label: error ?? '${instruccion.titulo}. ${instruccion.detalle}',
                excludeSemantics: true,
                child: AnimatedSwitcher(
                  duration: Movimiento.reducido(context) ? Duration.zero : Movimiento.normal,
                  child: Column(
                    key: ValueKey('${instruccion.titulo}-${error ?? ''}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: tinta.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(error != null ? Icons.location_off_outlined : instruccion.icono, size: 32, color: tinta),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  error != null ? 'No podemos seguir tu ubicación' : instruccion.titulo,
                                  style: texto.headlineMedium?.copyWith(color: tinta, height: 1.05),
                                ),
                                const SizedBox(height: 2),
                                Text(error ?? instruccion.detalle, style: texto.titleSmall?.copyWith(color: tinta)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (avance != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            for (var k = 0; k < avance.total; k++) ...[
                              if (k > 0) const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: k < avance.pasadas ? tinta : tinta.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (simularViaje) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tinta.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Simulación: el viaje avanza solo, sin GPS',
                              style: texto.labelMedium?.copyWith(color: tinta)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (instruccion.luego != null && error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Material(
              color: b.hoja,
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Luego ', style: TextStyle(color: b.textoSuave)),
                    TextSpan(text: instruccion.luego),
                  ]),
                  style: texto.titleSmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Desvio extends StatelessWidget {
  final VoidCallback onRecalcular;

  const _Desvio({required this.onRecalcular});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Material(
      color: b.hoja,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Icon(Icons.alt_route, color: b.via),
            const SizedBox(width: 10),
            Expanded(child: Text('Te saliste del recorrido', style: Theme.of(context).textTheme.titleSmall)),
            FilledButton(onPressed: onRecalcular, child: const Text('Otra ruta')),
          ],
        ),
      ),
    );
  }
}

/// Cuánto falta: minutos grandes, la hora de llegada y la distancia; y el botón para terminar. Encima, [arriba]:
/// lo que saben los viajeros del bus (cuándo llega, cómo va).
class _BarraDeLlegada extends StatelessWidget {
  final SeguidorDeViaje seguidor;
  final Widget? arriba;
  final VoidCallback onTerminar;

  const _BarraDeLlegada({required this.seguidor, required this.arriba, required this.onTerminar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final estado = seguidor.estado;
    final llegada = DateTime.now().add(Duration(minutes: estado.minutosRestantes));
    final hora = llegada.hour % 12 == 0 ? 12 : llegada.hour % 12;
    final restante = estado.faltaDelTramoM +
        seguidor.opcion.tramos.skip(estado.tramo + 1).fold<double>(0, (suma, t) => suma + t.distanciaM);
    final cuanto = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Faltan ${estado.minutosRestantes} minutos. Llegas a las $hora:${llegada.minute.toString().padLeft(2, '0')}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(minutos(estado.minutosRestantes),
                      style: texto.displaySmall?.copyWith(fontSize: 32, height: 1, fontFeatures: tabularFigures)),
                  const SizedBox(height: 4),
                  Text(
                    'Llegas $hora:${llegada.minute.toString().padLeft(2, '0')} ${llegada.hour < 12 ? 'a. m.' : 'p. m.'}'
                    ' · ${metros(restante)}',
                    style: texto.bodyMedium?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Terminar el viaje',
            onPressed: onTerminar,
            style: IconButton.styleFrom(backgroundColor: b.campo, fixedSize: const Size(52, 52)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
    return Material(
      color: b.hoja,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: Movimiento.reducido(context) ? Duration.zero : Movimiento.normal,
              curve: Movimiento.suave,
              alignment: Alignment.topCenter,
              child: arriba == null
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [arriba!, Divider(height: 1, indent: 20, endIndent: 20, color: b.divisor)],
                    ),
            ),
            cuanto,
          ],
        ),
      ),
    );
  }
}

/// Mientras se camina a la parada o se espera: cuándo llega el bus según quienes lo vieron.
class _EnVivo extends StatelessWidget {
  final String ruta;
  final Llegada llegada;

  /// Esperando: el bus pasó lleno y no se pudo subir.
  final VoidCallback? onPasoLleno;

  const _EnVivo({required this.ruta, required this.llegada, required this.onPasoLleno});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final sabe = llegada.minutos != null;
    final (:titulo, :detalle) = textoDeLlegada(ruta, llegada);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, onPasoLleno != null ? 8 : 20, 12),
      child: Row(
        children: [
          Icon(sabe ? Icons.sensors : Icons.sensors_off_outlined, size: 22, color: sabe ? b.enVivo : b.textoSuave),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: '$titulo, $detalle',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: texto.titleSmall),
                  Text(detalle, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                ],
              ),
            ),
          ),
          if (onPasoLleno != null) TextButton(onPressed: onPasoLleno, child: const Text('Pasó lleno')),
        ],
      ),
    );
  }
}

/// A bordo: «¿Cómo va el T103?» en un toque y, si comparte dónde va el bus, una línea que lo dice.
class _ComoVa extends StatelessWidget {
  final String ruta;
  final Ocupacion? contada;
  final bool compartiendo;
  final ValueChanged<Ocupacion> onContar;

  const _ComoVa({required this.ruta, required this.contada, required this.compartiendo, required this.onContar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            contada == null ? '¿Cómo va el $ruta?' : 'Gracias: lo verán quienes esperan el $ruta',
            style: texto.titleSmall,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                for (final ocupacion in Ocupacion.values) ...[
                  if (ocupacion.index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Pildora(
                      etiqueta: ocupacion.etiqueta,
                      elegida: ocupacion == contada,
                      onTap: () => onContar(ocupacion),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (compartiendo)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.sensors, size: 18, color: b.enVivo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Compartiendo dónde va el $ruta, sin tu nombre',
                        style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  final String etiqueta;
  final bool elegida;
  final VoidCallback onTap;

  const _Pildora({required this.etiqueta, required this.elegida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Semantics(
      button: true,
      selected: elegida,
      child: Material(
        color: elegida ? b.acento : b.campo,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: elegida ? b.sobreAcento : b.texto),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Llegaste extends StatelessWidget {
  final String destino;
  final VoidCallback onTerminar;

  const _Llegaste({required this.destino, required this.onTerminar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Material(
      color: b.hoja,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Brote(child: Icon(Icons.check_circle, size: 56, color: b.enVivo)),
              const SizedBox(height: 8),
              Text('Llegaste a $destino', textAlign: TextAlign.center, style: texto.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '¿Viste algo en el camino? Repórtalo desde el inicio: le sirve a quien viene detrás.',
                textAlign: TextAlign.center,
                style: texto.bodyMedium?.copyWith(color: b.textoSuave),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onTerminar, child: const Text('Terminar')),
            ],
          ),
        ),
      ),
    );
  }
}

/// El aviso del primer viaje en bus: qué se comparte y cómo apagarlo. Empezar el viaje desde aquí es la autorización
/// (Ley 1581: previa, expresa e informada); cerrarlo no empieza el viaje.
class _AvisoDeCompartir extends StatelessWidget {
  final String ruta;

  const _AvisoDeCompartir({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    Widget punto(IconData icono, String linea) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20, color: b.textoSuave),
              const SizedBox(width: 12),
              Expanded(child: Text(linea, style: texto.bodyMedium)),
            ],
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Brote(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: b.enVivo.withValues(alpha: 0.16), shape: BoxShape.circle),
                  child: Icon(Icons.sensors, size: 30, color: b.enVivo),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Tu viaje ayuda a quien espera', style: texto.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Mientras vas en el $ruta, Karta comparte dónde va el bus. Así quienes lo esperan saben cuándo llega.',
              style: texto.bodyLarge,
            ),
            punto(Icons.person_off_outlined, 'Sin tu nombre: el viaje lleva un código al azar.'),
            punto(Icons.directions_bus_outlined, 'Solo el tramo en bus, nunca la caminata desde o hasta tu casa.'),
            punto(Icons.timer_outlined, 'Se borra 5 minutos después de la última posición.'),
            const SizedBox(height: 14),
            Text('Puedes apagarlo cuando quieras en Perfil › Privacidad.',
                style: texto.bodySmall?.copyWith(color: b.textoSuave)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Entendido, empezar viaje'),
            ),
          ],
        ),
      ),
    );
  }
}
