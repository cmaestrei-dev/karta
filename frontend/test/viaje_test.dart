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

  @override
  Future<bool> pedirPermiso() async => true;

  @override
  Future<void> mostrar(String titulo, String texto) async => mostrados.add(titulo);

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
}
