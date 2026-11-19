import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/bahia.dart';
import '../data/progreso_local.dart';
import '../domain/album.dart';
import '../domain/progreso.dart';

const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre',
  'noviembre', 'diciembre'];

/// «el 18 de noviembre», o «hoy» y «ayer».
String cuandoLaConsiguio(DateTime fecha, {DateTime? ahora}) {
  final referencia = ahora ?? DateTime.now();
  final hoy = DateTime(referencia.year, referencia.month, referencia.day);
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  final dias = hoy.difference(dia).inDays;
  if (dias == 0) return 'hoy';
  if (dias == 1) return 'ayer';
  return 'el ${fecha.day} de ${_meses[fecha.month - 1]}${fecha.year != hoy.year ? ' de ${fecha.year}' : ''}';
}

/// Una lámina del álbum, en grande. Al abrirla deja de ser «Nueva».
class LaminaScreen extends StatefulWidget {
  final EstacionDelAlbum estacion;
  final ProgresoLocal progreso;

  const LaminaScreen({super.key, required this.estacion, required this.progreso});

  @override
  State<LaminaScreen> createState() => _LaminaScreenState();
}

class _LaminaScreenState extends State<LaminaScreen> {
  late final Future<ProgresoDeJuego> _progreso = widget.progreso.leer();
  bool _eraNueva = false;

  @override
  void initState() {
    super.initState();
    _progreso.then((p) {
      if (p.album.nueva != widget.estacion.id) return;
      if (mounted) setState(() => _eraNueva = true);
      widget.progreso.cambiar((actual) => (progreso: actual.copyWith(album: actual.album.vista()), resultado: null));
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final estacion = widget.estacion;
    return Scaffold(
      appBar: AppBar(title: Text('N.º ${estacion.numero} de ${estacionesDelAlbum.length}')),
      body: FutureBuilder<ProgresoDeJuego>(
        future: _progreso,
        builder: (context, datos) {
          final album = datos.data?.album;
          final lamina = album?.laminas[estacion.id];
          if (album == null || lamina == null) return const SizedBox.shrink();
          final siguiente = album.siguientePorConseguir(despuesDe: estacion.id);
          Widget tarjeta(Widget hijo) => Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(color: b.tarjeta, borderRadius: BorderRadius.circular(18)),
                child: hijo,
              );
          Widget etiqueta(String que, Color color, Color fondo) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
                child: Text(que, style: texto.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
              );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 160 / 110,
                  child: SvgPicture.asset(estacion.ilustracion,
                      fit: BoxFit.cover, semanticsLabel: 'Ilustración de la estación ${estacion.nombre}'),
                ),
              ),
              const SizedBox(height: 16),
              Text(estacion.nombre, style: texto.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                etiqueta(estacion.tipo, b.acento, b.acentoSuave),
                if (_eraNueva) etiqueta('Nueva en tu álbum', b.reportar, b.viaSuave),
              ]),
              const SizedBox(height: 16),
              tarjeta(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'La conseguiste ${cuandoLaConsiguio(lamina.conseguida)}${lamina.ruta != null ? ', en la ${lamina.ruta}' : ''}.',
                    style: texto.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lamina.veces == 1 ? 'Has pasado por aquí una vez.' : 'Has pasado por aquí ${lamina.veces} veces.',
                    style: texto.bodySmall?.copyWith(color: b.textoSuave),
                  ),
                ],
              )),
              if (siguiente != null) ...[
                const SizedBox(height: 12),
                tarjeta(Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14), border: Border.all(color: b.asa, width: 1.5)),
                      child: Text('?', style: texto.titleMedium?.copyWith(color: b.textoSuave)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('La siguiente por conseguir: ${siguiente.nombre}', style: texto.titleSmall),
                          const SizedBox(height: 3),
                          Text(
                            'Te faltan ${album.total - album.conseguidas} para llenar el álbum.',
                            style: texto.bodySmall?.copyWith(color: b.textoSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                )),
              ],
              const SizedBox(height: 20),
              Text(
                'Tu álbum vive en este teléfono: Karta no guarda por dónde pasas.',
                textAlign: TextAlign.center,
                style: texto.bodySmall?.copyWith(color: b.textoSuave),
              ),
            ],
          );
        },
      ),
    );
  }
}
