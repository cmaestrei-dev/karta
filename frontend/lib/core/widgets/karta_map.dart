import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../design/bahia.dart';

/// Centro del Centro Histórico: vista inicial cuando aún no hay ubicación.
const centroDeCartagena = LatLng(10.4236, -75.5480);

/// Punto de "estás aquí" (o del origen elegido) en el acento. Con [pulso], una onda sale de él cada
/// dos segundos para encontrarlo de un vistazo; se queda quieto si el sistema pide reducir el movimiento.
class UserLocationDot extends StatefulWidget {
  final String etiqueta;
  final bool pulso;

  const UserLocationDot({super.key, this.etiqueta = 'Tu ubicación', this.pulso = false});

  @override
  State<UserLocationDot> createState() => _UserLocationDotState();
}

class _UserLocationDotState extends State<UserLocationDot> with SingleTickerProviderStateMixin {
  late final _onda = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulso && !MediaQuery.disableAnimationsOf(context)) {
      if (!_onda.isAnimating) _onda.repeat();
    } else {
      _onda.stop();
    }
  }

  @override
  void dispose() {
    _onda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final acento = Theme.of(context).colorScheme.primary;
    final punto = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: acento,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
    );
    return Semantics(
      label: widget.etiqueta,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.pulso)
            AnimatedBuilder(
              animation: _onda,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_onda.value);
                return Container(
                  width: 18 + 34 * t,
                  height: 18 + 34 * t,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: acento.withValues(alpha: 0.45 * (1 - t))),
                );
              },
            )
          else
            Container(decoration: BoxDecoration(shape: BoxShape.circle, color: acento.withValues(alpha: 0.18))),
          punto,
        ],
      ),
    );
  }
}

/// Alfiler macizo con el centro blanco: su punta marca el punto. Mide [alto] × 0,75 [alto].
class MapPin extends StatelessWidget {
  final double alto;
  final String? etiqueta;

  const MapPin({super.key, this.alto = 48, this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta,
      child: CustomPaint(
        size: Size(alto * 0.75, alto),
        painter: _Alfiler(Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _Alfiler extends CustomPainter {
  final Color color;

  _Alfiler(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const borde = 2.0;
    final r = size.width / 2 - borde;
    final centro = Offset(size.width / 2, r + borde);
    final punta = Offset(size.width / 2, size.height - borde);
    // Las dos rectas salen de la punta tangentes al círculo de la cabeza.
    final alfa = math.acos(r / (punta.dy - centro.dy));
    final forma = Path()
      ..moveTo(punta.dx, punta.dy)
      ..lineTo(centro.dx - r * math.sin(alfa), centro.dy + r * math.cos(alfa))
      ..arcTo(Rect.fromCircle(center: centro, radius: r), math.pi / 2 + alfa, 2 * math.pi - 2 * alfa, false)
      ..close();

    canvas.drawShadow(forma, Colors.black, 3, false);
    canvas.drawPath(forma, Paint()..color = color);
    canvas.drawPath(
      forma,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = borde
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(centro, r * 0.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_Alfiler anterior) => anterior.color != color;
}

/// Botón redondo de 48 dp sobre el mapa (volver, centrar en mi ubicación), con la superficie de la hoja.
class MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const MapIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final b = Bahia.de(context);
    return Material(
      color: b.hoja,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: IconButton(
        icon: Icon(icon, color: color ?? b.texto),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
      ),
    );
  }
}
