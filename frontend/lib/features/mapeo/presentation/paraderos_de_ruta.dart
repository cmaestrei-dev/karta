import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../../core/design/bahia.dart';
import '../../../core/location_service.dart';
import '../data/mapeo_repository.dart';
import '../domain/mapeo_models.dart';
import 'marcar_paradero_screen.dart';

/// Los paraderos oficiales de la ruta, por sentido y en orden: los que ya están en el mapa, los que alguien marcó
/// y esperan confirmación, y los que faltan, que cualquiera puede marcar (Kartógrafos).
class ParaderosDeLaRuta extends StatefulWidget {
  final String ruta;
  final String tipoRuta;
  final List<LatLng> recorrido;

  const ParaderosDeLaRuta({super.key, required this.ruta, required this.tipoRuta, required this.recorrido});

  @override
  State<ParaderosDeLaRuta> createState() => _ParaderosDeLaRutaState();
}

class _ParaderosDeLaRutaState extends State<ParaderosDeLaRuta> {
  late Future<ParaderosDeRuta> _datos = _cargar();
  int _sentido = 0;

  Future<ParaderosDeRuta> _cargar() => context.read<MapeoRepository>().paraderos(widget.ruta);

  void _recargar() => setState(() => _datos = _cargar());

  void _mensaje(String texto) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _marcar(SentidoDeRuta sentido, ParaderoDeRuta paradero, ParaderosDeRuta datos) async {
    final marcado = await MarcarParaderoScreen.open(
      context,
      ruta: widget.ruta,
      tipoRuta: widget.tipoRuta,
      recorrido: widget.recorrido,
      paradero: paradero,
      vecinos: sentido.vecinos(paradero),
      pistas: datos.pistas,
    );
    if (!mounted || marcado != true) return;
    _mensaje('Gracias, Kartógrafo: cuando otros viajeros que pasen por ahí lo confirmen, quedará en el mapa.');
    _recargar();
  }

  Future<void> _confirmar(ParaderoDeRuta paradero) async {
    final marca = paradero.marca!;
    final respuesta = await showModalBottomSheet<bool>(
      context: context,
      builder: (hoja) => _Confirmar(paradero: paradero, marca: marca),
    );
    if (!mounted || respuesta == null) return;
    try {
      final ubicacion = await LocationService.getCurrentLocation();
      if (!mounted) return;
      final resultado = await context.read<MapeoRepository>().votar(marca.id, estaAqui: respuesta, desde: ubicacion.point);
      _mensaje(switch (resultado.estado) {
        'ubicada' => 'Listo: «${paradero.nombre}» ya está en el mapa. Gracias.',
        'descartada' => 'Gracias: esa marca se quitó y el paradero se puede marcar otra vez.',
        _ => 'Gracias: falta poco para que quede en el mapa.',
      });
      _recargar();
    } on ApiException catch (e) {
      _mensaje(e.message);
    } catch (e) {
      _mensaje(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return FutureBuilder<ParaderosDeRuta>(
      future: _datos,
      builder: (context, snap) {
        final datos = snap.data;
        if (snap.hasError) {
          return Row(children: [
            Expanded(child: Text('No se pudieron cargar los paraderos.', style: texto.bodyMedium)),
            TextButton(onPressed: _recargar, child: const Text('Reintentar')),
          ]);
        }
        if (datos == null) return const LinearProgressIndicator();
        if (datos.sentidos.isEmpty) return const SizedBox.shrink();
        final sentido = datos.sentidos[_sentido.clamp(0, datos.sentidos.length - 1)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Semantics(header: true, child: Text('Paraderos', style: texto.titleLarge))),
                Text('${datos.ubicados} de ${datos.total} en el mapa',
                    style: texto.bodySmall?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Los que faltan los marcan los Kartógrafos: mueves el mapa hasta el paradero y otros viajeros que '
              'pasen por ahí lo confirman.',
              style: texto.bodySmall?.copyWith(color: b.textoSuave),
            ),
            if (datos.sentidos.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (k, s) in datos.sentidos.indexed) ...[
                    if (k > 0) const SizedBox(width: 8),
                    ChoiceChip(label: Text(s.etiqueta), selected: k == _sentido, onSelected: (_) => setState(() => _sentido = k)),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 8),
            for (final paradero in sentido.paraderos)
              _FilaDeParadero(
                paradero: paradero,
                onMarcar: () => _marcar(sentido, paradero, datos),
                onConfirmar: () => _confirmar(paradero),
              ),
            const SizedBox(height: 8),
            Text(
              'Paraderos: «Paradero_Transcaribe 2025», Portal de Datos Abiertos de Cartagena (CC BY), ubicados con '
              'calles de OpenStreetMap y por la comunidad.',
              style: texto.bodySmall?.copyWith(color: b.textoSuave),
            ),
          ],
        );
      },
    );
  }
}

class _FilaDeParadero extends StatelessWidget {
  final ParaderoDeRuta paradero;
  final VoidCallback onMarcar;
  final VoidCallback onConfirmar;

  const _FilaDeParadero({required this.paradero, required this.onMarcar, required this.onConfirmar});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final marca = paradero.marca;
    final (color, relleno) = switch (paradero.estado) {
      EstadoDeParadero.estacion || EstadoDeParadero.direccion || EstadoDeParadero.estimado ||
      EstadoDeParadero.comunidad => (b.acento, true),
      EstadoDeParadero.porConfirmar => (b.via, true),
      EstadoDeParadero.sinUbicar => (b.textoSuave, false),
    };
    final detalle = switch (paradero.estado) {
      EstadoDeParadero.estacion => paradero.modulo != null ? 'Estación · módulo ${paradero.modulo}' : 'Estación',
      EstadoDeParadero.direccion => 'En el mapa',
      EstadoDeParadero.estimado => 'En el mapa · ubicación estimada por la dirección',
      EstadoDeParadero.comunidad => 'En el mapa · lo ubicó la comunidad',
      EstadoDeParadero.porConfirmar => marca!.mia
          ? 'Tu marca · falta que la confirmen'
          : marca.miVoto != null
              ? 'Ya respondiste · por confirmar'
              : 'Alguien lo marcó · por confirmar',
      EstadoDeParadero.sinUbicar => 'Sin ubicar',
    };
    final accion = switch (paradero.estado) {
      EstadoDeParadero.sinUbicar => TextButton(onPressed: onMarcar, child: const Text('Marcar')),
      EstadoDeParadero.porConfirmar when !marca!.mia && marca.miVoto == null =>
        TextButton(onPressed: onConfirmar, child: const Text('¿Está aquí?')),
      _ => null,
    };
    return Semantics(
      label: '${paradero.orden}, ${paradero.nombre}: $detalle',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: relleno ? color.withValues(alpha: 0.18) : null,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.6),
              ),
              child: Text('${paradero.orden}',
                  style: texto.labelSmall?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabularFigures)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paradero.nombre, style: texto.bodyMedium, maxLines: 2),
                    Text(detalle, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                  ],
                ),
              ),
            ),
            ?accion,
          ],
        ),
      ),
    );
  }
}

/// «¿Está aquí «Iglesia Pozón»?»: se responde estando allí.
class _Confirmar extends StatelessWidget {
  final ParaderoDeRuta paradero;
  final MarcaDeParadero marca;

  const _Confirmar({required this.paradero, required this.marca});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final b = Bahia.de(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Está aquí «${paradero.nombre}»?', style: texto.titleLarge),
            const SizedBox(height: 8),
            SizedBox(height: 180, child: MapaDeUnPunto(punto: marca.punto)),
            const SizedBox(height: 8),
            Text('Respóndelo estando allí (a menos de 300 m): usamos tu ubicación solo para comprobarlo.',
                style: texto.bodySmall?.copyWith(color: b.textoSuave)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No está aquí'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, está aquí'))),
            ]),
          ],
        ),
      ),
    );
  }
}
