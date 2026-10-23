import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/karta_map.dart';
import '../../data/places_repository.dart';
import '../../domain/place_models.dart';

/// Elegir un punto moviendo el mapa bajo un alfiler fijo; muestra cómo se llama el lugar.
class PickOnMapScreen extends StatefulWidget {
  final LatLng? centroInicial;

  const PickOnMapScreen({super.key, this.centroInicial});

  @override
  State<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends State<PickOnMapScreen> {
  final _mapa = MapController();
  Timer? _espera;
  late LatLng _centro = widget.centroInicial ?? centroDeCartagena;
  Place? _lugar;
  String? _error;
  bool _cargando = true;
  int _peticion = 0;

  @override
  void initState() {
    super.initState();
    _nombrar(_centro);
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  void _alMoverse(MapCamera camara, bool porGesto) {
    _centro = camara.center;
    _espera?.cancel();
    setState(() => _cargando = true);
    _espera = Timer(const Duration(milliseconds: 450), () => _nombrar(_centro));
  }

  Future<void> _nombrar(LatLng punto) async {
    final peticion = ++_peticion;
    try {
      final lugar = await context.read<PlacesRepository>().reverse(punto);
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _lugar = lugar;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _lugar = null;
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(initialCenter: _centro, initialZoom: 16, onPositionChanged: _alMoverse),
            children: const [KartaTiles()],
          ),
          // Alfiler fijo en el centro: su punta marca el punto elegido.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: const MapPin(),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MapIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: scheme.surface,
              elevation: 8,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _cargando ? 'Buscando el nombre del lugar…' : _error ?? _lugar?.nombre ?? '',
                          style: texto.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Mueve el mapa para ajustar el punto', style: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _cargando || _lugar == null
                            ? null
                            : () => Navigator.of(context).pop(TripPoint(nombre: _lugar!.nombre, punto: _centro)),
                        child: const Text('Usar este punto'),
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
