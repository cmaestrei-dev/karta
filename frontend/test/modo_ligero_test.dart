import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/design/apariencia.dart';
import 'package:karta/core/design/vigia_de_fotogramas.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('el modo ligero se ofrece solo con suficientes fotogramas y muchos lentos', () {
    expect(VigiaDeFotogramas.esLento(total: 100, lentos: 100), isFalse); // muestra corta: no se decide
    expect(VigiaDeFotogramas.esLento(total: 240, lentos: 59), isFalse);
    expect(VigiaDeFotogramas.esLento(total: 240, lentos: 60), isTrue);
  });

  test('el modo ligero se guarda en el teléfono', () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = ModoLigeroCubit();
    await cubit.elegir(true);
    final otro = ModoLigeroCubit();
    await otro.cargar();
    expect(otro.state, isTrue);
  });

  testWidgets('con el modo ligero, los widgets ven las animaciones apagadas', (tester) async {
    late bool sinAnimaciones, ligero;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ModoLigero(
        activo: true,
        child: MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      ),
      home: Builder(builder: (context) {
        sinAnimaciones = MediaQuery.disableAnimationsOf(context);
        ligero = ModoLigero.de(context);
        return const SizedBox();
      }),
    ));
    expect((sinAnimaciones, ligero), (true, true));
  });
}
