import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/bahia.dart';
import '../../../../core/design/movimiento.dart';
import '../../../../core/format.dart';
import '../../../../core/location_service.dart';
import '../../../../core/widgets/plaque.dart';
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

  void _borrar() {
    _controller.clear();
    setState(() {});
    context.read<PlaceSearchCubit>().onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);

    return Scaffold(
      backgroundColor: b.hoja,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: b.campo, fixedSize: const Size(48, 48)),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CampoDeBusqueda(
                      controller: _controller,
                      hint: widget.hint,
                      onChanged: (texto) {
                        setState(() {});
                        context.read<PlaceSearchCubit>().onQueryChanged(texto);
                      },
                      onBorrar: _borrar,
                    ),
                  ),
                ],
              ),
            ),
            BlocBuilder<PlaceSearchCubit, PlaceSearchState>(
              builder: (context, state) => SizedBox(
                height: 3,
                child: state.status == PlaceSearchStatus.buscando || _ubicando
                    ? const LinearProgressIndicator(minHeight: 3)
                    : null,
              ),
            ),
            Expanded(
              child: BlocBuilder<PlaceSearchCubit, PlaceSearchState>(
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
                        detalle: 'Prueba con un barrio, una estación de Transcaribe o un sitio conocido, o marca el '
                            'punto en el mapa.',
                        accion: FilledButton.icon(
                          onPressed: _elegirEnMapa,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Elegir en el mapa'),
                        ),
                      ),
                    PlaceSearchStatus.error => _Mensaje(
                        titulo: 'No pudimos buscar',
                        detalle: state.mensaje ?? '',
                        accion: FilledButton(
                          onPressed: () => context.read<PlaceSearchCubit>().retry(),
                          child: const Text('Reintentar'),
                        ),
                      ),
                    _ => ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          Text('Lugares en Cartagena',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: b.textoSuave)),
                          const SizedBox(height: 4),
                          for (final (k, lugar) in state.resultados.indexed)
                            _FilaDeResultado(
                              key: ValueKey('${state.consulta}-${lugar.nombre}'),
                              lugar: lugar,
                              consulta: state.consulta,
                              desde: widget.centroDelMapa,
                              retraso: Duration(milliseconds: 40 * k),
                              onTap: () => Navigator.of(context).pop(TripPoint.deLugar(lugar)),
                            ),
                          // Al final siempre está el mapa: si el lugar exacto no aparece, hay salida.
                          const SizedBox(height: 12),
                          _Tarjeta(
                            icono: Icons.map_outlined,
                            titulo: 'Elegir en el mapa',
                            detalle: '¿No aparece el punto exacto? Márcalo tú',
                            onTap: _elegirEnMapa,
                          ),
                        ],
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoDeBusqueda extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onBorrar;

  const _CampoDeBusqueda({required this.controller, required this.hint, required this.onChanged, required this.onBorrar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: b.campo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: b.acento, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: b.acento),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              cursorColor: b.acento,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Borrar',
              onPressed: onBorrar,
              style: IconButton.styleFrom(backgroundColor: b.tarjeta, foregroundColor: b.textoSuave),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}

/// Un resultado: ícono del tipo, el nombre con lo escrito resaltado, el tipo y a qué distancia queda.
class _FilaDeResultado extends StatelessWidget {
  final Place lugar;
  final String consulta;
  final LatLng? desde;
  final Duration retraso;
  final VoidCallback onTap;

  const _FilaDeResultado({
    super.key,
    required this.lugar,
    required this.consulta,
    required this.desde,
    required this.retraso,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final distancia = desde == null ? null : metros(const Distance().as(LengthUnit.Meter, desde!, lugar.punto));
    final fila = Semantics(
      button: true,
      label: '${lugar.nombre}, ${lugar.tipo}${distancia != null ? ', a $distancia' : ''}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: b.divisor))),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(12)),
                child: Icon(lugar.icono, size: 20, color: b.texto),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        for (final (parte, coincide) in tramosResaltados(lugar.nombre, consulta))
                          TextSpan(
                            text: parte,
                            style: coincide ? TextStyle(color: b.acento, fontWeight: FontWeight.w800) : null,
                          ),
                      ]),
                      style: texto.bodyLarge,
                    ),
                    Text(lugar.tipo, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                  ],
                ),
              ),
              if (distancia != null) ...[
                const SizedBox(width: 8),
                Text(distancia, style: texto.labelMedium?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
              ],
            ],
          ),
        ),
      ),
    );
    if (Movimiento.reducido(context)) return fila;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Movimiento.normal + retraso,
      curve: Interval(retraso.inMilliseconds / (Movimiento.normal + retraso).inMilliseconds, 1,
          curve: Movimiento.suave),
      builder: (context, t, hijo) =>
          Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: hijo)),
      child: fila,
    );
  }
}

/// Una acción grande con ícono en su círculo («Elegir en el mapa», «Tu ubicación actual»).
class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? onTap;

  const _Tarjeta({required this.icono, required this.titulo, required this.detalle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final radio = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: '$titulo. $detalle',
      excludeSemantics: true,
      child: Material(
        color: b.tarjeta,
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: b.acentoSuave, child: Icon(icono, size: 20, color: b.acento)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: texto.titleMedium),
                      Text(detalle, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final b = Bahia.de(context);
    return BlocBuilder<SavedPlacesCubit, SavedPlacesState>(
      builder: (context, guardados) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (permitirMiUbicacion) ...[
              _Tarjeta(
                icono: Icons.my_location,
                titulo: 'Tu ubicación actual',
                detalle: 'Sale desde donde estás ahora',
                onTap: onMiUbicacion,
              ),
              const SizedBox(height: 10),
            ],
            _Tarjeta(
              icono: Icons.place_outlined,
              titulo: 'Elegir en el mapa',
              detalle: 'Mueve el mapa hasta el punto exacto',
              onTap: onElegirEnMapa,
            ),
            if (guardados.lugares.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Tus lugares', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: b.textoSuave)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final lugar in guardados.lugares)
                    MiniPlaque(
                      icon: lugar.icono.icono,
                      label: lugar.nombre,
                      onTap: () => Navigator.of(context).pop(TripPoint.deGuardado(lugar)),
                    ),
                ],
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
