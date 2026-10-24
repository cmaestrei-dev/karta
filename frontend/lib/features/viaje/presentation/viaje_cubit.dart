import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../trip/domain/trip_models.dart';
import '../data/avisos.dart';
import '../domain/seguidor_de_viaje.dart';

class ViajeState extends Equatable {
  final EstadoDelViaje estado;
  final LatLng? posicion;

  /// El último aviso, para mostrarlo también en pantalla.
  final EventoDelViaje? ultimoEvento;

  /// Por qué no se puede seguir el viaje (GPS apagado, sin permiso).
  final String? error;

  const ViajeState({required this.estado, this.posicion, this.ultimoEvento, this.error});

  ViajeState copyWith({EstadoDelViaje? estado, LatLng? posicion, EventoDelViaje? ultimoEvento, String? error}) =>
      ViajeState(
        estado: estado ?? this.estado,
        posicion: posicion ?? this.posicion,
        ultimoEvento: ultimoEvento ?? this.ultimoEvento,
        error: error,
      );

  @override
  List<Object?> get props => [estado, posicion, ultimoEvento, error];
}

/// El viaje activo: escucha el GPS, se lo pasa al [SeguidorDeViaje] y convierte sus eventos en avisos.
class ViajeCubit extends Cubit<ViajeState> {
  final RouteOption opcion;
  final Avisos avisos;
  final Stream<LatLng> Function(RouteOption opcion) fuente;
  final SeguidorDeViaje seguidor;
  StreamSubscription<LatLng>? _suscripcion;

  ViajeCubit({required this.opcion, required this.avisos, required this.fuente})
      : seguidor = SeguidorDeViaje(opcion),
        super(ViajeState(estado: SeguidorDeViaje(opcion).estado));

  /// El nombre del destino, como lo dice el último tramo («Bocagrande»).
  String get destino => opcion.tramos.last.hasta;

  Future<void> iniciar() async {
    await avisos.pedirPermiso();
    _suscripcion = fuente(opcion).listen(
      posicion,
      onError: (Object e) {
        if (!isClosed) emit(state.copyWith(error: e.toString().replaceAll('Exception: ', '')));
      },
    );
  }

  /// Una posición nueva del GPS (pública para las pruebas).
  void posicion(LatLng punto) {
    if (isClosed) return;
    final eventos = seguidor.actualizar(punto);
    for (final evento in eventos) {
      _avisar(evento);
    }
    emit(ViajeState(
      estado: seguidor.estado,
      posicion: punto,
      ultimoEvento: eventos.isNotEmpty ? eventos.last : state.ultimoEvento,
    ));
    if (seguidor.estado.fase == Fase.llegaste) _suscripcion?.cancel();
  }

  void _avisar(EventoDelViaje evento) {
    final aviso = textoDelAviso(evento, seguidor, destino);
    if (aviso == null) return;
    HapticFeedback.heavyImpact();
    avisos.mostrar(aviso.titulo, aviso.texto);
  }

  Future<void> terminar() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
    await avisos.limpiar();
  }

  @override
  Future<void> close() async {
    await terminar();
    return super.close();
  }
}

/// El texto de cada aviso, con lo que toca hacer ahora. Null si el evento no amerita notificación.
({String titulo, String texto})? textoDelAviso(EventoDelViaje evento, SeguidorDeViaje seguidor, String destino) {
  final actual = seguidor.tramoActual;
  return switch (evento) {
    EventoDelViaje.llegasteALaParada =>
      (titulo: 'Llegaste a ${actual.desde}', texto: 'Espera el ${actual.ruta}. Te avisamos antes de bajarte.'),
    EventoDelViaje.subiste => null,
    EventoDelViaje.bajateEnLaProxima =>
      (titulo: 'Bájate en la próxima', texto: '${actual.hasta}. Ve acercándote a la puerta.'),
    EventoDelViaje.bajateAqui => (titulo: 'Bájate aquí', texto: actual.hasta),
    EventoDelViaje.bajaste => switch (seguidor.estado.fase) {
        Fase.transbordo => (
            titulo: 'Ahora cambia de bus',
            texto: 'Camina hasta ${actual.hasta} y toma el ${seguidor.tramoSiguiente?.ruta ?? 'siguiente bus'}.',
          ),
        _ => (titulo: 'Camina a $destino', texto: 'Ya casi llegas.'),
      },
    EventoDelViaje.llegaste => (titulo: 'Llegaste a $destino', texto: 'Buen viaje con Karta.'),
    EventoDelViaje.teDesviaste =>
      (titulo: 'Te saliste del recorrido', texto: 'Abre Karta para buscar otra forma de llegar.'),
  };
}
