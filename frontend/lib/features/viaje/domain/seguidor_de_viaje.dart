import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/geometria.dart';
import '../../trip/domain/trip_models.dart';

/// En qué parte del viaje va el viajero.
enum Fase { caminandoALaParada, esperando, aBordo, transbordo, caminandoAlDestino, llegaste }

/// Lo que acaba de pasar, para avisar una sola vez (vibración, notificación, voz).
enum EventoDelViaje { llegasteALaParada, subiste, bajateEnLaProxima, bajateAqui, bajaste, llegaste, teDesviaste }

class EstadoDelViaje extends Equatable {
  final Fase fase;

  /// Índice del tramo actual en [RouteOption.tramos].
  final int tramo;

  /// Metros que faltan para terminar el tramo actual (hasta la parada, la bajada o el destino).
  final double faltaDelTramoM;

  /// En bus por la troncal: cuántas estaciones faltan hasta la de bajada (la de bajada cuenta). Null sin estaciones.
  final int? paradasQueFaltan;

  /// Minutos estimados hasta el destino, con las esperas que faltan.
  final int minutosRestantes;

  /// Está lejos del recorrido: conviene recalcular.
  final bool desviado;

  const EstadoDelViaje({
    required this.fase,
    required this.tramo,
    required this.faltaDelTramoM,
    required this.paradasQueFaltan,
    required this.minutosRestantes,
    this.desviado = false,
  });

  @override
  List<Object?> get props => [fase, tramo, faltaDelTramoM, paradasQueFaltan, minutosRestantes, desviado];
}

/// Sigue un viaje con las posiciones del GPS: decide en qué fase va y qué avisar. No sabe nada de pantallas ni
/// de permisos; solo recibe posiciones y devuelve el estado y los eventos de cada una.
class SeguidorDeViaje {
  /// Más cerca que esto del final de una caminata se considera que se llegó.
  static const llegadaM = 40.0;

  /// Se da por subido al bus cuando la posición avanza esto sobre la ruta desde la parada…
  static const avanceParaSubidoM = 150.0;

  /// …sin alejarse de la línea más que esto (el GPS de un bus en movimiento se desvía unos metros).
  static const anchoDeLaRutaM = 70.0;

  /// Sin estaciones (vía mixta), «bájate en la próxima» suena a esta distancia de la bajada.
  static const avisoSinParadasM = 500.0;

  /// «Bájate aquí» suena a esta distancia de la bajada.
  static const bajateAquiM = 150.0;

  /// Más lejos que esto del recorrido, el viajero se desvió.
  static const desvioM = 250.0;

  final RouteOption opcion;
  final List<double> _largos;
  late EstadoDelViaje _estado;

  /// Metros avanzados en el bus actual: solo crece, para que el GPS no lo haga retroceder.
  double _avanceEnBus = 0;
  bool _avisoProxima = false;
  bool _avisoAqui = false;
  bool _desviadoAvisado = false;

  SeguidorDeViaje(this.opcion) : _largos = [for (final t in opcion.tramos) _largo(t.puntos)] {
    final primero = opcion.tramos.first;
    _estado = EstadoDelViaje(
      fase: primero.esCaminata ? _faseDeCaminata(0) : Fase.esperando,
      tramo: 0,
      faltaDelTramoM: _largos.first,
      paradasQueFaltan: null,
      minutosRestantes: opcion.tiempoTotalMin,
    );
  }

  EstadoDelViaje get estado => _estado;
  Leg get tramoActual => opcion.tramos[_estado.tramo];

  /// La siguiente instrucción después de la actual («Luego bájate en Bocagrande», «Luego camina 3 min»).
  Leg? get tramoSiguiente => _estado.tramo + 1 < opcion.tramos.length ? opcion.tramos[_estado.tramo + 1] : null;

  /// Procesa una posición nueva y devuelve los eventos que produjo (normalmente ninguno).
  List<EventoDelViaje> actualizar(LatLng posicion) {
    final eventos = <EventoDelViaje>[];
    if (_estado.fase == Fase.llegaste) return eventos;

    // Puede saltar más de una fase con una sola posición (p. ej. el viaje empieza en la parada).
    for (var vueltas = 0; vueltas < opcion.tramos.length + 2; vueltas++) {
      final antes = _estado;
      _avanzar(posicion, eventos);
      if (_estado.fase == antes.fase && _estado.tramo == antes.tramo) break;
    }
    return eventos;
  }

  void _avanzar(LatLng posicion, List<EventoDelViaje> eventos) {
    final k = _estado.tramo;
    final tramo = opcion.tramos[k];
    switch (_estado.fase) {
      case Fase.caminandoALaParada || Fase.transbordo || Fase.caminandoAlDestino:
        final fin = tramo.puntos.isNotEmpty ? tramo.puntos.last : posicion;
        final falta = const Distance().as(LengthUnit.Meter, posicion, fin);
        final desvio = proyectarEnLinea(posicion, tramo.puntos).distanciaM;
        if (falta <= llegadaM || (k + 1 < opcion.tramos.length && _yaEnElBus(posicion, k + 1))) {
          if (k + 1 >= opcion.tramos.length) {
            eventos.add(EventoDelViaje.llegaste);
            _estado = _nuevo(Fase.llegaste, k, 0);
          } else {
            eventos.add(EventoDelViaje.llegasteALaParada);
            _iniciarBus(k + 1);
          }
          return;
        }
        _estado = _nuevo(_estado.fase, k, falta, desviado: _marcarDesvio(desvio > desvioM, eventos));
      case Fase.esperando:
        if (_yaEnElBus(posicion, k)) {
          eventos.add(EventoDelViaje.subiste);
          _estado = _nuevo(Fase.aBordo, k, _largos[k] - _avanceEnBus, paradas: _paradasQueFaltan(k));
        } else {
          _estado = _nuevo(Fase.esperando, k, _largos[k]);
        }
      case Fase.aBordo:
        final p = proyectarEnLinea(posicion, tramo.puntos, desdeM: math.max(0, _avanceEnBus - 200));
        if (p.distanciaM <= anchoDeLaRutaM * 2) _avanceEnBus = math.max(_avanceEnBus, p.avanceM);
        final falta = math.max(0.0, _largos[k] - _avanceEnBus);
        final paradas = _paradasQueFaltan(k);
        final proxima = paradas != null ? paradas <= 1 : falta <= avisoSinParadasM;
        if (proxima && !_avisoProxima && falta > bajateAquiM) {
          _avisoProxima = true;
          eventos.add(EventoDelViaje.bajateEnLaProxima);
        }
        if (falta <= bajateAquiM && !_avisoAqui) {
          _avisoAqui = true;
          eventos.add(EventoDelViaje.bajateAqui);
        }
        // Se bajó: llegó a la bajada, o la pasó y se alejó de la ruta.
        final seBajo = falta <= llegadaM || (falta <= 400 && p.distanciaM > anchoDeLaRutaM * 2);
        if (seBajo) {
          eventos.add(EventoDelViaje.bajaste);
          final siguiente = k + 1;
          _estado = _nuevo(_faseDeCaminata(siguiente), siguiente, _largos[siguiente]);
          return;
        }
        _estado = _nuevo(Fase.aBordo, k, falta, paradas: paradas,
            desviado: _marcarDesvio(p.distanciaM > desvioM && falta > 400, eventos));
      case Fase.llegaste:
        break;
    }
  }

  /// Subió si la posición avanzó sobre la ruta desde la parada sin salirse de ella.
  bool _yaEnElBus(LatLng posicion, int k) {
    final tramo = opcion.tramos[k];
    if (tramo.esCaminata) return false;
    final p = proyectarEnLinea(posicion, tramo.puntos);
    return p.distanciaM <= anchoDeLaRutaM && p.avanceM >= avanceParaSubidoM;
  }

  void _iniciarBus(int k) {
    _avanceEnBus = 0;
    _avisoProxima = false;
    _avisoAqui = false;
    _estado = _nuevo(Fase.esperando, k, _largos[k]);
  }

  /// Estaciones que faltan, sin contar las que el bus ya pasó (30 m de margen); la de bajada cuenta.
  /// Null si la bajada no es una estación: entonces los avisos van por distancia.
  int? _paradasQueFaltan(int k) {
    final tramo = opcion.tramos[k];
    if (!tramo.bajaEnEstacion) return null;
    var faltan = 0;
    for (final parada in tramo.paradas) {
      if (proyectarEnLinea(parada.punto, tramo.puntos).avanceM > _avanceEnBus + 30) faltan++;
    }
    return faltan;
  }

  Fase _faseDeCaminata(int k) {
    final hayBusDespues = opcion.tramos.skip(k + 1).any((t) => !t.esCaminata);
    final hayBusAntes = opcion.tramos.take(k).any((t) => !t.esCaminata);
    if (!hayBusDespues) return Fase.caminandoAlDestino;
    return hayBusAntes ? Fase.transbordo : Fase.caminandoALaParada;
  }

  /// El desvío se avisa una vez; si vuelve al recorrido, se puede volver a avisar.
  bool _marcarDesvio(bool desviado, List<EventoDelViaje> eventos) {
    if (desviado && !_desviadoAvisado) eventos.add(EventoDelViaje.teDesviaste);
    _desviadoAvisado = desviado;
    return desviado;
  }

  EstadoDelViaje _nuevo(Fase fase, int k, double falta, {int? paradas, bool desviado = false}) => EstadoDelViaje(
        fase: fase,
        tramo: k,
        faltaDelTramoM: falta,
        paradasQueFaltan: paradas,
        minutosRestantes: _minutosRestantes(fase, k, falta),
        desviado: desviado,
      );

  /// Lo que falta del tramo actual (en proporción a su duración, con la espera si aún no sube) más los tramos
  /// siguientes completos.
  int _minutosRestantes(Fase fase, int k, double falta) {
    if (fase == Fase.llegaste) return 0;
    final tramo = opcion.tramos[k];
    final fraccion = _largos[k] <= 0 ? 0.0 : (falta / _largos[k]).clamp(0.0, 1.0);
    var minutos = tramo.duracionMin * fraccion + (fase == Fase.esperando ? tramo.esperaMin : 0);
    for (final siguiente in opcion.tramos.skip(k + 1)) {
      minutos += siguiente.duracionMin + siguiente.esperaMin;
    }
    return minutos.ceil();
  }

  /// Con la misma medida que el avance (la proyección local de [proyectarEnLinea]): si no, en 11 km la diferencia
  /// entre las dos medidas supera el margen de llegada.
  static double _largo(List<LatLng> puntos) => puntos.isEmpty ? 0 : proyectarEnLinea(puntos.first, puntos).largoM;
}
