import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/bahia.dart';
import '../../../core/design/movimiento.dart';
import '../data/progreso_local.dart';
import '../domain/album.dart';
import '../domain/progreso.dart';
import 'lamina_screen.dart';

/// El álbum de estaciones: una lámina por estación, que se gana al pasar por ella en un viaje compartido.
class AlbumScreen extends StatefulWidget {
  final ProgresoLocal progreso;

  AlbumScreen({super.key, ProgresoLocal? progreso}) : progreso = progreso ?? ProgresoLocal();

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late Future<ProgresoDeJuego> _progreso = widget.progreso.leer();

  Future<void> _abrir(EstacionDelAlbum estacion) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LaminaScreen(estacion: estacion, progreso: widget.progreso),
    ));
    if (mounted) setState(() => _progreso = widget.progreso.leer()); // ya no es «Nueva»
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Álbum de estaciones')),
      body: FutureBuilder<ProgresoDeJuego>(
        future: _progreso,
        builder: (context, datos) {
          final album = datos.data?.album;
          if (album == null) return const LinearProgressIndicator();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: '${album.conseguidas} de ${album.total} estaciones en tu álbum',
                        excludeSemantics: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${album.conseguidas}',
                                style: texto.displaySmall?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabularFigures)),
                            Text(' de ${album.total}', style: texto.titleLarge?.copyWith(color: b.textoSuave)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('estaciones en tu álbum',
                                  style: texto.bodyMedium?.copyWith(color: b.textoSuave)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                            value: album.conseguidas / album.total, minHeight: 10, backgroundColor: b.campo),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        album.lleno
                            ? '¡Lo llenaste! Pasaste por todas las estaciones de Transcaribe compartiendo tus buses.'
                            : 'Se llena cuando pasas por una estación en un viaje compartido. El álbum vive solo en tu '
                                'teléfono.',
                        style: texto.bodySmall?.copyWith(color: b.textoSuave, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130, // tres columnas en un teléfono
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.76,
                  ),
                  itemCount: estacionesDelAlbum.length,
                  itemBuilder: (context, k) {
                    final estacion = estacionesDelAlbum[k];
                    final lamina = album.laminas[estacion.id];
                    return Brote(
                      retraso: Duration(milliseconds: 25 * k),
                      child: lamina == null
                          ? _LaminaQueFalta(estacion: estacion)
                          : _LaminaConseguida(
                              estacion: estacion, nueva: album.nueva == estacion.id, onTap: () => _abrir(estacion)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LaminaConseguida extends StatelessWidget {
  final EstacionDelAlbum estacion;
  final bool nueva;
  final VoidCallback onTap;

  const _LaminaConseguida({required this.estacion, required this.nueva, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final radio = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: '${estacion.nombre}, número ${estacion.numero}${nueva ? ', nueva' : ''}. Ver la lámina',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: b.tarjeta,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: nueva ? BorderSide(color: b.reportar, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SvgPicture.asset(estacion.ilustracion, fit: BoxFit.cover, excludeFromSemantics: true),
                    if (nueva)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: b.reportar, borderRadius: BorderRadius.circular(6)),
                          child: Text('Nueva',
                              style: texto.labelSmall?.copyWith(color: b.sobreReportar, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('N.º ${estacion.numero}', style: texto.labelSmall?.copyWith(color: b.textoSuave)),
                    Text(estacion.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: texto.labelLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La que falta: se ve el nombre (para saber cuáles quedan), no la ilustración.
class _LaminaQueFalta extends StatelessWidget {
  final EstacionDelAlbum estacion;

  const _LaminaQueFalta({required this.estacion});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Semantics(
      label: '${estacion.nombre}, número ${estacion.numero}: te falta',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: b.asa, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: b.tarjeta, shape: BoxShape.circle),
                  child: Text('?', style: texto.titleMedium?.copyWith(color: b.textoSuave, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('N.º ${estacion.numero}', style: texto.labelSmall?.copyWith(color: b.textoSuave)),
                  Text(estacion.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: texto.labelLarge?.copyWith(color: b.textoSuave, height: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
