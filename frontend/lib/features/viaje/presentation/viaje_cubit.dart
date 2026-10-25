import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../trip/domain/trip_models.dart';
import '../data/avisos.dart';
import '../data/preferencia_de_compartir.dart';
import '../data/tiempo_real_repository.dart';
import '../domain/seguidor_de_viaje.dart';

class ViajeState extends Equatable {
  final EstadoDelViaje estado;
  final LatLng? posicion;

  /// El último aviso, para mostrarlo también en pantalla.
  final EventoDelViaje? ultimoEvento;

  /// Por qué no se puede seguir el viaje (GPS apagado, sin permiso).
  final String? error;

  /// Cuándo llega el próximo bus según los viajeros, mientras se camina a la parada o se espera.
  /// Null: aún no se sabe (o no aplica); con [Llegada.minutos] null, nadie lo ha visto.
  final Llegada? llegada;

  /// Está enviando dónde va el bus (solo a bordo, si no lo apagó en Perfil › Privacidad).
  final bool compartiendo;

  /// Lo que contó de este bus («De pie»), para marcarlo en pantalla.
  final Ocupacion? ocupacion;

  const ViajeState({
    required this.estado,
    this.posicion,
    this.ultimoEvento,
    this.error,
    this.llegada,
    this.compartiendo = false,
    this.ocupacion,
  });

  /// Los campos que pueden volver a null se pasan como función: `llegada: () => null`.
  ViajeState copyWith({
    EstadoDelViaje? estado,
    LatLng? posicion,
    EventoDelViaje? ultimoEvento,
    String? Function()? error,
    Llegada? Function()? llegada,
    bool? compartiendo,
    Ocupacion? Function()? ocupacion,
  }) =>
      ViajeState(
        estado: estado ?? this.estado,
        posicion: posicion ?? this.posicion,
        ultimoEvento: ultimoEvento ?? this.ultimoEvento,
        error: error != null ? error() : this.error,
        llegada: llegada != null ? llegada() : this.llegada,
        compartiendo: compartiendo ?? this.compartiendo,
        ocupacion: ocupacion != null ? ocupacion() : this.ocupacion,
      );

  @override
  List<Object?> get props => [estado, posicion, ultimoEvento, error, llegada, compartiendo, ocupacion];
}

/// El viaje activo: escucha el GPS, se lo pasa al [SeguidorDeViaje] y convierte sus eventos en avisos.
/// Con [tiempoReal], además consulta cuándo llega el bus y, a bordo, comparte dónde va (salvo que lo haya apagado).
class ViajeCubit extends Cubit<ViajeState> {
  final RouteOption opcion;
  final Avisos avisos;
  final Stream<LatLng> Function(RouteOption opcion) fuente;
  final SeguidorDeViaje seguidor;
  final TiempoRealRepository? tiempoReal;
  final PreferenciaDeCompartir preferencia;

  /// Contar cómo va el bus o compartirlo pide sesión (el servidor la usa solo para limitar envíos).
  final bool Function() haySesion;

  /// Cada cuánto se consulta la llegada y se envía la posición del bus.
  final Duration cadaCuanto;
  final DateTime Function() reloj;

  StreamSubscription<LatLng>? _suscripcion;
  Timer? _consultas;
  Leg? _busConsultado;
  DateTime? _ultimaLlegada;
  bool _quiereCompartir = false;
  String? _viajeCompartido;
  DateTime? _ultimoEnvio;

  ViajeCubit({
    required this.opcion,
    required this.avisos,
    required this.fuente,
    this.tiempoReal,
    PreferenciaDeCompartir? preferencia,
    this.haySesion = _sinSesion,
    this.cadaCuanto = const Duration(seconds: 30),
    this.reloj = DateTime.now,
  })  : seguidor = SeguidorDeViaje(opcion),
        preferencia = preferencia ?? PreferenciaDeCompartir(),
        super(ViajeState(estado: SeguidorDeViaje(opcion).estado));

  static bool _sinSesion() => false;

  /// El nombre del destino, como lo dice el último tramo («Bocagrande»).
  String get destino => opcion.tramos.last.hasta;

  /// Puede contar cómo va el bus en el que va (y compartir dónde va).
  bool get puedeContar =>
      tiempoReal != null && haySesion() && seguidor.estado.fase == Fase.aBordo && seguidor.tramoActual.ruta != null;

  /// El bus que se está esperando o al que se va caminando; null a bordo o al final.
  Leg? get busQueViene {
    final estado = seguidor.estado;
    return switch (estado.fase) {
      Fase.esperando => seguidor.tramoActual,
      Fase.caminandoALaParada || Fase.transbordo =>
        opcion.tramos.skip(estado.tramo + 1).where((t) => !t.esCaminata).firstOrNull,
      _ => null,
    };
  }

  Future<void> iniciar() async {
    if (tiempoReal != null) _quiereCompartir = await preferencia.compartir() && await preferencia.avisoVisto();
    await avisos.pedirPermiso();
    if (isClosed) return;
    _seguirLlegada();
    _suscripcion = fuente(opcion).listen(
      posicion,
      onError: (Object e) {
        if (!isClosed) emit(state.copyWith(error: () => e.toString().replaceAll('Exception: ', '')));
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
    emit(state.copyWith(
      estado: seguidor.estado,
      posicion: punto,
      ultimoEvento: eventos.isNotEmpty ? eventos.last : null,
      error: () => null,
    ));
    for (final evento in eventos) {
      if (evento == EventoDelViaje.bajaste) _alBajar();
      if (evento == EventoDelViaje.subiste) _alSubir();
    }
    _seguirLlegada();
    _enviarPosicion(punto);
    if (seguidor.estado.fase == Fase.llegaste) _suscripcion?.cancel();
  }

  // Cuándo llega el bus ------------------------------------------------------------------------------------------

  /// Consulta la llegada del bus que viene ahora y la repite cada [cadaCuanto] mientras siga siendo ese bus.
  void _seguirLlegada() {
    final bus = tiempoReal != null ? busQueViene : null;
    if (identical(bus, _busConsultado)) return;
    _busConsultado = bus;
    _consultas?.cancel();
    _consultas = null;
    if (state.llegada != null) emit(state.copyWith(llegada: () => null));
    if (bus == null || bus.ruta == null || bus.puntos.length < 2) return;
    _consultarLlegada(bus);
    _consultas = Timer.periodic(cadaCuanto, (_) => _consultarLlegada(bus));
  }

  Future<void> _consultarLlegada(Leg bus) async {
    try {
      final llegada = await tiempoReal!.llegada(bus.ruta!, desde: bus.puntos.first, hasta: bus.puntos.last);
      if (isClosed || !identical(bus, _busConsultado)) return;
      _ultimaLlegada = reloj();
      emit(state.copyWith(llegada: () => llegada));
    } catch (_) {
      // Sin conexión: la última estimación sirve un rato; después ya no dice nada cierto.
      final vieja = _ultimaLlegada != null && reloj().difference(_ultimaLlegada!) > cadaCuanto * 2;
      if (!isClosed && vieja && identical(bus, _busConsultado)) emit(state.copyWith(llegada: () => null));
    }
  }

  /// Esperando: el bus pasó lleno y no se pudo subir. Lo verán quienes lo esperan más adelante. Se envía la
  /// parada, no la ubicación del viajero.
  Future<void> pasoLleno() async {
    final bus = busQueViene;
    if (tiempoReal == null || bus?.ruta == null || bus!.puntos.isEmpty) return;
    await tiempoReal!.avistamiento(bus.ruta!, bus.puntos.first, ocupacion: Ocupacion.muyLleno);
  }

  // A bordo: cómo va y dónde va ----------------------------------------------------------------------------------

  /// «¿Cómo va el T103?»: si comparte el viaje, va con su posición; si no, como un avistamiento desde el bus.
  Future<void> contarOcupacion(Ocupacion ocupacion) async {
    final punto = state.posicion;
    if (!puedeContar || punto == null) return;
    final viaje = _viajeCompartido;
    if (state.compartiendo && viaje != null && await tiempoReal!.moverViajeCompartido(viaje, punto, ocupacion: ocupacion)) {
      _ultimoEnvio = reloj();
    } else {
      await tiempoReal!.avistamiento(seguidor.tramoActual.ruta!, punto, ocupacion: ocupacion);
    }
    if (!isClosed) emit(state.copyWith(ocupacion: () => ocupacion));
  }

  void _alSubir() {
    if (state.ocupacion != null) emit(state.copyWith(ocupacion: () => null));
    if (_quiereCompartir) _empezarACompartir();
  }

  void _alBajar() {
    _dejarDeCompartir();
    if (state.ocupacion != null) emit(state.copyWith(ocupacion: () => null));
  }

  void _empezarACompartir() {
    if (!puedeContar || state.compartiendo) return;
    emit(state.copyWith(compartiendo: true));
    _ultimoEnvio = null;
    if (state.posicion != null) _enviarPosicion(state.posicion!);
  }

  void _dejarDeCompartir() {
    final viaje = _viajeCompartido;
    _viajeCompartido = null;
    _ultimoEnvio = null;
    if (state.compartiendo && !isClosed) emit(state.copyWith(compartiendo: false));
    // Si no llega, el servidor lo borra solo a los 5 minutos.
    if (viaje != null) tiempoReal?.terminarViajeCompartido(viaje).catchError((_) {});
  }

  /// Envía la posición del bus a lo sumo cada [cadaCuanto]; si el viaje venció en el servidor, empieza otro.
  Future<void> _enviarPosicion(LatLng punto) async {
    if (!state.compartiendo || seguidor.estado.fase != Fase.aBordo) return;
    final ahora = reloj();
    if (_ultimoEnvio != null && ahora.difference(_ultimoEnvio!) < cadaCuanto) return;
    _ultimoEnvio = ahora;
    final ruta = seguidor.tramoActual.ruta!;
    try {
      final viaje = _viajeCompartido;
      if (viaje != null && await tiempoReal!.moverViajeCompartido(viaje, punto)) return;
      final nuevo = await tiempoReal!.iniciarViajeCompartido(ruta, punto);
      if (state.compartiendo && !isClosed && seguidor.tramoActual.ruta == ruta) {
        _viajeCompartido = nuevo;
      } else {
        await tiempoReal!.terminarViajeCompartido(nuevo); // se bajó o dejó de compartir mientras tanto
      }
    } catch (_) {
      // Sin conexión o demasiados envíos: se reintenta con la próxima posición.
    }
  }

  void _avisar(EventoDelViaje evento) {
    final aviso = textoDelAviso(evento, seguidor, destino);
    if (aviso == null) return;
    HapticFeedback.heavyImpact();
    avisos.mostrar(aviso.titulo, aviso.texto);
  }

  Future<void> terminar() async {
    _consultas?.cancel();
    _consultas = null;
    _busConsultado = null;
    _dejarDeCompartir();
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
