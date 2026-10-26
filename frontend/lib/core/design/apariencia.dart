import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema que eligió el viajero: el del teléfono (por defecto), siempre claro o siempre oscuro.
/// Se guarda en el teléfono y se aplica desde que la app abre.
class AparienciaCubit extends Cubit<ThemeMode> {
  static const _clave = 'karta_tema';

  AparienciaCubit() : super(ThemeMode.system);

  Future<void> cargar() async {
    final guardado = (await SharedPreferences.getInstance()).getString(_clave);
    final modo = ThemeMode.values.where((m) => m.name == guardado).firstOrNull;
    if (modo != null && !isClosed) emit(modo);
  }

  Future<void> elegir(ThemeMode modo) async {
    emit(modo);
    await (await SharedPreferences.getInstance()).setString(_clave, modo.name);
  }
}

/// Modo ligero (D13), para teléfonos lentos: la app sin animaciones decorativas y un mapa que pinta los nombres de
/// las calles una sola vez por tesela, no en cada cuadro. Se guarda en el teléfono.
class ModoLigeroCubit extends Cubit<bool> {
  static const _clave = 'karta_modo_ligero';

  ModoLigeroCubit() : super(false);

  Future<void> cargar() async {
    final guardado = (await SharedPreferences.getInstance()).getBool(_clave);
    if (guardado != null && !isClosed) emit(guardado);
  }

  Future<void> elegir(bool activo) async {
    emit(activo);
    await (await SharedPreferences.getInstance()).setBool(_clave, activo);
  }
}

/// Si el modo ligero está activo, para lo que no lee el bloc (el mapa base). Lo pone la app sobre todo lo demás.
class ModoLigero extends InheritedWidget {
  final bool activo;

  const ModoLigero({super.key, required this.activo, required super.child});

  static bool de(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ModoLigero>()?.activo ?? false;

  @override
  bool updateShouldNotify(ModoLigero antes) => antes.activo != activo;
}
