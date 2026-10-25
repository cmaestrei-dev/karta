import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/auth/domain/models/usuario.dart';
import 'package:karta/features/home/presentation/widgets/avatar_de_viajero.dart';
import 'package:karta/features/home/presentation/widgets/profile_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

import 'bahia_design_test.dart' show contraste;

void main() {
  testWidgets('cada nivel dibuja su marco sin errores, chico y en la vitrina, y sin agrandar la caja', (tester) async {
    for (final (reputacion, archivo) in [(100, null), (160, 'muralla'), (210, 'bahia'), (310, 'castillo'), (500, 'la_popa')]) {
      final usuario = Usuario.fromJson({'id': '1', 'email': 'a@b.co', 'nombre': 'Ana Pérez', 'reputacion': reputacion});
      for (final (tamano, detalle) in [(48.0, 'chico'), (88.0, 'vitrina')]) {
        await tester.pumpWidget(MaterialApp(
            home: Center(child: AvatarDeViajero(usuario: usuario, tamano: tamano, animar: true))));
        await tester.pump(const Duration(milliseconds: 1200)); // a mitad del brillo
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(AvatarDeViajero)), Size.square(tamano + 6));
        final svgs = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).length;
        expect(svgs, archivo == null ? 0 : greaterThan(0), reason: '$archivo $detalle');
        await tester.pumpAndSettle(); // el brillo se detiene solo: dos vueltas
      }
    }
  });

  test('cada marco tiene su arte en las dos versiones', () {
    for (final archivo in ['muralla', 'bahia', 'castillo', 'la_popa']) {
      for (final detalle in ['chico', 'vitrina']) {
        expect(File('assets/marcos/${archivo}_frente_$detalle.svg').existsSync(), isTrue, reason: '$archivo $detalle');
      }
    }
  });

  testWidgets('con «quitar animaciones» el marco no brilla', (tester) async {
    final usuario = Usuario.fromJson({'id': '1', 'email': 'a@b.co', 'nombre': 'Ana', 'reputacion': 500});
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(child: AvatarDeViajero(usuario: usuario, tamano: 88, animar: true)),
      ),
    ));
    expect(tester.hasRunningAnimations, isFalse);
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
