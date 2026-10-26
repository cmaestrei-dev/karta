import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/design/tema.dart';
import 'package:karta/features/auth/domain/models/usuario.dart';
import 'package:karta/features/legal/data/politica_repository.dart';
import 'package:karta/features/legal/presentation/aviso_de_privacidad.dart';
import 'package:karta/features/legal/presentation/politica_screen.dart';

class _PoliticaFalsa implements PoliticaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Politica> politica() async => const Politica(
        version: '1.0',
        vigenteDesde: '1 de noviembre de 2026',
        responsable: 'Camilo Andrés Maestre Iglesias',
        correo: 'privacidad@karta.test',
        texto: '# Política\n\n## 1. Quién\n\n- **Correo:** privacidad@karta.test.\n\nUn párrafo.',
      );
}

Future<void> _montar(WidgetTester tester, Widget hijo) => tester.pumpWidget(RepositoryProvider<PoliticaRepository>(
      create: (_) => _PoliticaFalsa(),
      child: MaterialApp(theme: TemaBahia.oscuro, home: hijo),
    ));

void main() {
  testWidgets('el aviso dice quién responde y cómo escribirle, y se acepta solo siendo mayor de edad', (tester) async {
    String? aceptada;
    await _montar(tester, AvisoDePrivacidad(onAceptar: (v) => aceptada = v));
    await tester.pumpAndSettle();

    expect(find.textContaining('Camilo Andrés Maestre Iglesias'), findsOneWidget);
    expect(find.textContaining('privacidad@karta.test'), findsWidgets);
    expect(find.text('Leer la política completa (versión 1.0)'), findsOneWidget);

    // Sin la casilla de edad, el botón no hace nada: nunca hay aceptación por omisión.
    final aceptar = find.widgetWithText(FilledButton, 'Acepto y continuar');
    expect(tester.widget<FilledButton>(aceptar).onPressed, isNull);
    await tester.tap(find.text('Tengo 18 años o más'));
    await tester.pump();
    await tester.tap(aceptar);
    expect(aceptada, '1.0');
  });

  testWidgets('la política se lee en la app con sus títulos y negrillas', (tester) async {
    await _montar(tester, const PoliticaScreen());
    await tester.pumpAndSettle();
    expect(find.text('Política'), findsWidgets);
    expect(find.text('1. Quién'), findsOneWidget);
    expect(find.textContaining('privacidad@karta.test', findRichText: true), findsOneWidget);
  });

  test('se vuelve a pedir la autorización solo si no aceptó la versión vigente', () {
    const base = Usuario(id: 'x', email: null, nombre: null, tipoViajero: null, reputacion: 100, alias: 'V', nivel: 1);
    expect(base.debeAceptarPolitica, isFalse); // perfil viejo: aún no se sabe la vigente
    expect(Usuario.fromJson({...base.toJson(), 'politica_vigente': '1.0'}).debeAceptarPolitica, isTrue);
    expect(Usuario.fromJson({...base.toJson(), 'politica_vigente': '1.0', 'autorizacion': '1.0'}).debeAceptarPolitica,
        isFalse);
    expect(Usuario.fromJson({...base.toJson(), 'politica_vigente': '1.1', 'autorizacion': '1.0'}).debeAceptarPolitica,
        isTrue);
  });
}
