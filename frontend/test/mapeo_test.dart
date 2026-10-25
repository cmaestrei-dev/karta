import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/mapeo/domain/mapeo_models.dart';
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
    expect(MarcarParaderoScreen.inicio((antes: null, despues: null), const [LatLng(1, 1), LatLng(2, 2), LatLng(3, 3)]),
        const LatLng(2, 2));
  });
}
