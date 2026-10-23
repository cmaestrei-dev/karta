import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/karta_theme.dart';
import '../../../../core/widgets/karta_map.dart';
import '../../../../core/widgets/plaque.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../../core/widgets/route_capsule.dart';
import '../../../incidents/domain/models/incident_models.dart';
import '../../../incidents/presentation/bloc/incident_bloc.dart';
import '../../../incidents/presentation/widgets/incident_marker.dart';
import '../../../places/domain/place_models.dart';
import '../../domain/trip_models.dart';

/// Detalle de una forma de llegar: el recorrido dibujado en el mapa y los tramos en secuencia
/// (el tramo en bus en su placa), con el origen y el destino como palabras guía en la cabecera.
class RouteDetailScreen extends StatefulWidget {
  final RouteOption opcion;
  final TripPoint origen;
  final TripPoint destino;

  const RouteDetailScreen({super.key, required this.opcion, required this.origen, required this.destino});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> with SingleTickerProviderStateMixin {
  static const _hojaInicial = 0.42;

  late final AnimationController _trazo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _avance = CurvedAnimation(parent: _trazo, curve: Curves.easeOutCubic);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El recorrido se dibuja de origen a destino una sola vez; sin animaciones del sistema, aparece completo.
    if (MediaQuery.disableAnimationsOf(context)) {
      _trazo.value = 1;
    } else if (!_trazo.isAnimating && _trazo.value == 0) {
      _trazo.forward();
    }
  }

  @override
  void dispose() {
    _trazo.dispose();
    super.dispose();
  }

  List<Polyline> _lineas(BuildContext context, double avance) {
    final tinta = Theme.of(context).colorScheme.onSurface;
    final total = widget.opcion.tramos.fold<int>(0, (n, t) => n + t.puntos.length);
    var visibles = (total * avance).ceil();
    final lineas = <Polyline>[];
    for (final tramo in widget.opcion.tramos) {
      final cuantos = visibles.clamp(0, tramo.puntos.length);
      visibles -= cuantos;
      if (cuantos < 2) continue;
      final puntos = tramo.puntos.sublist(0, cuantos);
      lineas.add(tramo.esCaminata
          ? Polyline(points: puntos, color: tinta, strokeWidth: 5, pattern: const StrokePattern.dotted())
          : Polyline(
              points: puntos,
              color: RouteCapsule.colorDe(tramo.tipoRuta),
              strokeWidth: 6,
              borderColor: Colors.white,
              borderStrokeWidth: 2.5,
            ));
    }
    return lineas;
  }

  /// Paradas de subida y bajada. Si el origen queda a menos de 100 m de la subida, el punto del
  /// origen se funde con la parada para que no se tapen entre sí.
  List<Marker> _paradas({required bool origenEnSubida}) {
    final bus = widget.opcion.bus;
    if (bus == null || bus.puntos.isEmpty) return [];
    final parada = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: RouteCapsule.colorDe(bus.tipoRuta),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.directions_bus, size: 16, color: Colors.white),
    );
    final subida = origenEnSubida
        ? Stack(children: [
            Positioned(right: 0, top: 0, child: parada),
            Positioned(
              left: 0,
              bottom: 0,
              child: SizedBox(width: 24, height: 24, child: UserLocationDot(etiqueta: 'Origen: ${widget.origen.nombre}')),
            ),
          ])
        : parada;
    return [
      Marker(point: bus.puntos.first, width: origenEnSubida ? 44 : 28, height: origenEnSubida ? 44 : 28, child: subida),
      Marker(point: bus.puntos.last, width: 28, height: 28, child: parada),
    ];
  }

  /// Los incidentes que cuentan en el riesgo de esta opción (a menos de 500 m del recorrido, el mismo
  /// radio del backend) se ven completos; los demás quedan atenuados.
  /// Un incidente encima de la parada de subida o de bajada se corre arriba a la izquierda: los dos
  /// tienen que verse, porque la parada es a donde el viajero debe caminar.
  List<Marker> _incidentes(BuildContext context, List<Incident> incidentes) {
    final recorrido = widget.opcion.puntos;
    final paradas = [?widget.opcion.bus?.puntos.firstOrNull, ?widget.opcion.bus?.puntos.lastOrNull];
    const distancia = Distance();
    return [
      for (final i in incidentes)
        incidentMarker(
          context,
          i,
          atenuado: _distanciaALinea(LatLng(i.latitud, i.longitud), recorrido) > _radioDeRiesgoM,
          alineacion: paradas.any((p) => distancia.as(LengthUnit.Meter, p, LatLng(i.latitud, i.longitud)) < 60)
              ? const Alignment(-1.5, -1.5)
              : Alignment.center,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alto = MediaQuery.sizeOf(context).height;
    final puntos = widget.opcion.puntos;
    final subida = widget.opcion.bus?.puntos.firstOrNull;
    final origenEnSubida =
        subida != null && const Distance().as(LengthUnit.Meter, widget.origen.punto, subida) < 100;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(puntos.length > 1 ? puntos : [widget.origen.punto, widget.destino.punto]),
                padding: EdgeInsets.fromLTRB(40, 96, 40, alto * _hojaInicial + 32),
              ),
            ),
            // Orden de capas: recorrido, paradas y extremos, y encima los incidentes, que explican el riesgo.
            children: [
              const KartaTiles(),
              AnimatedBuilder(
                animation: _avance,
                builder: (context, _) => PolylineLayer(polylines: _lineas(context, _avance.value)),
              ),
              MarkerLayer(markers: [
                ..._paradas(origenEnSubida: origenEnSubida),
                if (!origenEnSubida)
                  Marker(
                    point: widget.origen.punto,
                    width: 40,
                    height: 40,
                    child: UserLocationDot(etiqueta: 'Origen: ${widget.origen.nombre}'),
                  ),
                Marker(
                  point: widget.destino.punto,
                  width: 36,
                  height: 48,
                  alignment: Alignment.topCenter,
                  child: MapPin(etiqueta: 'Destino: ${widget.destino.nombre}'),
                ),
              ]),
              BlocBuilder<IncidentBloc, IncidentState>(
                buildWhen: (_, actual) => actual is IncidentsLoaded,
                builder: (context, state) => MarkerLayer(
                  markers: state is IncidentsLoaded ? _incidentes(context, state.incidents) : [],
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MapIconButton(icon: Icons.arrow_back, tooltip: 'Volver', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  const OsmAttribution(),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: _hojaInicial,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            snap: true,
            builder: (context, controlador) => Material(
              color: scheme.surface,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.4),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: ListView(
                controller: controlador,
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  const _Asa(),
                  _Cabecera(opcion: widget.opcion, origen: widget.origen, destino: widget.destino),
                  const SizedBox(height: 20),
                  for (final tramo in widget.opcion.tramos) _FilaDeTramo(tramo: tramo),
                  _Llegada(destino: widget.destino),
                  const SizedBox(height: 16),
                  Text(
                    'Tiempos estimados con velocidades promedio; las caminatas se dibujan en línea recta. '
                    'Rutas de Transcaribe: © colaboradores de OpenStreetMap (ODbL).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Asa extends StatelessWidget {
  const _Asa();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  final RouteOption opcion;
  final TripPoint origen;
  final TripPoint destino;

  const _Cabecera({required this.opcion, required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${origen.nombre} → ${destino.nombre}', style: texto.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: minutos(opcion.tiempoTotalMin), style: texto.headlineSmall?.copyWith(fontFeatures: tabularFigures)),
            TextSpan(
              text: '  aprox. · ${metros(opcion.distanciaCaminataM)} a pie en total',
              style: texto.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabularFigures),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        RiskBadge(nivel: opcion.riesgo.nivel, totalIncidentes: opcion.riesgo.totalIncidentes),
      ],
    );
  }
}

/// Un tramo con su riel a la izquierda: punteado para caminar, continuo y del color de la ruta para el bus.
class _FilaDeTramo extends StatelessWidget {
  final Leg tramo;

  const _FilaDeTramo({required this.tramo});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colorRuta = RouteCapsule.colorDe(tramo.tipoRuta);
    final secundario = texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    final contenido = tramo.esCaminata
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Camina ${minutos(tramo.duracionMin)} · ${metros(tramo.distanciaM)}',
                  style: texto.titleSmall?.copyWith(fontFeatures: tabularFigures)),
              Text('hasta ${tramo.hasta}', style: secundario),
            ],
          )
        // El tramo en bus es la placa del recorrido: la ruta, dónde subir y dónde bajar.
        : Plaque(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  RouteCapsule(codigo: tramo.ruta ?? '', tipo: tramo.tipoRuta, grande: true),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tramo.nombreRuta ?? '', style: texto.bodySmall, maxLines: 2)),
                ]),
                const SizedBox(height: 8),
                Text('Sube en ${tramo.desde}', style: texto.titleMedium?.copyWith(color: scheme.primary)),
                Text('Espera aprox. ${minutos(tramo.esperaMin)} · ${minutos(tramo.duracionMin)} de viaje',
                    style: secundario?.copyWith(fontFeatures: tabularFigures)),
                const SizedBox(height: 4),
                Text('Bájate en ${tramo.hasta}', style: texto.titleMedium?.copyWith(color: scheme.primary)),
              ],
            ),
          );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _Nodo(
                  icono: tramo.esCaminata ? Icons.directions_walk : Icons.directions_bus,
                  relleno: tramo.esCaminata ? null : colorRuta,
                ),
                Expanded(
                  child: tramo.esCaminata
                      ? CustomPaint(painter: _RielPunteado(scheme.onSurface), child: const SizedBox(width: 4))
                      : Container(width: 4, color: colorRuta),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 4, bottom: 20), child: contenido)),
        ],
      ),
    );
  }
}

class _Llegada extends StatelessWidget {
  final TripPoint destino;

  const _Llegada({required this.destino});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 40, child: _Nodo(icono: Icons.place)),
        const SizedBox(width: 12),
        Expanded(child: Text('Llegas a ${destino.nombre}', style: Theme.of(context).textTheme.titleSmall)),
      ],
    );
  }
}

class _Nodo extends StatelessWidget {
  final IconData icono;
  final Color? relleno;

  const _Nodo({required this.icono, this.relleno});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: relleno ?? scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: relleno ?? scheme.onSurface, width: 2),
      ),
      child: Icon(icono, size: 18, color: relleno != null ? Colors.white : scheme.onSurface),
    );
  }
}

class _RielPunteado extends CustomPainter {
  final Color color;

  _RielPunteado(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..color = color;
    for (var y = 6.0; y < size.height; y += 10) {
      canvas.drawCircle(Offset(size.width / 2, y), 2, pincel);
    }
  }

  @override
  bool shouldRepaint(_RielPunteado anterior) => anterior.color != color;
}

/// Radio alrededor del recorrido en el que un incidente cuenta para su riesgo (RADIO_BUSQUEDA_M del backend).
const _radioDeRiesgoM = 500;

/// Distancia aproximada en metros de un punto a una polilínea, en una proyección local plana:
/// a la escala de una ciudad el error es despreciable.
double _distanciaALinea(LatLng punto, List<LatLng> linea) {
  if (linea.isEmpty) return double.infinity;
  const metrosPorGradoLat = 110540.0;
  final metrosPorGradoLon = 111320.0 * math.cos(punto.latitude * math.pi / 180);
  Offset local(LatLng q) => Offset(
        (q.longitude - punto.longitude) * metrosPorGradoLon,
        (q.latitude - punto.latitude) * metrosPorGradoLat,
      );
  var minima = local(linea.first).distance;
  for (var k = 0; k + 1 < linea.length; k++) {
    final a = local(linea[k]);
    final ab = local(linea[k + 1]) - a;
    final largo2 = ab.distanceSquared;
    final t = largo2 == 0 ? 0.0 : (-(a.dx * ab.dx + a.dy * ab.dy) / largo2).clamp(0.0, 1.0);
    minima = math.min(minima, (a + ab * t).distance);
  }
  return minima;
}
