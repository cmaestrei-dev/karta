import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/bahia.dart';
import '../../../core/design/movimiento.dart';
import '../domain/logros.dart';
import '../domain/sellos.dart';

/// Celebra un logro del viaje unos segundos, encima de la barra de abajo, y se va solo: nunca tapa la instrucción
/// ni pide nada. Tocarlo lo quita antes.
class CelebracionDeLogro extends StatefulWidget {
  final LogroDelViaje logro;
  final VoidCallback onVisto;
  final Duration dura;

  const CelebracionDeLogro({super.key, required this.logro, required this.onVisto, this.dura = const Duration(seconds: 4)});

  @override
  State<CelebracionDeLogro> createState() => _CelebracionDeLogroState();
}

class _CelebracionDeLogroState extends State<CelebracionDeLogro> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer(widget.dura, widget.onVisto);
  }

  void _cerrar() {
    _reloj?.cancel();
    widget.onVisto();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final (Widget imagen, String titulo, String detalle) = switch (widget.logro) {
      LaminaNueva(:final estacion, :final conseguidas, :final total) => (
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SvgPicture.asset(estacion.ilustracion, width: 56, height: 40, fit: BoxFit.cover,
                excludeFromSemantics: true),
          ),
          '${estacion.nombre} entró a tu álbum',
          'Llevas $conseguidas de $total estaciones',
        ),
      SelloDelDia(:final sellos, :final llena) => (
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: b.acento, shape: BoxShape.circle),
            child: Icon(Icons.directions_bus, color: b.sobreAcento),
          ),
          llena ? '¡Llenaste tu tarjeta de sellos!' : 'Sello del día',
          llena
              ? 'Siete días compartiendo tu bus. Empieza otra tarjeta.'
              : 'Llevas $sellos de ${TarjetaDeSellos.porTarjeta} en tu tarjeta',
        ),
    };
    return Semantics(
      liveRegion: true,
      button: true,
      label: '$titulo. $detalle. Toca para cerrar',
      excludeSemantics: true,
      onTap: _cerrar,
      child: Brote(
        child: Material(
          color: b.hoja,
          elevation: 6,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: b.reportar.withValues(alpha: 0.6), width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _cerrar,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Row(
                children: [
                  imagen,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(titulo, style: texto.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(detalle, style: texto.bodySmall?.copyWith(color: b.textoSuave)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
