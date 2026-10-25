import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../../core/design/bahia.dart';
import '../../../core/map/capa_bahia.dart';
import '../../../core/widgets/karta_map.dart';
import '../../../core/widgets/route_capsule.dart';
import '../data/mapeo_repository.dart';
import '../domain/mapeo_models.dart';

/// Marcar un paradero sin ubicar: se mueve el mapa hasta él. Ayudan el recorrido de la ruta, los paraderos vecinos
/// ya ubicados y las pistas (lugares donde varios viajeros se subieron).
class MarcarParaderoScreen extends StatefulWidget {
  final String ruta;
  final String tipoRuta;
  final List<LatLng> recorrido;
  final ParaderoDeRuta paradero;
  final ({ParaderoDeRuta? antes, ParaderoDeRuta? despues}) vecinos;
  final List<PistaDeSubida> pistas;

  const MarcarParaderoScreen({
    super.key,
    required this.ruta,
    required this.tipoRuta,
    required this.recorrido,
    required this.paradero,
    required this.vecinos,
    required this.pistas,
  });

  /// true si quedó marcado.
  static Future<bool?> open(
    BuildContext context, {
    required String ruta,
    required String tipoRuta,
    required List<LatLng> recorrido,
    required ParaderoDeRuta paradero,
    required ({ParaderoDeRuta? antes, ParaderoDeRuta? despues}) vecinos,
    required List<PistaDeSubida> pistas,
  }) =>
      Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => MarcarParaderoScreen(
            ruta: ruta, tipoRuta: tipoRuta, recorrido: recorrido, paradero: paradero, vecinos: vecinos, pistas: pistas),
      ));

  /// Dónde empezar: entre los vecinos ya ubicados, o junto al que haya, o en la mitad del recorrido.
  static LatLng inicio(({ParaderoDeRuta? antes, ParaderoDeRuta? despues}) vecinos, List<LatLng> recorrido) {
    final a = vecinos.antes?.punto, d = vecinos.despues?.punto;
    if (a != null && d != null) return LatLng((a.latitude + d.latitude) / 2, (a.longitude + d.longitude) / 2);
    return a ?? d ?? (recorrido.isEmpty ? const LatLng(10.4, -75.5) : recorrido[recorrido.length ~/ 2]);
  }

  @override
  State<MarcarParaderoScreen> createState() => _MarcarParaderoScreenState();
}

class _MarcarParaderoScreenState extends State<MarcarParaderoScreen> {
  final _mapa = MapController();
  late LatLng _centro = MarcarParaderoScreen.inicio(widget.vecinos, widget.recorrido);
  bool _enviando = false;

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      await context.read<MapeoRepository>().marcar(widget.paradero.id, _centro);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final color = RouteCapsule.colorDe(widget.tipoRuta);
    final antes = widget.vecinos.antes, despues = widget.vecinos.despues;
    final entre = [
      if (antes != null) 'después de «${antes.nombre}»',
      if (despues != null) 'antes de «${despues.nombre}»',
    ].join(' y ');
    return Scaffold(
      backgroundColor: b.hoja,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _centro,
              initialZoom: 17,
              backgroundColor: fondoDelMapa(Theme.of(context).brightness),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onPositionChanged: (camara, _) => _centro = camara.center,
            ),
            children: [
              const CapaBahia(),
              PolylineLayer(polylines: [
                Polyline(points: widget.recorrido, strokeWidth: 6, color: color, borderStrokeWidth: 2.5, borderColor: b.bordeDeRuta),
              ]),
              MarkerLayer(markers: [
                for (final pista in widget.pistas)
                  Marker(
                    point: pista.punto,
                    width: 34,
                    height: 34,
                    child: Semantics(
                      label: '${pista.subidas} viajeros se subieron aquí',
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: b.via.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: b.hoja, width: 2),
                        ),
                        child: Text('${pista.subidas}',
                            style: texto.labelSmall?.copyWith(color: b.sobreReportar, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                for (final vecino in [?antes, ?despues])
                  Marker(
                    point: vecino.punto!,
                    width: 22,
                    height: 22,
                    child: Semantics(
                      label: 'Paradero ${vecino.nombre}',
                      child: Container(
                        decoration: BoxDecoration(color: b.hoja, shape: BoxShape.circle, border: Border.all(color: color, width: 5)),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
          // El punto que se marca es el centro del mapa.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: b.reportar, shadows: const [Shadow(blurRadius: 8, color: Colors.black45)]),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MapIconButton(icon: Icons.arrow_back, tooltip: 'Volver', onPressed: () => Navigator.of(context).pop()),
            ),
          ),
          const Positioned(left: 8, bottom: 236, child: AtribucionDelMapa()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: b.hoja,
              elevation: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        RouteCapsule(codigo: widget.ruta, tipo: widget.tipoRuta),
                        const SizedBox(width: 8),
                        Expanded(child: Text('¿Dónde está «${widget.paradero.nombre}»?', style: texto.titleMedium, maxLines: 2)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        'Mueve el mapa hasta el paradero, sobre la calle por donde pasa la ruta'
                        '${entre.isEmpty ? '' : ': $entre'}.'
                        '${widget.pistas.isEmpty ? '' : ' Los círculos amarillos son lugares donde varios viajeros se subieron.'}',
                        style: texto.bodySmall?.copyWith(color: b.textoSuave),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _enviando ? null : _enviar,
                        icon: const Icon(Icons.where_to_vote_outlined),
                        label: Text(_enviando ? 'Enviando…' : 'El paradero está aquí'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un mapa pequeño, quieto, con un punto: para confirmar una marca.
class MapaDeUnPunto extends StatelessWidget {
  final LatLng punto;

  const MapaDeUnPunto({super.key, required this.punto});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: punto,
          initialZoom: 17,
          backgroundColor: fondoDelMapa(Theme.of(context).brightness),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
        ),
        children: [
          const CapaBahia(),
          MarkerLayer(markers: [
            Marker(point: punto, width: 40, height: 40, alignment: Alignment.topCenter,
                child: Icon(Icons.location_on, size: 40, color: b.reportar)),
          ]),
        ],
      ),
    );
  }
}
