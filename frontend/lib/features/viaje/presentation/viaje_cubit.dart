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
import 'instrucciones.dart';

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

  /// Es momento de pedir la parada (pantalla completa) hasta que diga que ya lo hizo o se baje.
  final ComoPedirLaParada? pedirLaParada;

  /// A bordo y fuera del recorrido, el viajero confirmó que el bus se desvió: se le sigue acompañando, sin
  /// proponerle otra ruta, hasta que el bus vuelva a su recorrido.
  final bool desvioDelBus;

  /// A bordo, el bus lleva varios minutos quieto lejos de una estación: «¿El T103 se varó?».
  final bool preguntarVarado;

  /// El viajero reportó que el bus se varó: se le agradece y se le ofrece otra ruta.
  final bool varadoReportado;

  /// Se bajó en un paradero: «¿Cómo pediste la parada en …?» (D12), con el nombre del paradero.
  final String? preguntarComoPediste;

  /// Cómo se pide la parada en la bajada del bus de este tramo, según los viajeros.
  final ComoSePideAqui? comoSePideAqui;

  /// Con «el que pase primero» (T103 o T101): cuál llega antes según los viajeros, y en cuál dijo que va.
  final String? rutaQueLlega;
  final String? rutaABordo;

  const ViajeState({
    required this.estado,
    this.posicion,
    this.ultimoEvento,
    this.error,
    this.llegada,
    this.compartiendo = false,
    this.ocupacion,
    this.pedirLaParada,
    this.desvioDelBus = false,
    this.preguntarVarado = false,
    this.varadoReportado = false,
    this.preguntarComoPediste,
    this.comoSePideAqui,
    this.rutaQueLlega,
    this.rutaABordo,
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
    ComoPedirLaParada? Function()? pedirLaParada,
    bool? desvioDelBus,
    bool? preguntarVarado,
    bool? varadoReportado,
    String? Function()? preguntarComoPediste,
    ComoSePideAqui? Function()? comoSePideAqui,
    String? Function()? rutaQueLlega,
    String? Function()? rutaABordo,
  }) =>
      ViajeState(
        estado: estado ?? this.estado,
        posicion: posicion ?? this.posicion,
        ultimoEvento: ultimoEvento ?? this.ultimoEvento,
        error: error != null ? error() : this.error,
        llegada: llegada != null ? llegada() : this.llegada,
        compartiendo: compartiendo ?? this.compartiendo,
        ocupacion: ocupacion != null ? ocupacion() : this.ocupacion,
        pedirLaParada: pedirLaParada != null ? pedirLaParada() : this.pedirLaParada,
        desvioDelBus: desvioDelBus ?? this.desvioDelBus,
        preguntarVarado: preguntarVarado ?? this.preguntarVarado,
        varadoReportado: varadoReportado ?? this.varadoReportado,
        preguntarComoPediste: preguntarComoPediste != null ? preguntarComoPediste() : this.preguntarComoPediste,
        comoSePideAqui: comoSePideAqui != null ? comoSePideAqui() : this.comoSePideAqui,
        rutaQueLlega: rutaQueLlega != null ? rutaQueLlega() : this.rutaQueLlega,
        rutaABordo: rutaABordo != null ? rutaABordo() : this.rutaABordo,
      );

  @override
  List<Object?> get props => [
        estado, posicion, ultimoEvento, error, llegada, compartiendo, ocupacion, pedirLaParada, desvioDelBus,
        preguntarVarado, varadoReportado, preguntarComoPediste, comoSePideAqui, rutaQueLlega, rutaABordo,
      ];
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

  /// Tanto tiempo quieto a bordo, lejos de una estación y de la bajada, hace preguntar si el bus se varó.
  static const quietoParaPreguntar = Duration(minutes: 4);
  static const radioQuietoM = 35.0;

  StreamSubscription<LatLng>? _suscripcion;
  Timer? _consultas;
  Timer? _vigiaQuieto;
  LatLng? _anclaQuieto;
  DateTime? _quietoDesde;
  bool _yaPreguntoVarado = false;

  /// Como máximo una pregunta por viaje (D12): si ya se preguntó por un varado o un desvío, no se pregunta más.
  bool _huboPregunta = false;
  Leg? _paraderoPorResponder;
  Leg? _busSabido;
  bool _contadoEsteBus = false;
  Leg? _busConsultado;
  DateTime? _ultimaLlegada;
  Llegada? _ultimoDato;

  /// Sin conexión, la última estimación se sigue mostrando (envejecida y diciéndolo) hasta este tiempo.
  static const vigenciaSinConexion = Duration(minutes: 5);
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

  /// La ruta del bus en que va: la que dijo, o la que se esperaba que pasara primero, o la del tramo.
  String? get rutaDelBus => state.rutaABordo ?? _rutaPrevista ?? seguidor.tramoActual.ruta;
  String? _rutaPrevista;
  String? _rutaCompartida;
  LatLng? _dondeEsperaba;

  /// «Voy en el T101»: con «el que pase primero», cuál de las rutas tomó. Lo que comparta va con esa ruta.
  void voyEn(String ruta) {
    if (isClosed || seguidor.estado.fase != Fase.aBordo) return;
    emit(state.copyWith(rutaABordo: () => ruta));
    final viaje = _viajeCompartido;
    if (viaje != null && _rutaCompartida != ruta) {
      _viajeCompartido = null;
      _ultimoEnvio = null;
      tiempoReal?.terminarViajeCompartido(viaje).catchError((_) {});
      if (state.posicion != null) _enviarPosicion(state.posicion!);
    }
  }

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
    final tramoAntes = seguidor.tramoActual;
    if (seguidor.estado.fase == Fase.esperando) _dondeEsperaba = state.posicion ?? punto;
    final eventos = seguidor.actualizar(punto);
    for (final evento in eventos) {
      _avisar(evento);
    }
    emit(state.copyWith(
      estado: seguidor.estado,
      posicion: punto,
      ultimoEvento: eventos.isNotEmpty ? eventos.last : null,
      error: () => null,
      // El desvío confirmado dura mientras el bus siga fuera del recorrido y el viajero a bordo.
      desvioDelBus: state.desvioDelBus && seguidor.estado.desviado && seguidor.estado.fase == Fase.aBordo,
    ));
    _seMovio(punto);
    if (seguidor.estado.desviado && seguidor.estado.fase == Fase.aBordo) _huboPregunta = true; // «¿Se desvió?»
    for (final evento in eventos) {
      if (evento == EventoDelViaje.bajaste) _alBajar(tramoAntes);
      if (evento == EventoDelViaje.subiste) _alSubir();
      if (evento == EventoDelViaje.pideLaParada) {
        emit(state.copyWith(pedirLaParada: () => comoPedirLaParada(seguidor.tramoActual)));
      }
    }
    _seguirLlegada();
    _enviarPosicion(punto);
    if (seguidor.estado.fase == Fase.llegaste) _suscripcion?.cancel();
  }

  // Cuándo llega el bus ------------------------------------------------------------------------------------------

  /// Consulta la llegada del bus que viene ahora y la repite cada [cadaCuanto] mientras siga siendo ese bus.
  void _seguirLlegada() {
    final bus = tiempoReal != null ? busQueViene : null;
    if (bus != null) _saberComoSePide(bus);
    if (identical(bus, _busConsultado)) return;
    _busConsultado = bus;
    _consultas?.cancel();
    _consultas = null;
    _ultimoDato = null;
    _ultimaLlegada = null;
    if (state.llegada != null || state.rutaQueLlega != null) {
      emit(state.copyWith(llegada: () => null, rutaQueLlega: () => null));
    }
    if (bus == null || bus.ruta == null || bus.puntos.length < 2) return;
    _consultarLlegada(bus);
    _consultas = Timer.periodic(cadaCuanto, (_) => _consultarLlegada(bus));
  }

  Future<void> _consultarLlegada(Leg bus) async {
    try {
      // Con «el que pase primero», la llegada de cada ruta: se muestra la que pasa antes.
      final llegadas = await Future.wait([
        for (final ruta in bus.rutas) tiempoReal!.llegada(ruta, desde: bus.puntos.first, hasta: bus.puntos.last),
      ]);
      if (isClosed || !identical(bus, _busConsultado)) return;
      var k = 0;
      for (var i = 1; i < llegadas.length; i++) {
        final m = llegadas[i].minutos, mejor = llegadas[k].minutos;
        if (m != null && (mejor == null || m < mejor)) k = i;
      }
      final llegada = llegadas[k];
      _ultimaLlegada = reloj();
      _ultimoDato = llegada;
      emit(state.copyWith(llegada: () => llegada, rutaQueLlega: () => bus.alternativas.isEmpty ? null : bus.rutas[k]));
    } catch (_) {
      // Sin conexión: la última estimación sirve unos minutos, descontando lo que pasó y diciendo de cuándo es;
      // después ya no dice nada cierto.
      final dato = _ultimoDato, desde = _ultimaLlegada;
      if (isClosed || !identical(bus, _busConsultado) || dato == null || desde == null) return;
      final transcurrido = reloj().difference(desde);
      emit(state.copyWith(
          llegada: () => transcurrido > vigenciaSinConexion ? null : dato.sinConexionDesde(transcurrido)));
    }
  }

  /// Esperando: el bus pasó lleno y no se pudo subir. Lo verán quienes lo esperan más adelante. Se envía la
  /// parada, no la ubicación del viajero.
  Future<void> pasoLleno() async {
    final bus = busQueViene;
    if (tiempoReal == null || bus?.ruta == null || bus!.puntos.isEmpty) return;
    await tiempoReal!.avistamiento(state.rutaQueLlega ?? bus.ruta!, bus.puntos.first, ocupacion: Ocupacion.muyLleno);
  }

  // Cómo se pide la parada (D12) ----------------------------------------------------------------------------------

  /// Antes de subir (cuando suele haber señal), lo que saben los viajeros del paradero donde se va a bajar.
  Future<void> _saberComoSePide(Leg bus) async {
    if (identical(bus, _busSabido) || comoPedirLaParada(bus) == ComoPedirLaParada.paraSolo) return;
    if (bus.ruta == null || bus.puntos.isEmpty) return;
    _busSabido = bus;
    try {
      final sabido = await tiempoReal!.comoSePide(bus.ruta!, bus.puntos.last);
      if (!isClosed && identical(bus, _busSabido)) emit(state.copyWith(comoSePideAqui: () => sabido));
    } catch (_) {
      // Sin conexión: el aviso dice lo de siempre.
    }
  }

  /// «¿Cómo pediste la parada?»: se envía el paradero y la respuesta, nada más.
  Future<void> respondiComoPedi(ComoSePidio como) async {
    final bus = _paraderoPorResponder;
    _paraderoPorResponder = null;
    if (!isClosed) emit(state.copyWith(preguntarComoPediste: () => null));
    if (tiempoReal == null || bus?.ruta == null || bus!.puntos.isEmpty) return;
    await tiempoReal!.comoPediLaParada(bus.ruta!, bus.puntos.last, como);
  }

  void saltarComoPedi() {
    _paraderoPorResponder = null;
    if (!isClosed && state.preguntarComoPediste != null) emit(state.copyWith(preguntarComoPediste: () => null));
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
      await tiempoReal!.avistamiento(rutaDelBus!, punto, ocupacion: ocupacion);
    }
    if (!isClosed) emit(state.copyWith(ocupacion: () => ocupacion));
  }

  void _alSubir() {
    if (state.ocupacion != null) emit(state.copyWith(ocupacion: () => null));
    _rutaPrevista = state.rutaQueLlega;
    if (state.rutaABordo != null) emit(state.copyWith(rutaABordo: () => null));
    saltarComoPedi(); // si no respondió antes de subir al siguiente bus, el momento ya pasó
    if (_quiereCompartir) _empezarACompartir();
    _contarSubida();
    _contadoEsteBus = false;
    // Con el bus quieto el GPS no manda posiciones (solo cada 10 m): un reloj revisa si lleva mucho quieto.
    _yaPreguntoVarado = false;
    _anclaQuieto = state.posicion;
    _quietoDesde = reloj();
    _vigiaQuieto?.cancel();
    _vigiaQuieto = Timer.periodic(cadaCuanto, (_) => revisarSiSeVaro());
  }

  /// Subió a la ruta: el punto donde esperaba va con el mismo permiso de compartir el viaje, y sin el nombre de
  /// nadie. En la calle es una pista para ubicar el paradero; en una estación, con el módulo del bus, enseña de qué
  /// lado queda cada vagón (sin módulo, en la estación no sirve).
  void _contarSubida() {
    final tramo = seguidor.tramoActual, punto = _dondeEsperaba;
    _dondeEsperaba = null;
    if (!_quiereCompartir || !haySesion() || tiempoReal == null || punto == null) return;
    if (tramo.subeEnEstacion && tramo.modulo == null) return;
    final ruta = rutaDelBus;
    if (ruta != null) {
      tiempoReal!.subida(ruta, punto, modulo: tramo.subeEnEstacion ? tramo.modulo : null).catchError((_) {});
    }
  }

  void _seMovio(LatLng punto) {
    final ancla = _anclaQuieto;
    if (ancla != null && const Distance().as(LengthUnit.Meter, ancla, punto) <= radioQuietoM) return;
    _anclaQuieto = punto;
    _quietoDesde = reloj();
    // Si el bus volvió a andar, la pregunta ya no aplica.
    if (state.preguntarVarado) emit(state.copyWith(preguntarVarado: false));
  }

  /// Pregunta una vez por bus si lleva [quietoParaPreguntar] quieto lejos de la bajada y de las estaciones
  /// (pública para las pruebas).
  void revisarSiSeVaro() {
    final ancla = _anclaQuieto, desde = _quietoDesde;
    if (isClosed || _yaPreguntoVarado || ancla == null || desde == null) return;
    if (seguidor.estado.fase != Fase.aBordo || tiempoReal == null || !haySesion()) return;
    final quieto = reloj().difference(desde);
    if (quieto < quietoParaPreguntar || seguidor.estado.faltaDelTramoM < 250) return;
    final enEstacion = seguidor.tramoActual.paradas
        .any((p) => const Distance().as(LengthUnit.Meter, p.punto, ancla) <= 80);
    if (enEstacion) return;
    _yaPreguntoVarado = true;
    _huboPregunta = true;
    emit(state.copyWith(preguntarVarado: true));
    avisos.mostrar('¿El ${rutaDelBus ?? 'bus'} se varó?',
        'Lleva ${quieto.inMinutes} minutos quieto. Abre Karta para contarnos.');
  }

  /// «Sí, se varó»: se reporta donde está el bus, para que quienes lo esperan sepan que no llegará.
  Future<void> seVaro() async {
    final punto = state.posicion ?? _anclaQuieto;
    final ruta = rutaDelBus;
    if (tiempoReal == null || punto == null || ruta == null) return;
    await tiempoReal!.reportar('bus_varado', {'ruta': ruta}, punto);
    if (!isClosed) emit(state.copyWith(preguntarVarado: false, varadoReportado: true));
  }

  /// «Es un trancón»: se reporta el trancón detenido y se sigue el viaje.
  Future<void> esTrancon() async {
    final punto = state.posicion ?? _anclaQuieto;
    if (tiempoReal == null || punto == null) return;
    await tiempoReal!.reportar('trancon', {'estado': 'detenido'}, punto);
    if (!isClosed) emit(state.copyWith(preguntarVarado: false));
  }

  /// Cierra la pregunta o el agradecimiento del bus varado.
  void cerrarVarado() {
    if (!isClosed) emit(state.copyWith(preguntarVarado: false, varadoReportado: false));
  }

  /// «¿El T103 se desvió?» → «Sí»: se le sigue acompañando sin proponerle otra ruta.
  void elBusSeDesvio() {
    if (!isClosed && seguidor.estado.fase == Fase.aBordo) emit(state.copyWith(desvioDelBus: true));
  }

  /// Ya tocó el timbre (o gritó): se quita la pantalla completa.
  void yaPediLaParada() {
    if (!isClosed && state.pedirLaParada != null) emit(state.copyWith(pedirLaParada: () => null));
  }

  void _alBajar(Leg bus) {
    _rutaPrevista = null;
    if (state.rutaABordo != null) emit(state.copyWith(rutaABordo: () => null));
    _vigiaQuieto?.cancel();
    _vigiaQuieto = null;
    yaPediLaParada();
    _dejarDeCompartir();
    if (state.ocupacion != null) emit(state.copyWith(ocupacion: () => null));
    if (state.comoSePideAqui != null) emit(state.copyWith(comoSePideAqui: () => null));
    _busSabido = null;
    // En un momento seguro (ya abajo), una vez por viaje y solo en paraderos: en las estaciones para siempre.
    final enParadero = comoPedirLaParada(bus) != ComoPedirLaParada.paraSolo;
    if (enParadero && !_huboPregunta && tiempoReal != null && haySesion() && bus.ruta != null) {
      _huboPregunta = true;
      _paraderoPorResponder = bus;
      emit(state.copyWith(preguntarComoPediste: () => bus.hasta));
    }
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
    final ruta = rutaDelBus!;
    try {
      final viaje = _viajeCompartido;
      if (viaje != null && await tiempoReal!.moverViajeCompartido(viaje, punto)) return;
      final nuevo = await tiempoReal!.iniciarViajeCompartido(ruta, punto);
      if (state.compartiendo && !isClosed && rutaDelBus == ruta) {
        _viajeCompartido = nuevo;
        _rutaCompartida = ruta;
        if (!_contadoEsteBus) {
          _contadoEsteBus = true;
          await preferencia.sumarViajeCompartido(); // para «Tu impacto», solo en el teléfono
        }
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
    avisos.mostrar(aviso.titulo, aviso.texto, urgente: evento == EventoDelViaje.pideLaParada);
  }

  Future<void> terminar() async {
    _vigiaQuieto?.cancel();
    _vigiaQuieto = null;
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
      (titulo: 'Llegaste a ${actual.desde}', texto: 'Espera el ${actual.rutas.join(' o el ')}. Te avisamos antes de bajarte.'),
    EventoDelViaje.subiste => null,
    EventoDelViaje.bajateEnLaProxima => (
        titulo: comoPedirLaParada(actual) == ComoPedirLaParada.paraSolo
            ? 'Bájate en la próxima'
            : 'Bájate en el próximo paradero',
        texto: '${actual.hasta}. Ve acercándote a la puerta.',
      ),
    EventoDelViaje.pideLaParada => (
        titulo: textoDePedirLaParada(comoPedirLaParada(actual)),
        texto: 'Te bajas en el próximo paradero: ${actual.hasta}.',
      ),
    EventoDelViaje.bajateAqui => (titulo: 'Bájate aquí', texto: actual.hasta),
    EventoDelViaje.bajaste => switch (seguidor.estado.fase) {
        Fase.transbordo => (
            titulo: 'Ahora cambia de bus',
            texto: actual.indicacion ??
                'Camina hasta ${actual.hasta} y toma el ${seguidor.tramoSiguiente?.ruta ?? 'siguiente bus'}.',
          ),
        _ => (titulo: 'Camina a $destino', texto: 'Ya casi llegas.'),
      },
    EventoDelViaje.llegaste => (titulo: 'Llegaste a $destino', texto: 'Buen viaje con Karta.'),
    // A bordo, salirse del recorrido es casi siempre un desvío del bus (un trancón, una vía cerrada).
    EventoDelViaje.teDesviaste => seguidor.estado.fase == Fase.aBordo
        ? (titulo: '¿El ${actual.ruta ?? 'bus'} se desvió?', texto: 'Abre Karta para seguir el viaje o buscar otra ruta.')
        : (titulo: 'Te saliste del recorrido', texto: 'Abre Karta para buscar otra forma de llegar.'),
  };
}
