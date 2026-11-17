import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/design/tema.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:karta/features/viaje/domain/plano_de_estacion.dart';
import 'package:karta/features/viaje/presentation/dibujo_del_plano.dart';
import 'package:latlong2/latlong.dart';

/// Un punto a `este` metros al este y `norte` al norte de la estación.
LatLng m(double este, [double norte = 0]) => LatLng(10.3995 + norte / 111320, -75.5 + este / 109540);

Leg tramo({List<Vagon> vagones = const []}) => Leg(
      modo: 'bus',
      desde: 'Estación Madre Bernarda',
      hasta: 'Estación La Bodeguita',
      distanciaM: 5000,
      duracionMin: 15,
      esperaMin: 5,
      ruta: 'T103',
      modulo: 'A1',
      puntos: [m(0), m(-800)],
      paradas: [(nombre: 'Madre Bernarda', punto: m(0)), (nombre: 'La Castellana', punto: m(-800))],
      vagones: vagones,
    );

// El A, donde para el bus, queda al oeste, hacia el Centro; el B, 50 m al este, hacia el Portal.
final doble = tramo(vagones: [
  (letra: 'A', hacia: 'el Centro', punto: m(-25)),
  (letra: 'B', hacia: 'el Portal', punto: m(25)),
]);

void main() {
  test('en el vagón de enfrente dice hacia qué extremo está el del bus', () {
    final plano = PlanoDeEstacion.de(doble, m(22, 4))!;
    expect(plano.donde, DondeEstas.enElOtro);
    expect(plano.posicion, closeTo(0.06, 0.01)); // 3 m del centro del B, en 50 m de eje
    expect(plano.leyenda('T103'), 'Parece que estás en el vagón B: el A queda en el extremo hacia el Centro.');
    expect(plano.tuyoALaIzquierda, isTrue);
  });

  test('en el vagón del bus lo confirma, y cerca de la mitad no se atreve a decir', () {
    expect(PlanoDeEstacion.de(doble, m(-20))!.leyenda('T103'), 'Parece que ya estás en el vagón A, donde para el T103.');
    final enLaMitad = PlanoDeEstacion.de(doble, m(3))!;
    expect(enLaMitad.donde, DondeEstas.enLaMitad);
    expect(enLaMitad.leyenda('T103'), isNull);
  });

  test('lejos de la estación o sin ubicación muestra el plano sin el viajero', () {
    for (final yo in [m(0, 60), m(200), null]) {
      final plano = PlanoDeEstacion.de(doble, yo)!;
      expect((plano.donde, plano.posicion), (DondeEstas.noSeSabe, null));
    }
  });

  test('sin los dos vagones o sin subir en una estación no hay plano', () {
    expect(PlanoDeEstacion.de(tramo(), m(0)), isNull);
    final enLaCalle = Leg(
      modo: 'bus', desde: 'Paradero', hasta: 'Estación La Bodeguita', distanciaM: 5000, duracionMin: 15, esperaMin: 5,
      puntos: [m(400), m(-800)], paradas: [(nombre: 'Madre Bernarda', punto: m(0))], vagones: doble.vagones);
    expect(PlanoDeEstacion.de(enLaCalle, m(0)), isNull);
  });

  test('los vagones llegan de la API, el del bus primero', () {
    final leg = Leg.fromJson({
      'modo': 'bus', 'desde': 'a', 'hasta': 'b', 'distancia_m': 1, 'duracion_min': 1,
      'vagones': [
        {'letra': 'A', 'hacia': 'el Centro', 'latitud': 10.4, 'longitud': -75.5},
        {'letra': 'B', 'hacia': 'el Portal', 'latitud': 10.39, 'longitud': -75.49},
      ],
      'geometria': {'type': 'LineString', 'coordinates': []},
    });
    expect([for (final v in leg.vagones) (v.letra, v.hacia)], [('A', 'el Centro'), ('B', 'el Portal')]);
    expect(leg.vagones.first.punto, const LatLng(10.4, -75.5));
  });

  pruebasDelDibujo();
}

// El dibujo, en el tema de la app.
Future<void> dibujar(WidgetTester tester, LatLng? yo) => tester.pumpWidget(MaterialApp(
      theme: TemaBahia.oscuro,
      home: Scaffold(body: DibujoDelPlano(plano: PlanoDeEstacion.de(doble, yo)!, bus: doble)),
    ));

void pruebasDelDibujo() {
  testWidgets('el dibujo pone cada vagón donde está en el mapa y dice dónde está el viajero', (tester) async {
    await dibujar(tester, m(22));
    // El A, hacia el Centro, queda al oeste: a la izquierda, como en el mapa.
    expect(tester.getCenter(find.text('Vagón A')).dx, lessThan(tester.getCenter(find.text('Vagón B')).dx));
    expect(tester.getCenter(find.text('Hacia el Centro')).dx, lessThan(tester.getCenter(find.text('Hacia el Portal')).dx));
    expect(find.text('Parece que estás en el vagón B: el A queda en el extremo hacia el Centro.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Plano de la estación: el vagón A, donde para el T103')), findsOneWidget);
  });

  testWidgets('sin saber dónde está el viajero, solo los vagones', (tester) async {
    await dibujar(tester, null);
    expect(find.text('Vagón A'), findsOneWidget);
    expect(find.textContaining('Parece'), findsNothing);
  });
}
