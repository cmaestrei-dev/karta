import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:karta/features/viaje/data/avisos.dart';
import 'package:karta/features/viaje/domain/seguidor_de_viaje.dart';
import 'package:karta/features/viaje/presentation/instrucciones.dart';
import 'package:karta/features/viaje/presentation/viaje_cubit.dart';
import 'package:latlong2/latlong.dart';

const _mLat = 1 / 110540;
const _mLon = 1 / 108900;
LatLng _p(double esteM, double norteM) => LatLng(10.40 + norteM * _mLat, -75.55 + esteM * _mLon);

/// Caminar a Bazurto, T103 hasta La Bodeguita pasando por La Popa y Chambacú, caminar a Bocagrande.
RouteOption _viaje() => RouteOption(
      resumen: 'T103',
      tiempoTotalMin: 20,
      distanciaCaminataM: 350,
      tramos: [
        Leg(modo: 'caminata', desde: 'Tu ubicación', hasta: 'Estación Bazurto', distanciaM: 200, duracionMin: 3,
            esperaMin: 0, puntos: [_p(0, 0), _p(0, 200)]),
        Leg(
          modo: 'bus', desde: 'Estación Bazurto', hasta: 'Estación La Bodeguita', distanciaM: 3000, duracionMin: 10,
          esperaMin: 5, ruta: 'T103', tipoRuta: 'troncal', puntos: [_p(0, 200), _p(3000, 200)],
          paradas: [
            for (final (n, x) in [('Bazurto', 0.0), ('La Popa', 1000.0), ('Chambacú', 2000.0), ('La Bodeguita', 3000.0)])
              (nombre: n, punto: _p(x, 200)),
          ],
        ),
        Leg(modo: 'caminata', desde: 'Estación La Bodeguita', hasta: 'Bocagrande', distanciaM: 150, duracionMin: 2,
            esperaMin: 0, puntos: [_p(3000, 200), _p(3000, 50)]),
      ],
      riesgo: const RiskSummary(score: 0, nivel: 'BAJO', totalIncidentes: 0),
    );

class _AvisosDePrueba extends Avisos {
  final mostrados = <String>[];
  final urgentes = <String>[];

  @override
  Future<bool> pedirPermiso() async => true;

  @override
  Future<void> mostrar(String titulo, String texto, {bool urgente = false}) async {
    mostrados.add(titulo);
    if (urgente) urgentes.add(titulo);
  }

  @override
  Future<void> limpiar() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada fase dice qué hacer ahora y qué viene después', () {
    final s = SeguidorDeViaje(_viaje());
    var i = instruccionDe(s, 'Bocagrande');
    expect(i.titulo, 'Camina a Estación Bazurto');
    expect(i.luego, 'sube al T103');

    s.actualizar(_p(0, 195));
    i = instruccionDe(s, 'Bocagrande');
    expect(i.titulo, 'Sube al T103');
    expect(i.detalle, 'en Estación Bazurto');
    expect(i.luego, 'bájate en Estación La Bodeguita · 3 paradas');

    s.actualizar(_p(300, 200));
    i = instruccionDe(s, 'Bocagrande');
    expect(i.titulo, 'Bájate en 3 paradas');
    expect(i.luego, 'camina 2 min hasta Bocagrande');
    expect(avanceEnParadas(s), (total: 3, pasadas: 0));

    s.actualizar(_p(2100, 200));
    expect(instruccionDe(s, 'Bocagrande').titulo, 'Bájate en la próxima');
    expect(avanceEnParadas(s), (total: 3, pasadas: 2));

    s.actualizar(_p(2900, 200));
    expect(instruccionDe(s, 'Bocagrande').titulo, 'Bájate aquí');
  });

  test('si el destino es la estación, a bordo no anuncia una caminata de 0 min', () {
    final base = _viaje();
    final hastaLaEstacion = RouteOption(
      resumen: base.resumen,
      tiempoTotalMin: 18,
      distanciaCaminataM: 200,
      tramos: [
        base.tramos[0],
        base.tramos[1],
        Leg(modo: 'caminata', desde: 'Estación La Bodeguita', hasta: 'Estación La Bodeguita', distanciaM: 0,
            duracionMin: 0, esperaMin: 0, puntos: [_p(3000, 200), _p(3000, 200)]),
      ],
      riesgo: base.riesgo,
    );
    final s = SeguidorDeViaje(hastaLaEstacion)
      ..actualizar(_p(0, 195))
      ..actualizar(_p(300, 200));
    expect(s.estado.fase, Fase.aBordo);
    expect(instruccionDe(s, 'Estación La Bodeguita').luego, isNull);
  });

  test('el viaje avisa con notificaciones en el orden del recorrido', () async {
    final avisos = _AvisosDePrueba();
    final posiciones = StreamController<LatLng>();
    final cubit = ViajeCubit(opcion: _viaje(), avisos: avisos, fuente: (_) => posiciones.stream);
    await cubit.iniciar();
    for (final p in [_p(0, 195), _p(300, 200), _p(1500, 200), _p(2100, 200), _p(2900, 200), _p(2990, 200), _p(3000, 60)]) {
      posiciones.add(p);
      await Future<void>.delayed(Duration.zero);
    }
    expect(avisos.mostrados, [
      'Llegaste a Estación Bazurto',
      'Bájate en la próxima',
      'Bájate aquí',
      'Camina a Bocagrande',
      'Llegaste a Bocagrande',
    ]);
    expect(cubit.state.estado.fase, Fase.llegaste);
    await cubit.close();
    await posiciones.close();
  });

  group('pedir la parada', () {
    /// El mismo viaje, pero el T103 deja al viajero en un paradero de Bocagrande, no en una estación.
    RouteOption hastaUnParadero({String ruta = 'T103'}) {
      final base = _viaje();
      return RouteOption(
        resumen: ruta,
        tiempoTotalMin: base.tiempoTotalMin,
        distanciaCaminataM: base.distanciaCaminataM,
        tramos: [
          base.tramos[0],
          Leg(
            modo: 'bus', desde: 'Estación Bazurto', hasta: 'Paradero Cra. 2 con Calle 5', distanciaM: 3000,
            duracionMin: 10, esperaMin: 5, ruta: ruta, tipoRuta: 'troncal', puntos: [_p(0, 200), _p(3000, 200)],
            paradas: [(nombre: 'Bazurto', punto: _p(0, 200)), (nombre: 'La Popa', punto: _p(1000, 200))],
          ),
          Leg(modo: 'caminata', desde: 'Paradero Cra. 2 con Calle 5', hasta: 'Bocagrande', distanciaM: 150,
              duracionMin: 2, esperaMin: 0, puntos: [_p(3000, 200), _p(3000, 50)]),
        ],
        riesgo: base.riesgo,
      );
    }

    test('en una estación el bus para solo; en un paradero, timbre en Transcaribe y grito en las busetas', () {
      expect(comoPedirLaParada(_viaje().tramos[1]), ComoPedirLaParada.paraSolo);
      expect(comoPedirLaParada(hastaUnParadero().tramos[1]), ComoPedirLaParada.timbre);
      expect(comoPedirLaParada(hastaUnParadero(ruta: 'B12').tramos[1]), ComoPedirLaParada.gritar);
    });

    test('en un paradero avisa a 500 m, pide el timbre a 200 m y dice «bájate aquí» a 60 m', () {
      final s = SeguidorDeViaje(hastaUnParadero())
        ..actualizar(_p(0, 195))
        ..actualizar(_p(300, 200));
      expect(s.actualizar(_p(2600, 200)), [EventoDelViaje.bajateEnLaProxima]);
      expect(instruccionDe(s, 'Bocagrande').titulo, 'Bájate en el próximo paradero');
      expect(instruccionDe(s, 'Bocagrande').detalle, 'Paradero Cra. 2 con Calle 5 · te avisamos cuándo tocar el timbre');
      expect(s.actualizar(_p(2820, 200)), [EventoDelViaje.pideLaParada]);
      expect(instruccionDe(s, 'Bocagrande').titulo, '¡Toca el timbre!');
      expect(s.actualizar(_p(2900, 200)), isEmpty); // a 100 m no repite nada
      expect(s.actualizar(_p(2950, 200)), [EventoDelViaje.bajateAqui]);
      expect(s.actualizar(_p(2990, 200)), [EventoDelViaje.bajaste]);
    });

    test('si el GPS brinca hasta muy cerca, igual pide la parada', () {
      final s = SeguidorDeViaje(hastaUnParadero())
        ..actualizar(_p(0, 195))
        ..actualizar(_p(300, 200));
      expect(s.actualizar(_p(2950, 200)), [EventoDelViaje.pideLaParada, EventoDelViaje.bajateAqui]);
    });

    test('la pantalla de pedir la parada sale con aviso urgente y se quita al decir que ya se pidió', () async {
      final avisos = _AvisosDePrueba();
      final posiciones = StreamController<LatLng>();
      final cubit = ViajeCubit(opcion: hastaUnParadero(), avisos: avisos, fuente: (_) => posiciones.stream);
      await cubit.iniciar();
      for (final p in [_p(0, 195), _p(300, 200), _p(2820, 200)]) {
        posiciones.add(p);
        await Future<void>.delayed(Duration.zero);
      }
      expect(cubit.state.pedirLaParada, ComoPedirLaParada.timbre);
      expect(avisos.urgentes, ['¡Toca el timbre!']);
      cubit.yaPediLaParada();
      expect(cubit.state.pedirLaParada, isNull);

      posiciones.add(_p(2990, 200)); // se bajó sin decir nada: también se quita
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.pedirLaParada, isNull);
      await cubit.close();
      await posiciones.close();
    });
  });

  test('a bordo, salirse del recorrido pregunta si el bus se desvió; al volver a la ruta se olvida', () async {
    final posiciones = StreamController<LatLng>();
    final avisos = _AvisosDePrueba();
    final cubit = ViajeCubit(opcion: _viaje(), avisos: avisos, fuente: (_) => posiciones.stream);
    await cubit.iniciar();
    Future<void> en(LatLng p) async {
      posiciones.add(p);
      await Future<void>.delayed(Duration.zero);
    }

    await en(_p(0, 195));
    await en(_p(300, 200));
    await en(_p(900, 600)); // 400 m fuera de la troncal, lejos de la bajada
    expect(cubit.state.estado.desviado, isTrue);
    expect(avisos.mostrados.last, '¿El T103 se desvió?');

    cubit.elBusSeDesvio();
    expect(cubit.state.desvioDelBus, isTrue);
    await en(_p(1200, 620));
    expect(cubit.state.desvioDelBus, isTrue); // sigue desviado

    await en(_p(1500, 200)); // volvió a su recorrido
    expect((cubit.state.estado.desviado, cubit.state.desvioDelBus), (false, false));
    expect(cubit.state.estado.fase, Fase.aBordo);
    await cubit.close();
    await posiciones.close();
  });

  test('el lector de pantalla no lee doble puntuación', () {
    expect(frase('¡Toca el timbre!', 'Te bajas en el próximo paradero'), '¡Toca el timbre! Te bajas en el próximo paradero');
    expect(frase('Sube al T103', 'en Estación Bazurto'), 'Sube al T103, en Estación Bazurto');
    expect(frase('Camina a Bazurto', '350 m · 5 min a pie'), 'Camina a Bazurto. 350 m · 5 min a pie');
  });
}
