import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/mapeo/domain/mapeo_models.dart';
import 'package:karta/features/mapeo/domain/viaje_de_mapeo.dart';
import 'package:karta/features/mapeo/presentation/marcar_paradero_screen.dart';
import 'package:latlong2/latlong.dart';

/// «Marca este paradero»: lo que la app entiende de los paraderos de una ruta.
void main() {
  final json = {
    'ruta': 'A107', 'ubicados': 2, 'total': 4,
    'sentidos': [
      {
        'sentido': 'ida', 'hacia': 'Blas de Lezo',
        'paraderos': [
          {'id': 'A107-ida-01', 'orden': 1, 'nombre': 'Transferencia Santa Lucia', 'estado': 'estacion',
           'latitud': 10.3952, 'longitud': -75.478},
          {'id': 'A107-ida-02', 'orden': 2, 'nombre': 'Chinatown', 'estado': 'sin_ubicar'},
          {'id': 'A107-ida-03', 'orden': 3, 'nombre': 'Clínica Blas de Lezo', 'estado': 'por_confirmar',
           'marca': {'id': 'm1', 'paradero': 'A107-ida-03', 'latitud': 10.39, 'longitud': -75.48, 'apoyo': 1,
                     'estado': 'por_confirmar', 'mia': false, 'mi_voto': null}},
          {'id': 'A107-ida-04', 'orden': 4, 'nombre': 'Kr 68 entre Cl 25 y 24', 'estado': 'direccion',
           'latitud': 10.388, 'longitud': -75.49},
        ],
      },
    ],
    'pistas': [{'latitud': 10.3901, 'longitud': -75.4801, 'subidas': 4}],
  };

  test('lee los paraderos por sentido, su estado y la marca por confirmar', () {
    final datos = ParaderosDeRuta.fromJson(json);
    final ida = datos.sentidos.single;
    expect(ida.etiqueta, 'Ida · hacia Blas de Lezo');
    expect(ida.paraderos.map((p) => p.estado), [
      EstadoDeParadero.estacion, EstadoDeParadero.sinUbicar, EstadoDeParadero.porConfirmar, EstadoDeParadero.direccion,
    ]);
    expect(ida.paraderos[2].marca!.apoyo, 1);
    expect(datos.pistas.single.subidas, 4);
  });

  test('para marcar uno, se empieza entre sus vecinos ya ubicados', () {
    final ida = ParaderosDeRuta.fromJson(json).sentidos.single;
    final vecinos = ida.vecinos(ida.paraderos[1]);
    expect(vecinos.antes!.nombre, 'Transferencia Santa Lucia');
    expect(vecinos.despues!.nombre, 'Kr 68 entre Cl 25 y 24'); // el por confirmar aún no cuenta
    final inicio = MarcarParaderoScreen.inicio(vecinos, const []);
    expect(inicio.latitude, closeTo((10.3952 + 10.388) / 2, 1e-9));
    // Con el recorrido, a mitad de camino sobre él: entre el punto más cercano a cada vecino.
    const recorrido = [LatLng(10.3952, -75.478), LatLng(10.40, -75.47), LatLng(10.41, -75.47), LatLng(10.388, -75.49)];
    expect(MarcarParaderoScreen.inicio(vecinos, recorrido), const LatLng(10.40, -75.47));
    expect(MarcarParaderoScreen.inicio((antes: null, despues: null), const [LatLng(1, 1), LatLng(2, 2), LatLng(3, 3)]),
        const LatLng(2, 2));
  });

  test('en un viaje de mapeo, la lista sigue al bus y solo anota los que faltan', () {
    final ida = ParaderosDeRuta.fromJson(json).sentidos.single.paraderos;
    // Se subió en Santa Lucía (el ya ubicado más cercano): sigue Chinatown.
    final subio = ViajeDeMapeo.dondeSubio(ida, const LatLng(10.3953, -75.4781));
    expect(subio, 0);
    var viaje = ViajeDeMapeo.desde(ida, subio);
    expect(viaje.proximo!.nombre, 'Chinatown');
    expect(viaje.faltan, 2);

    const aqui = LatLng(10.3931, -75.4802);
    viaje = viaje.paroAqui(aqui);
    expect(viaje.paradas, [const ParadaDelViaje(paradero: 'A107-ida-02', punto: aqui)]);
    // La Clínica no paró: no se anota. Y deshacer vuelve a ella.
    viaje = viaje.noParo();
    expect(viaje.proximo!.id, 'A107-ida-04');
    viaje = viaje.deshacer();
    expect(viaje.proximo!.id, 'A107-ida-03');
    viaje = viaje.noParo();
    // El que sigue ya está en el mapa: lejos no pasa nada; al llegar a él, se pasa solo.
    expect(viaje.pasoPor(const LatLng(10.40, -75.47)), viaje);
    viaje = viaje.pasoPor(const LatLng(10.3881, -75.4901));
    expect(viaje.termino, isTrue);
    expect(viaje.paradas.single.toJson(), {'paradero': 'A107-ida-02', 'latitud': 10.3931, 'longitud': -75.4802});
    // Deshacer el «paró aquí» quita lo anotado.
    expect(ViajeDeMapeo.desde(ida, 0).paroAqui(aqui).deshacer().paradas, isEmpty);
  });

  test('el bus está detenido si casi no se movió en los últimos segundos', () {
    final t0 = DateTime(2026, 10, 26, 8);
    const p = LatLng(10.39, -75.48);
    final quieto = [for (var s = 0; s <= 8; s += 2) (t0.add(Duration(seconds: s)), p)];
    expect(estaDetenido(quieto, t0.add(const Duration(seconds: 8))), isTrue);
    final andando = [for (var s = 0; s <= 8; s += 2) (t0.add(Duration(seconds: s)), LatLng(10.39 + s * 0.0001, -75.48))];
    expect(estaDetenido(andando, t0.add(const Duration(seconds: 8))), isFalse);
    // Recién empieza: no hay con qué saberlo.
    expect(estaDetenido(quieto.sublist(3), t0.add(const Duration(seconds: 8))), isFalse);
  });
}
