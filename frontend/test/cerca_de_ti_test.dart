import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karta/core/api_client.dart';
import 'package:karta/features/trip/data/trip_repository.dart';
import 'package:karta/features/trip/presentation/cubit/trip_cubits.dart';
import 'package:latlong2/latlong.dart';

/// «Cerca de ti»: estaciones y, además, las rutas que pasan cerca con dónde tomarlas (D16).
void main() {
  const estacion = {
    'id': 'la-castellana', 'nombre': 'La Castellana', 'latitud': 10.3944, 'longitud': -75.4861,
    'rutas': ['T101'], 'distancia_m': 900, 'caminata_m': 1170, 'caminata_min': 16,
  };
  const a107 = {
    'ruta': 'A107', 'nombre': 'Blas de Lezo - Santa Lucía', 'tipo': 'alimentadora',
    'paradero': 'Paradero Av. John F. Kennedy con Calle 18', 'latitud': 10.39, 'longitud': -75.49,
    'distancia_m': 90, 'caminata_m': 117, 'caminata_min': 2,
  };

  NearbyStopsCubit cubit({required bool rutasFallan}) => NearbyStopsCubit(
        repository: TripRepository(
          api: ApiClient(token: () => null, client: MockClient((pedido) async {
            if (pedido.url.path.endsWith('/stops/nearby')) return http.Response(jsonEncode([estacion]), 200);
            if (rutasFallan) return http.Response('{"detail": "Error interno"}', 500);
            return http.Response(jsonEncode([a107]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
          })),
        ),
      );

  test('muestra las estaciones y las rutas que pasan cerca, con su paradero', () async {
    final c = cubit(rutasFallan: false);
    await c.load(const LatLng(10.39, -75.49));
    final estado = c.state as NearbyStopsLoaded;
    expect(estado.estaciones.single.nombre, 'La Castellana');
    expect(estado.rutas.single.paradero, 'Paradero Av. John F. Kennedy con Calle 18');
    expect(estado.rutas.single.caminataMin, 2);
  });

  test('si las rutas no se pueden consultar, igual muestra las estaciones', () async {
    final c = cubit(rutasFallan: true);
    await c.load(const LatLng(10.39, -75.49));
    final estado = c.state as NearbyStopsLoaded;
    expect(estado.estaciones, hasLength(1));
    expect(estado.rutas, isEmpty);
  });
}
