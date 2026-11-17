import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Los avisos del viaje como notificaciones que vibran: llegan con la pantalla apagada o en otra app.
class Avisos {
  static const _canal = AndroidNotificationDetails(
    'viaje',
    'Avisos del viaje',
    channelDescription: 'Cuándo subir, cuándo bajarte y cuándo cambiar de bus',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notificacion',
    category: AndroidNotificationCategory.navigation,
  );

  /// Pedir la parada no puede pasar desapercibido: su propio canal, con prioridad máxima y vibración larga.
  static final _canalUrgente = AndroidNotificationDetails(
    'parada',
    'Pedir la parada',
    channelDescription: 'El momento de tocar el timbre para bajarte en un paradero',
    importance: Importance.max,
    priority: Priority.max,
    icon: 'ic_notificacion',
    category: AndroidNotificationCategory.navigation,
    vibrationPattern: Int64List.fromList([0, 700, 250, 700, 250, 700]),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  Future<void> _iniciar() async {
    if (_listo || kIsWeb) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notificacion')),
    );
    _listo = true;
  }

  /// Pide permiso de notificaciones (Android 13 en adelante). Devuelve si quedó concedido.
  Future<bool> pedirPermiso() async {
    if (kIsWeb) return false;
    await _iniciar();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> mostrar(String titulo, String texto, {bool urgente = false}) async {
    if (kIsWeb) return;
    await _iniciar();
    // Un solo aviso a la vez: el nuevo reemplaza al anterior.
    await _plugin.show(
      id: 7,
      title: titulo,
      body: texto,
      notificationDetails: NotificationDetails(android: urgente ? _canalUrgente : _canal),
    );
  }

  Future<void> limpiar() async {
    if (_listo) await _plugin.cancelAll();
  }
}
