import 'package:flutter/material.dart';

import '../../../core/design/bahia.dart';
import '../../../core/widgets/route_capsule.dart';
import '../../trip/domain/trip_models.dart';
import '../domain/plano_de_estacion.dart';

/// Esperando en una estación doble: los dos vagones en el sentido del mapa, el del bus en su color, y dónde está el
/// viajero (D18).
class DibujoDelPlano extends StatelessWidget {
  final PlanoDeEstacion plano;
  final Leg bus;

  const DibujoDelPlano({super.key, required this.plano, required this.bus});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    final texto = Theme.of(context).textTheme;
    final color = RouteCapsule.colorDe(bus.tipoRuta);
    final (izquierda, derecha) = plano.tuyoALaIzquierda ? (plano.tuyo, plano.otro) : (plano.otro, plano.tuyo);
    final leyenda = plano.leyenda(bus.rutasEnTexto);

    Widget extremo(Vagon v, IconData flecha, {required bool alFinal}) {
      final etiqueta = Text('Hacia ${v.hacia}', style: texto.labelSmall?.copyWith(color: b.textoSuave));
      final icono = Icon(flecha, size: 14, color: b.textoSuave);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: alFinal
            ? [etiqueta, const SizedBox(width: 4), icono]
            : [icono, const SizedBox(width: 4), etiqueta],
      );
    }

    Widget vagon(Vagon v, {required bool aLaIzquierda}) {
      final esTuyo = v == plano.tuyo;
      final tinta = esTuyo ? Bahia.tintaSobre(color) : b.textoSuave;
      const fuera = Radius.circular(12);
      const dentro = Radius.circular(4);
      return Expanded(
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: esTuyo ? color : b.campo,
            borderRadius: aLaIzquierda
                ? const BorderRadius.horizontal(left: fuera, right: dentro)
                : const BorderRadius.horizontal(left: dentro, right: fuera),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (esTuyo) ...[Icon(Icons.directions_bus, size: 16, color: tinta), const SizedBox(width: 6)],
              Text('Vagón ${v.letra}', style: texto.labelLarge?.copyWith(color: tinta)),
            ],
          ),
        ),
      );
    }

    // El centro de cada mitad es donde esperan en promedio sus viajeros: 0 en el vagón de enfrente, 1 en el del bus.
    final posicion = plano.posicion;
    final dondeX = posicion == null
        ? null
        : (plano.tuyoALaIzquierda ? 0.75 - 0.5 * posicion : 0.25 + 0.5 * posicion).clamp(0.04, 0.96);

    return Semantics(
      label: 'Plano de la estación: el vagón ${plano.tuyo.letra}, donde para el ${bus.rutasEnTexto}, queda en el '
          'extremo hacia ${plano.tuyo.hacia}, y el ${plano.otro.letra}, hacia ${plano.otro.hacia}.'
          '${leyenda == null ? '' : ' $leyenda'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                extremo(izquierda, Icons.west, alFinal: false),
                const Spacer(),
                extremo(derecha, Icons.east, alFinal: true),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, medidas) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    // Abajo, el espacio para el punto del viajero, que monta el borde del plano.
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        vagon(izquierda, aLaIzquierda: true),
                        const SizedBox(width: 3),
                        vagon(derecha, aLaIzquierda: false),
                      ],
                    ),
                  ),
                  if (dondeX != null)
                    Positioned(
                      left: medidas.maxWidth * dondeX - 8,
                      top: 44 - 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (leyenda != null) ...[
              const SizedBox(height: 6),
              Text(
                leyenda,
                style: texto.bodySmall?.copyWith(
                    color: plano.donde == DondeEstas.enElOtro ? b.texto : b.textoSuave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
