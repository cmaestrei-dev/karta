import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:karta/features/viaje/domain/seguidor_de_viaje.dart';
import 'package:latlong2/latlong.dart';

/// Metros → grados a la latitud de Cartagena (aprox.).
const _mLat = 1 / 110540;
const _mLon = 1 / 108900;

LatLng _p(double esteM, double norteM) => LatLng(10.40 + norteM * _mLat, -75.55 + esteM * _mLon);

Leg _caminata(LatLng a, LatLng b, int minutos) => Leg(
    modo: 'caminata', desde: '', hasta: '', distanciaM: 0, duracionMin: minutos, esperaMin: 0, puntos: [a, b]);

/// Un viaje: caminar 200 m al norte, bus 3 km al este por una recta con 4 estaciones, caminar 150 m al sur.
RouteOption _viaje({bool conParadas = true}) {
  final subida = _p(0, 200);
  final bajada = _p(3000, 200);
  return RouteOption(
    resumen: 'T103',
    tiempoTotalMin: 20,
    distanciaCaminataM: 350,
    tramos: [
      _caminata(_p(0, 0), subida, 3),
      Leg(
        modo: 'bus', desde: 'Estación A', hasta: 'Estación D', distanciaM: 3000, duracionMin: 10, esperaMin: 5,
        ruta: 'T103', tipoRuta: 'troncal', puntos: [subida, _p(1500, 200), bajada],
        paradas: conParadas
            ? [for (final (n, x) in [('A', 0.0), ('B', 1000.0), ('C', 2000.0), ('D', 3000.0)]) (nombre: n, punto: _p(x, 200))]
            : const [],
      ),
      _caminata(bajada, _p(3000, 50), 2),
    ],
    riesgo: const RiskSummary(score: 0, nivel: 'BAJO', totalIncidentes: 0),
  );
}

/// Recorre las posiciones y junta los eventos en orden.
List<EventoDelViaje> _recorrer(SeguidorDeViaje s, Iterable<LatLng> posiciones) =>
    [for (final p in posiciones) ...s.actualizar(p)];

Iterable<LatLng> _linea(LatLng a, LatLng b, {int pasos = 30, double ruidoM = 0}) sync* {
  for (var i = 0; i <= pasos; i++) {
    final t = i / pasos;
    final ruido = ruidoM * (i.isEven ? 1 : -1);
    yield LatLng(a.latitude + (b.latitude - a.latitude) * t + ruido * _mLat, a.longitude + (b.longitude - a.longitude) * t);
  }
}

void main() {
  test('un viaje completo avanza solo y avisa antes de bajarse', () {
    final s = SeguidorDeViaje(_viaje());
    expect(s.estado.fase, Fase.caminandoALaParada);

    final eventos = <EventoDelViaje>[];
    eventos.addAll(_recorrer(s, _linea(_p(0, 0), _p(0, 195))));       // camina a la parada
    expect(s.estado.fase, Fase.esperando);
    eventos.addAll(_recorrer(s, [_p(5, 205), _p(-8, 190), _p(3, 200)])); // espera: el GPS baila
    expect(s.estado.fase, Fase.esperando, reason: 'esperar en la parada no es subirse');

    eventos.addAll(_recorrer(s, _linea(_p(0, 200), _p(1500, 200), ruidoM: 15)));
    expect(s.estado.fase, Fase.aBordo);
    expect(s.estado.paradasQueFaltan, 2, reason: 'quedan C y D');

    eventos.addAll(_recorrer(s, _linea(_p(1500, 200), _p(2995, 200), pasos: 60, ruidoM: 15)));
    expect(s.estado.fase, Fase.caminandoAlDestino);
    eventos.addAll(_recorrer(s, _linea(_p(3000, 200), _p(3000, 55))));
    expect(s.estado.fase, Fase.llegaste);
    expect(s.estado.minutosRestantes, 0);

    expect(eventos, [
      EventoDelViaje.llegasteALaParada,
      EventoDelViaje.subiste,
      EventoDelViaje.bajateEnLaProxima,
      EventoDelViaje.bajateAqui,
      EventoDelViaje.bajaste,
      EventoDelViaje.llegaste,
    ]);
  });

  test('«bájate en la próxima» suena al pasar la penúltima estación', () {
    final s = SeguidorDeViaje(_viaje());
    _recorrer(s, [_p(0, 195), ..._linea(_p(0, 200), _p(1900, 200))]);
    expect(s.estado.paradasQueFaltan, 2);
    final eventos = _recorrer(s, _linea(_p(1900, 200), _p(2100, 200), pasos: 8));
    expect(eventos, [EventoDelViaje.bajateEnLaProxima]);
    expect(s.estado.paradasQueFaltan, 1);
  });

  test('sin estaciones (vía mixta) avisa a 500 m de la bajada', () {
    final s = SeguidorDeViaje(_viaje(conParadas: false));
    _recorrer(s, [_p(0, 195), ..._linea(_p(0, 200), _p(2400, 200))]);
    expect(s.estado.paradasQueFaltan, isNull);
    final eventos = _recorrer(s, _linea(_p(2400, 200), _p(2600, 200), pasos: 8));
    expect(eventos, [EventoDelViaje.bajateEnLaProxima]);
  });

  test('si empieza en la parada, ya está esperando el bus', () {
    final s = SeguidorDeViaje(_viaje());
    expect(s.actualizar(_p(2, 198)), [EventoDelViaje.llegasteALaParada]);
    expect(s.estado.fase, Fase.esperando);
    expect(s.estado.minutosRestantes, 5 + 10 + 2);
  });

  test('si se aleja del recorrido lo avisa una vez', () {
    final s = SeguidorDeViaje(_viaje());
    expect(s.actualizar(_p(400, 50)), [EventoDelViaje.teDesviaste]);
    expect(s.estado.desviado, isTrue);
    expect(s.actualizar(_p(420, 60)), isEmpty);
    expect(s.actualizar(_p(0, 60)), isEmpty);
    expect(s.estado.desviado, isFalse);
  });

  test('si se baja antes de tiempo pasa a caminar', () {
    final s = SeguidorDeViaje(_viaje());
    _recorrer(s, [_p(0, 195), ..._linea(_p(0, 200), _p(2800, 200))]);
    expect(s.estado.fase, Fase.aBordo);
    // Se baja a 200 m de la estación y camina hacia el sur, lejos de la ruta.
    final eventos = _recorrer(s, [_p(2800, 120), _p(2810, 40)]);
    expect(eventos, contains(EventoDelViaje.bajaste));
    expect(s.estado.fase, Fase.caminandoAlDestino);
  });

  test('si se baja en un paradero de la vía, no cuenta estaciones: avisa por distancia', () {
    // Como la X105: pasa por estaciones en el camino pero se baja en un paradero 1 km después de la última.
    final subida = _p(0, 200);
    final bajada = _p(3000, 200);
    final opcion = RouteOption(
      resumen: 'X105',
      tiempoTotalMin: 20,
      distanciaCaminataM: 0,
      tramos: [
        Leg(
          modo: 'bus', desde: 'Paradero', hasta: 'Paradero Cra. 3 con Calle 9', distanciaM: 3000, duracionMin: 10,
          esperaMin: 5, ruta: 'X105', tipoRuta: 'pretroncal', puntos: [subida, bajada],
          paradas: [(nombre: 'Lo Amador', punto: _p(1000, 200)), (nombre: 'Centro', punto: _p(2000, 200))],
        ),
      ],
      riesgo: const RiskSummary(score: 0, nivel: 'BAJO', totalIncidentes: 0),
    );
    final s = SeguidorDeViaje(opcion);
    _recorrer(s, _linea(subida, _p(2100, 200)));
    expect(s.estado.paradasQueFaltan, isNull, reason: 'pasó la última estación pero aún falta 0,9 km');
    expect(_recorrer(s, _linea(_p(2100, 200), _p(2400, 200), pasos: 6)), isEmpty);
    expect(_recorrer(s, _linea(_p(2400, 200), _p(2600, 200), pasos: 6)), [EventoDelViaje.bajateEnLaProxima]);
  });
}
