import 'package:flutter/material.dart';

import '../../../core/design/bahia.dart';
import '../data/progreso_local.dart';
import '../domain/progreso.dart';
import '../domain/sellos.dart';
import 'iguana.dart';

/// En el perfil: el álbum de estaciones, la tarjeta de sellos y la iguana (docs/plan-juego.md). Todo sale del
/// teléfono.
class TuColeccion extends StatefulWidget {
  final ProgresoLocal progreso;

  /// Para abrir el álbum después de cerrar la hoja del perfil.
  final VoidCallback onAbrirAlbum;

  TuColeccion({super.key, ProgresoLocal? progreso, required this.onAbrirAlbum})
      : progreso = progreso ?? ProgresoLocal();

  @override
  State<TuColeccion> createState() => _TuColeccionState();
}

class _TuColeccionState extends State<TuColeccion> {
  late Future<ProgresoDeJuego> _progreso = widget.progreso.leer();

  Future<void> _vestir() async {
    await abrirVestidor(context, widget.progreso);
    if (mounted) setState(() => _progreso = widget.progreso.leer());
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final onAbrirAlbum = widget.onAbrirAlbum;
    return FutureBuilder<ProgresoDeJuego>(
      future: _progreso,
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
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration:
                                      BoxDecoration(color: b.acentoSuave, borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.collections_bookmark_outlined, color: b.acento),
                                ),
                                if (album.nueva != null)
                                  Positioned(
                                    top: -3,
                                    right: -3,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                          color: b.reportar,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: b.tarjeta, width: 2.5)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text('Álbum de estaciones', style: texto.titleSmall)),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _Tarjeta(tarjeta: tarjeta),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: b.divisor),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _vestir,
                    child: Semantics(
                      button: true,
                      onTap: _vestir,
                      label: 'Tu iguana: ${p.puesto?.nombre ?? 'sin accesorios'}. '
                          '${accesorios.where((a) => a.ganado(tarjeta.llenas)).length} de ${accesorios.length} '
                          'accesorios ganados. Vestirla',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                        child: Row(
                          children: [
                            Iguana(animo: AnimoDeIguana.feliz, accesorio: p.puesto, tamano: 64),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tu iguana del Centenario', style: texto.titleSmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${accesorios.where((a) => a.ganado(tarjeta.llenas)).length} de '
                                    '${accesorios.length} accesorios · cada tarjeta llena le gana uno',
                                    style: texto.bodySmall?.copyWith(color: b.textoSuave),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.checkroom_outlined, color: b.textoSuave),
                          ],
                        ),
                      ),
                    ),
                  ),
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
