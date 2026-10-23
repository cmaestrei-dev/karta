import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../places/data/places_repository.dart';
import '../../domain/models/incident_models.dart';
import '../bloc/incident_bloc.dart';

/// Reportar un incidente: categoría, intensidad y dónde, en tres toques.
class IncidentBottomSheet extends StatefulWidget {
  const IncidentBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Permite que la hoja crezca y se desplace en pantallas bajas o en horizontal.
      isScrollControlled: true,
      builder: (context) => const IncidentBottomSheet(),
    );
  }

  @override
  State<IncidentBottomSheet> createState() => _IncidentBottomSheetState();
}

class _IncidentBottomSheetState extends State<IncidentBottomSheet> {
  String _categoria = 'Tráfico';
  int _intensidad = 3;
  LatLng? _punto;
  bool _esRespaldo = false;
  String? _nombreLugar;
  String? _errorUbicacion;

  @override
  void initState() {
    super.initState();
    _ubicar();
  }

  Future<void> _ubicar() async {
    final places = context.read<PlacesRepository>();
    setState(() {
      _punto = null;
      _errorUbicacion = null;
    });
    try {
      final ubicacion = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _punto = ubicacion.point;
        _esRespaldo = ubicacion.isFallback;
      });
      final lugar = await places.reverse(ubicacion.point);
      if (mounted) setState(() => _nombreLugar = lugar.nombre);
    } catch (e) {
      // Sin nombre del lugar igual se puede reportar; sin ubicación, no.
      if (mounted && _punto == null) setState(() => _errorUbicacion = e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _enviar() {
    final punto = _punto;
    if (punto == null) return;
    context.read<IncidentBloc>().add(SubmitIncidentEvent(
          categoria: _categoria,
          intensidad: _intensidad,
          latitud: punto.latitude,
          longitud: punto.longitude,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reportar incidente', style: texto.headlineSmall),
            const SizedBox(height: 20),
            Text('¿Qué está pasando?', style: texto.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final estilo in const [IncidentCategoryStyle.trafico, IncidentCategoryStyle.seguridad])
                  ButtonSegment(value: estilo.nombre, label: Text(estilo.nombre), icon: Icon(estilo.icono)),
              ],
              selected: {_categoria},
              onSelectionChanged: (seleccion) => setState(() => _categoria = seleccion.first),
            ),
            const SizedBox(height: 20),
            Text('¿Qué tan fuerte?', style: texto.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final nivel in etiquetasIntensidad.keys)
                  ButtonSegment(
                    value: nivel,
                    label: Text('$nivel', semanticsLabel: '$nivel, ${etiquetasIntensidad[nivel]}'),
                  ),
              ],
              selected: {_intensidad},
              onSelectionChanged: (seleccion) => setState(() => _intensidad = seleccion.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Leve', style: texto.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(etiquetasIntensidad[_intensidad]!, style: texto.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Grave', style: texto.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _UbicacionDelReporte(
              cargando: _punto == null && _errorUbicacion == null,
              error: _errorUbicacion,
              nombre: _nombreLugar,
              esRespaldo: _esRespaldo,
              onReintentar: _ubicar,
            ),
            const SizedBox(height: 20),
            BlocConsumer<IncidentBloc, IncidentState>(
              listener: (context, state) {
                if (state is IncidentSuccess) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  messenger.showSnackBar(const SnackBar(content: Text('Reporte enviado. Gracias por avisar.')));
                } else if (state is IncidentError && state.sessionExpired) {
                  Navigator.pop(context);
                  context.read<AuthBloc>().add(LogoutRequested(message: state.message));
                } else if (state is IncidentError) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
              builder: (context, state) {
                final enviando = state is IncidentSubmitting;
                return FilledButton.icon(
                  onPressed: _punto == null || enviando ? null : _enviar,
                  icon: enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(enviando ? 'Enviando…' : 'Enviar reporte'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UbicacionDelReporte extends StatelessWidget {
  final bool cargando;
  final String? error;
  final String? nombre;
  final bool esRespaldo;
  final VoidCallback onReintentar;

  const _UbicacionDelReporte({
    required this.cargando,
    required this.error,
    required this.nombre,
    required this.esRespaldo,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;

    final Widget contenido;
    if (cargando) {
      contenido = Row(children: [
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Text('Buscando tu ubicación…', style: texto.bodyMedium)),
      ]);
    } else if (error != null) {
      contenido = Row(children: [
        Icon(Icons.location_off_outlined, color: scheme.error),
        const SizedBox(width: 12),
        Expanded(child: Text(error!, style: texto.bodyMedium)),
        TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
      ]);
    } else {
      contenido = Row(children: [
        Icon(Icons.place, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            const TextSpan(text: 'Se reportará en '),
            TextSpan(text: nombre ?? 'tu ubicación actual', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (esRespaldo) const TextSpan(text: ' (ubicación de prueba)'),
          ])),
        ),
      ]);
    }
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: contenido),
      ),
    );
  }
}
