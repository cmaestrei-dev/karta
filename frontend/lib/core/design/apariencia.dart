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
