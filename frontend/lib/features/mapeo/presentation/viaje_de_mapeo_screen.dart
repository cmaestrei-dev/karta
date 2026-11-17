import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../../core/design/bahia.dart';
import '../../../core/location_service.dart';
import '../../../core/map/capa_bahia.dart';
import '../../../core/widgets/karta_map.dart';
import '../../../core/widgets/route_capsule.dart';
import '../../viaje/data/rastreo.dart';
import '../data/mapeo_repository.dart';
import '../domain/mapeo_models.dart';
import '../domain/viaje_de_mapeo.dart';

/// Viaje de mapeo: el viajero va en el bus y, en cada paradero de la lista oficial, toca «paró aquí» (o «no paró»).
/// Al terminar se envía todo junto: los que faltaban quedan marcados y las marcas que había se confirman o no.
class ViajeDeMapeoScreen extends StatefulWidget {
  final String ruta;
  final String tipoRuta;
  final List<LatLng> recorrido;
  final SentidoDeRuta sentido;

  const ViajeDeMapeoScreen({
    super.key,
    required this.ruta,
    required this.tipoRuta,
    required this.recorrido,
    required this.sentido,
  });

  /// El resultado, si se envió algo.
  static Future<ResultadoDelViaje?> open(BuildContext context,
          {required String ruta, required String tipoRuta, required List<LatLng> recorrido, required SentidoDeRuta sentido}) =>
      Navigator.of(context).push<ResultadoDelViaje>(MaterialPageRoute(
        builder: (_) => ViajeDeMapeoScreen(ruta: ruta, tipoRuta: tipoRuta, recorrido: recorrido, sentido: sentido),
      ));

  @override
  State<ViajeDeMapeoScreen> createState() => _ViajeDeMapeoScreenState();
}

class _ViajeDeMapeoScreenState extends State<ViajeDeMapeoScreen> {
  final _mapa = MapController();
  StreamSubscription<LatLng>? _posiciones;
  LatLng? _posicion;
  final _recientes = <(DateTime, LatLng)>[];
  int _subio = 0;
  ViajeDeMapeo? _viaje;
  bool _enviando = false;

  List<ParaderoDeRuta> get _paraderos => widget.sentido.paraderos;

  @override
  void initState() {
    super.initState();
    LocationService.getCurrentLocation().then((u) {
      if (mounted && _viaje == null) setState(() => _subio = ViajeDeMapeo.dondeSubio(_paraderos, u.point));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _posiciones?.cancel();
    super.dispose();
  }

  void _empezar() {
    setState(() => _viaje = ViajeDeMapeo.desde(_paraderos, _subio));
    _posiciones = Rastreo.paraMapear(widget.recorrido, _paraderos[_subio].punto).listen((p) {
      if (!mounted) return;
      final ahora = DateTime.now();
      _recientes
        ..add((ahora, p))
        ..removeWhere((r) => r.$1.isBefore(ahora.subtract(const Duration(seconds: 20))));
      setState(() {
        _posicion = p;
        _viaje = _viaje?.pasoPor(p);
      });
      _mapa.move(p, _mapa.camera.zoom);
    }, onError: (Object e) {
      if (mounted) _mensaje(e.toString().replaceAll('Exception: ', ''));
    });
  }

  void _mensaje(String texto) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _elegirSubida() async {
    final elegido = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (hoja) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('¿En qué paradero te subiste?', style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final (k, p) in _paraderos.indexed)
              ListTile(
                leading: Text('${p.orden}'),
                title: Text(p.nombre),
                selected: k == _subio,
                onTap: () => Navigator.of(hoja).pop(k),
              ),
          ],
        ),
      ),
    );
    if (elegido != null && mounted) setState(() => _subio = elegido);
  }

  Future<void> _terminar() async {
    final viaje = _viaje;
    if (viaje == null || viaje.paradas.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _enviando = true);
    try {
      final resultado =
          await context.read<MapeoRepository>().viajeDeMapeo(widget.ruta, widget.sentido.sentido, viaje.paradas);
      if (mounted) Navigator.of(context).pop(resultado);
    } on ApiException catch (e) {
      if (!mounted) return;
      _mensaje(e.message);
      setState(() => _enviando = false);
    }
  }

  /// Al salir con paraderos anotados, se pregunta antes de perderlos.
  Future<void> _salir() async {
    final viaje = _viaje;
    if (viaje == null || viaje.paradas.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final enviar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Envías lo que anotaste?'),
        content: Text('Anotaste ${viaje.paradas.length} ${viaje.paradas.length == 1 ? 'paradero' : 'paraderos'}. '
            'Si sales sin enviar, se pierden.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Salir sin enviar')),
          FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Enviar')),
        ],
      ),
    );
    if (!mounted || enviar == null) return;
    if (enviar) {
      await _terminar();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final color = RouteCapsule.colorDe(widget.tipoRuta);
    final viaje = _viaje;
    final anotadas = {for (final p in viaje?.paradas ?? const <ParadaDelViaje>[]) p.paradero};
    final inicio = _paraderos[_subio].punto ?? (widget.recorrido.isEmpty ? const LatLng(10.4, -75.5) : widget.recorrido.first);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _salir();
      },
      child: Scaffold(
        backgroundColor: b.hoja,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: inicio,
                initialZoom: 17,
                backgroundColor: fondoDelMapa(Theme.of(context).brightness),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                const CapaBahia(),
                PolylineLayer(polylines: [
                  Polyline(points: widget.recorrido, strokeWidth: 6, color: color, borderStrokeWidth: 2.5, borderColor: b.bordeDeRuta),
                ]),
                MarkerLayer(markers: [
                  for (final p in _paraderos)
                    if (p.punto != null)
                      Marker(
                        point: p.punto!,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(color: b.hoja, shape: BoxShape.circle, border: Border.all(color: color, width: 4)),
                        ),
                      ),
                  for (final parada in viaje?.paradas ?? const <ParadaDelViaje>[])
                    Marker(
                      point: parada.punto,
                      width: 30,
                      height: 30,
                      child: Semantics(
                        label: 'Anotaste ${_paraderos.firstWhere((p) => p.id == parada.paradero).nombre}',
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: b.reportar, shape: BoxShape.circle, border: Border.all(color: b.hoja, width: 2)),
                          child: Icon(Icons.check, size: 16, color: b.sobreReportar),
                        ),
                      ),
                    ),
                  if (_posicion != null)
                    Marker(point: _posicion!, width: 56, height: 56, child: const UserLocationDot(pulso: true)),
                ]),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MapIconButton(icon: Icons.arrow_back, tooltip: 'Volver', onPressed: _salir),
              ),
            ),
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
                    child: viaje == null
                        ? _Preparar(
                            ruta: widget.ruta,
                            tipoRuta: widget.tipoRuta,
                            sentido: widget.sentido,
                            subio: _paraderos[_subio],
                            onCambiar: _elegirSubida,
                            onEmpezar: _empezar,
                          )
                        : _Mapeando(
                            viaje: viaje,
                            anotadas: anotadas.length,
                            detenido: _posicion != null && estaDetenido(_recientes, DateTime.now()),
                            hayPosicion: _posicion != null,
                            enviando: _enviando,
                            onParo: () => setState(() => _viaje = viaje.paroAqui(_posicion!)),
                            onNoParo: () => setState(() => _viaje = viaje.noParo()),
                            onDeshacer: () => setState(() => _viaje = viaje.deshacer()),
                            onTerminar: _terminar,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preparar extends StatelessWidget {
  final String ruta;
  final String tipoRuta;
  final SentidoDeRuta sentido;
  final ParaderoDeRuta subio;
  final VoidCallback onCambiar;
  final VoidCallback onEmpezar;

  const _Preparar({
    required this.ruta,
    required this.tipoRuta,
    required this.sentido,
    required this.subio,
    required this.onCambiar,
    required this.onEmpezar,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          RouteCapsule(codigo: ruta, tipo: tipoRuta),
          const SizedBox(width: 8),
          Expanded(child: Text('Mapear desde el bus', style: texto.titleMedium)),
        ]),
        const SizedBox(height: 4),
        Text(sentido.etiqueta, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
        const SizedBox(height: 10),
        Text(
          'Ve en el bus con el teléfono a mano. Te decimos cuál paradero sigue, y cuando el bus pare en él tocas '
          '«Paró aquí». Si no para, «No paró». Al final lo envías todo junto.',
          style: texto.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Te subiste en ', style: texto.bodyMedium?.copyWith(color: b.textoSuave)),
              TextSpan(text: '«${subio.nombre}»', style: texto.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ])),
          ),
          TextButton(onPressed: onCambiar, child: const Text('Cambiar')),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: onEmpezar, icon: const Icon(Icons.directions_bus), label: const Text('Empezar')),
      ],
    );
  }
}

class _Mapeando extends StatelessWidget {
  final ViajeDeMapeo viaje;
  final int anotadas;
  final bool detenido;
  final bool hayPosicion;
  final bool enviando;
  final VoidCallback onParo;
  final VoidCallback onNoParo;
  final VoidCallback onDeshacer;
  final VoidCallback onTerminar;

  const _Mapeando({
    required this.viaje,
    required this.anotadas,
    required this.detenido,
    required this.hayPosicion,
    required this.enviando,
    required this.onParo,
    required this.onNoParo,
    required this.onDeshacer,
    required this.onTerminar,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final proximo = viaje.proximo;
    final cuenta = Text(
      '$anotadas ${anotadas == 1 ? 'anotado' : 'anotados'} · faltan ${viaje.faltan} por ubicar',
      style: texto.bodySmall?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures),
    );
    if (proximo == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Llegaste al final de la ruta', style: texto.titleMedium),
          const SizedBox(height: 4),
          cuenta,
          const SizedBox(height: 14),
          FilledButton(onPressed: enviando ? null : onTerminar, child: Text(enviando ? 'Enviando…' : 'Enviar y terminar')),
          TextButton(onPressed: onDeshacer, child: const Text('Deshacer el último')),
        ],
      );
    }
    final yaEsta = proximo.estado.ubicado;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: cuenta),
          if (detenido)
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: b.viaSuave, borderRadius: BorderRadius.circular(99)),
                child: Text('El bus está detenido', style: texto.labelMedium?.copyWith(color: b.texto)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text('Sigue el paradero ${proximo.orden}', style: texto.labelLarge?.copyWith(color: b.textoSuave)),
        Text('«${proximo.nombre}»', style: texto.titleLarge, maxLines: 2),
        if (yaEsta)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Ya está en el mapa: pasamos solos al siguiente cuando el bus llegue.',
                style: texto.bodySmall?.copyWith(color: b.textoSuave)),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: hayPosicion && !enviando ? onParo : null,
          icon: const Icon(Icons.where_to_vote_outlined),
          label: Text(hayPosicion ? 'Paró aquí' : 'Buscando tu ubicación…'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: enviando ? null : onNoParo, child: const Text('No paró'))),
          const SizedBox(width: 8),
          IconButton(
            onPressed: viaje.anteriores.isEmpty || enviando ? null : onDeshacer,
            tooltip: 'Deshacer el último',
            icon: const Icon(Icons.undo),
          ),
          TextButton(onPressed: enviando ? null : onTerminar, child: Text(enviando ? 'Enviando…' : 'Terminar')),
        ]),
      ],
    );
  }
}
