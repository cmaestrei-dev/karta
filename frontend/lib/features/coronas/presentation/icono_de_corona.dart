import 'package:flutter/material.dart';

/// La corona de «Rey o reina de la estación», dibujada (Material no trae una).
class IconoDeCorona extends StatelessWidget {
  final double tamano;
  final Color color;

  const IconoDeCorona({super.key, this.tamano = 22, required this.color});

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(size: Size.square(tamano), painter: _Corona(color)));
}

class _Corona extends CustomPainter {
  final Color color;

  _Corona(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final e = size.width / 24;
    final pintura = Paint()..color = color;
    final picos = Path()
      ..moveTo(3 * e, 18 * e)
      ..lineTo(4.5 * e, 7 * e)
      ..lineTo(9 * e, 11.5 * e)
      ..lineTo(12 * e, 4.5 * e)
      ..lineTo(15 * e, 11.5 * e)
      ..lineTo(19.5 * e, 7 * e)
      ..lineTo(21 * e, 18 * e)
      ..close();
    canvas.drawPath(picos, pintura);
    canvas.drawRRect(RRect.fromLTRBR(3 * e, 19 * e, 21 * e, 21 * e, Radius.circular(e)), pintura);
  }

  @override
  bool shouldRepaint(_Corona antes) => antes.color != color;
}
