import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/incidents/domain/models/incident_models.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:karta/features/trip/presentation/screens/route_page_screen.dart';
import 'package:karta/features/trip/presentation/widgets/tarjeta_de_opcion.dart';
import 'package:latlong2/latlong.dart';

Leg _caminata(List<LatLng> puntos, {int metros = 300}) => Leg(
    modo: 'caminata', desde: 'A', hasta: 'B', distanciaM: metros, duracionMin: 4, esperaMin: 0, puntos: puntos);

Leg _bus(String ruta, List<LatLng> puntos, {String desde = 'Estación Bazurto', String hasta = 'Estación Centro'}) =>
    Leg(modo: 'bus', desde: desde, hasta: hasta, distanciaM: 5000, duracionMin: 14, esperaMin: 5, ruta: ruta,
        tipoRuta: 'troncal', puntos: puntos);

RouteOption _opcion(int minutos, List<Leg> tramos, {int reportes = 0}) => RouteOption(
      resumen: 'x',
      tiempoTotalMin: minutos,
      distanciaCaminataM: 500,
      transbordos: tramos.where((t) => !t.esCaminata).length - 1 < 0 ? 0 : tramos.where((t) => !t.esCaminata).length - 1,
      tramos: tramos,
      riesgo: RiskSummary(score: reportes * 5, nivel: reportes == 0 ? 'BAJO' : 'MEDIO', totalIncidentes: reportes),
    );

const _a = LatLng(10.4139, -75.5244);
const _b = LatLng(10.4200, -75.5400);
const _c = LatLng(10.4236, -75.5480);

void main() {
  test('lee transbordos, criterio, salida y aviso de la API', () {
    final s = RouteSuggestions.fromJson({
      'opciones': [],
      'criterio': 'sin_transbordo',
      'salida': '2026-10-23T23:30:00-05:00',
      'aviso': 'A esta hora no pasa ninguna ruta de Transcaribe que te sirva.',
      'nota': 'n',
      'fuente': 'f',
    });
    expect(s.criterio, CriterioDeRuta.sinTransbordo);
    expect(s.salida, DateTime.utc(2026, 10, 24, 4, 30));
    expect(s.aviso, startsWith('A esta hora'));
    expect(CriterioDeRuta.deApi('otra'), CriterioDeRuta.rapida);
  });

  test('con transbordo se sabe dónde se cambia de bus', () {
    final opcion = _opcion(40, [
      _caminata([_a, _a]),
      _bus('X106', [_a, _b], hasta: 'Estación La Castellana'),
      _caminata([_b, _b], metros: 0),
      _bus('T103', [_b, _c], desde: 'Estación La Castellana'),
      _caminata([_c, _c]),
    ]);
    expect(opcion.buses.map((b) => b.ruta), ['X106', 'T103']);
    expect(opcion.puntoDeTransbordo, 'Estación La Castellana');
  });

  test('cada burbuja dice lo que distingue a su opción', () {
    final rapida = _opcion(26, [_caminata([_a, _a]), _bus('T103', [_a, _c]), _caminata([_c, _c])], reportes: 2);
    final limpia = _opcion(31, [_caminata([_a, _a]), _bus('X105', [_a, _c]), _caminata([_c, _c])]);
    final conTransbordo = _opcion(35, [
      _caminata([_a, _a]), _bus('X106', [_a, _b]), _caminata([_b, _b]), _bus('T103', [_b, _c]), _caminata([_c, _c]),
    ], reportes: 1);
    final opciones = [rapida, limpia, conTransbordo];
    expect(etiquetaDeOpcion(opciones, 0), 'más rápida');
    expect(etiquetaDeOpcion(opciones, 1), 'sin reportes');
    expect(etiquetaDeOpcion(opciones, 2), isNull);
    expect(etiquetaDeOpcion([rapida], 0), isNull);
  });

  test('los reportes en el camino van del más grave al más confirmado', () {
    final opcion = _opcion(26, [_caminata([_a, _a]), _bus('T103', [_a, _c]), _caminata([_c, _c])]);
    Incident reporte(String id, String grupo, LatLng p, {int votos = 0}) => Incident(
        id: id, grupo: grupo, tipo: 'x', detalles: const {}, latitud: p.latitude, longitud: p.longitude, votosSi: votos);
    final lejos = reporte('lejos', 'seguridad', const LatLng(10.30, -75.40));
    final trancon = reporte('trancon', 'via', _b, votos: 5);
    final robo = reporte('robo', 'seguridad', _c);
    final lleno = reporte('lleno', 'servicio', _a, votos: 9);
    expect(reportesEnElCamino(opcion, [lejos, lleno, trancon, robo]).map((r) => r.id), ['robo', 'trancon', 'lleno']);
  });

  test('la página de una ruta lee su horario y sus estaciones', () {
    final pagina = PaginaDeRuta.fromJson({
      'codigo': 'T103',
      'nombre': 'Troncal 103',
      'tipo': 'troncal',
      'desde': 'Patio Portal',
      'hasta': 'Bocagrande',
      'geometria': {
        'type': 'LineString',
        'coordinates': [
          [-75.47, 10.39],
          [-75.55, 10.40],
        ],
      },
      'estaciones': [
        {'id': 'bazurto', 'nombre': 'Bazurto', 'latitud': 10.4139, 'longitud': -75.5243},
      ],
      'horario': {
        'lunes_a_viernes': {'primera': '05:00', 'ultima': '21:00'},
        'sabado': {'primera': '05:30', 'ultima': '20:30'},
        'domingo_y_festivos': null,
      },
      'hoy': 'sabado',
      'opera_ahora': true,
    });
    expect(pagina.puntos.first.longitude, -75.47);
    expect(pagina.estaciones.single.nombre, 'Bazurto');
    expect(pagina.horario['sabado'], (primera: '05:30', ultima: '20:30'));
    expect(pagina.horario['domingo_y_festivos'], isNull);
    expect(pagina.tieneHorario, isTrue);

    final sinHorario = PaginaDeRuta.fromJson({
      'codigo': 'C018', 'nombre': 'C018', 'tipo': 'complementaria', 'desde': '', 'hasta': '',
      'geometria': {'type': 'LineString', 'coordinates': []}, 'estaciones': [], 'horario': null,
      'hoy': 'sabado', 'opera_ahora': null,
    });
    expect(sinHorario.tieneHorario, isFalse);
    expect(sinHorario.operaAhora, isNull);
  });

  test('el título de una ruta es su recorrido, sin repetir tipo ni código', () {
    expect(recorridoDeRuta('Pretroncal X105 - Ciudadela 2000 - Crisanto Luque - Bocagrande', 'X105'),
        'Ciudadela 2000 · Crisanto Luque · Bocagrande');
    expect(recorridoDeRuta('Troncal 103 - Portal - Bocagrande - Portal', 'T103'), 'Portal · Bocagrande · Portal');
    expect(recorridoDeRuta('Ruta A107 - Blas de Lezo - Santa Lucía', 'A107'), 'Blas de Lezo · Santa Lucía');
    expect(recorridoDeRuta('Ruta C018', 'C018'), 'Ruta C018');
  });
}
