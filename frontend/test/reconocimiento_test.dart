import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/auth/domain/models/usuario.dart';
import 'package:karta/features/home/presentation/widgets/profile_sheet.dart';

import 'bahia_design_test.dart' show contraste;

void main() {
  testWidgets('cada nivel dibuja su marco sin errores, también en tamaño pequeño', (tester) async {
    for (final (reputacion, marco) in [(100, null), (160, 'Muralla'), (210, 'Bahía'), (310, 'Castillo'), (500, 'La Popa')]) {
      final usuario = Usuario.fromJson({'id': '1', 'email': 'a@b.co', 'nombre': 'Ana Pérez', 'reputacion': reputacion});
      expect(usuario.marco, marco);
      for (final tamano in [32.0, 56.0]) {
        await tester.pumpWidget(MaterialApp(home: Center(child: AvatarDeViajero(usuario: usuario, tamano: tamano))));
        expect(tester.takeException(), isNull);
        final pintor = tester.widget<CustomPaint>(find.byWidgetPredicate(
            (w) => w is CustomPaint && w.foregroundPainter is PintorDeMarco)).foregroundPainter as PintorDeMarco;
        expect(pintor.marco, marco);
      }
    }
  });

  test('los íconos de las medallas se leen sobre su color (≥ 4,5:1)', () {
    for (final MapEntry(key: clave, value: (fondo, _)) in medallas.entries) {
      expect(contraste(tintaDeMedalla, fondo), greaterThanOrEqualTo(4.5), reason: clave);
    }
  });

  test('el marco solo se vuelve a pintar si cambia', () {
    const bahia = PintorDeMarco(marco: 'Bahía', acento: Colors.teal);
    expect(bahia.shouldRepaint(const PintorDeMarco(marco: 'Bahía', acento: Colors.teal)), isFalse);
    expect(bahia.shouldRepaint(const PintorDeMarco(marco: 'Castillo', acento: Colors.teal)), isTrue);
  });
}
