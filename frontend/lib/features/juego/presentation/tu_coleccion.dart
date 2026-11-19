import 'package:flutter/material.dart';

import '../../../core/design/bahia.dart';
import '../data/progreso_local.dart';
import '../domain/progreso.dart';
import '../domain/sellos.dart';

/// En el perfil: el álbum de estaciones y la tarjeta de sellos (docs/plan-juego.md). Todo sale del teléfono.
class TuColeccion extends StatelessWidget {
  final ProgresoLocal progreso;

  /// Para abrir el álbum después de cerrar la hoja del perfil.
  final VoidCallback onAbrirAlbum;

  TuColeccion({super.key, ProgresoLocal? progreso, required this.onAbrirAlbum})
      : progreso = progreso ?? ProgresoLocal();

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return FutureBuilder<ProgresoDeJuego>(
      future: progreso.leer(),
      builder: (context, datos) {
        final p = datos.data ?? const ProgresoDeJuego();
        final album = p.album, tarjeta = p.tarjeta;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Tu colección', style: texto.titleMedium),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAbrirAlbum,
                    child: Semantics(
                      button: true,
                      onTap: onAbrirAlbum,
                      label: 'Álbum de estaciones: ${album.conseguidas} de ${album.total}'
                          '${album.nueva != null ? ', con una lámina nueva' : ''}. Abrir el álbum',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: b.acentoSuave, borderRadius: BorderRadius.circular(14)),
                              child: Icon(Icons.collections_bookmark_outlined, color: b.acento),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text('Álbum de estaciones', style: texto.titleSmall)),
                                      if (album.nueva != null)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                              color: b.reportar, borderRadius: BorderRadius.circular(6)),
                                          child: Text('Nueva',
                                              style: texto.labelSmall?.copyWith(
                                                  color: b.sobreReportar, fontWeight: FontWeight.w800)),
                                        ),
                                      Text('${album.conseguidas} de ${album.total}',
                                          style: texto.bodySmall
                                              ?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                        value: album.conseguidas / album.total,
                                        minHeight: 6,
                                        backgroundColor: b.campo),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: b.textoSuave),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: b.divisor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _Tarjeta(tarjeta: tarjeta),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// La tarjeta de sellos: siete casillas, sin fechas, porque no importa qué días fueron.
class _Tarjeta extends StatelessWidget {
  final TarjetaDeSellos tarjeta;

  const _Tarjeta({required this.tarjeta});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    return Semantics(
      label: 'Tarjeta de sellos: ${tarjeta.sellos} de ${TarjetaDeSellos.porTarjeta}'
          '${tarjeta.llenas > 0 ? '. Has llenado ${tarjeta.llenas}' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Tarjeta de sellos', style: texto.titleSmall)),
              Text('${tarjeta.sellos} de ${TarjetaDeSellos.porTarjeta}',
                  style: texto.bodySmall?.copyWith(color: b.textoSuave, fontFeatures: tabularFigures)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, caja) {
            final lado = ((caja.maxWidth - 6 * 8) / TarjetaDeSellos.porTarjeta).clamp(24.0, 40.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var k = 0; k < TarjetaDeSellos.porTarjeta; k++)
                  Container(
                    width: lado,
                    height: lado,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k < tarjeta.sellos ? b.acento : Colors.transparent,
                      border: Border.all(color: k < tarjeta.sellos ? b.acento : b.asa, width: 2),
                    ),
                    child: k < tarjeta.sellos ? Icon(Icons.directions_bus, size: lado * 0.55, color: b.sobreAcento) : null,
                  ),
              ],
            );
          }),
          const SizedBox(height: 10),
          Text(
            'Un sello por cada día que compartes dónde va tu bus. No tienen que ser días seguidos.'
            '${tarjeta.llenas > 0 ? ' Tarjetas llenas: ${tarjeta.llenas}.' : ''}',
            style: texto.bodySmall?.copyWith(color: b.textoSuave, height: 1.4),
          ),
        ],
      ),
    );
  }
}
