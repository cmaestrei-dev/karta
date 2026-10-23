import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Centro del Centro Histórico: vista inicial cuando aún no hay ubicación.
const centroDeCartagena = LatLng(10.4236, -75.5480);

// Saturación al 55 %: las calles y el agua se siguen leyendo, pero los colores
// del mapa no compiten con los códigos de ruta, riesgo y categoría.
const _matrizCal = <double>[
  0.6457, 0.3218, 0.0325, 0, 0,
  0.0957, 0.8718, 0.0325, 0, 0,
  0.0957, 0.3218, 0.5825, 0, 0,
  0, 0, 0, 1, 0,
];

// De noche, «cal bajo farol»: el mismo mapa sin invertir, con menos color, un tono cálido y
// oscurecido restando luz (no multiplicando), para que calles, agua y manzanas conserven
// la diferencia entre sí.
const _matrizNoche = <double>[
  0.4882, 0.4649, 0.0469, 0, -140,
  0.1354, 0.7986, 0.0460, 0, -140,
  0.1313, 0.4417, 0.3771, 0, -140,
  0, 0, 0, 1, 0,
];

/// Teselas de OpenStreetMap con un solo filtro para toda la capa (no uno por tesela).
class KartaTiles extends StatelessWidget {
  const KartaTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final noche = Theme.of(context).brightness == Brightness.dark;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(noche ? _matrizNoche : _matrizCal),
      child: TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'c.karta',
      ),
    );
  }
}

/// Atribución obligatoria de OpenStreetMap. Quien la usa decide dónde va, siempre visible.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text('© colaboradores de OpenStreetMap',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
      ),
    );
  }
}

/// Punto azul de "estás aquí" (o del origen elegido).
class UserLocationDot extends StatelessWidget {
  final String etiqueta;

  const UserLocationDot({super.key, this.etiqueta = 'Tu ubicación'});

  @override
  Widget build(BuildContext context) {
    final azul = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: etiqueta,
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: azul.withValues(alpha: 0.18)),
        alignment: Alignment.center,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: azul,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
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

/// Botón redondo sobre el mapa (volver, centrar en mi ubicación), con fondo de placa.
class MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const MapIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: CircleBorder(side: BorderSide(color: scheme.primary, width: 1.5)),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: IconButton(icon: Icon(icon, color: scheme.primary), tooltip: tooltip, onPressed: onPressed),
    );
  }
}
