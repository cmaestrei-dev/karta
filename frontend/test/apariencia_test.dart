import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/design/apariencia.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sin elección guardada sigue el tema del teléfono', () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AparienciaCubit();
    await cubit.cargar();
    expect(cubit.state, ThemeMode.system);
  });

  test('recuerda el tema elegido al volver a abrir la app', () async {
    SharedPreferences.setMockInitialValues({});
    await AparienciaCubit().elegir(ThemeMode.light);

    final alAbrir = AparienciaCubit();
    await alAbrir.cargar();
    expect(alAbrir.state, ThemeMode.light);
  });

  test('un valor guardado desconocido no rompe nada', () async {
    SharedPreferences.setMockInitialValues({'karta_tema': 'sepia'});
    final cubit = AparienciaCubit();
    await cubit.cargar();
    expect(cubit.state, ThemeMode.system);
  });
}
