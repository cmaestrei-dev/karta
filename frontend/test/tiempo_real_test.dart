import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/api_client.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:karta/features/viaje/data/avisos.dart';
import 'package:karta/features/viaje/data/preferencia_de_compartir.dart';
import 'package:karta/features/viaje/data/tiempo_real_repository.dart';
import 'package:karta/features/viaje/domain/seguidor_de_viaje.dart';
import 'package:karta/features/viaje/presentation/instrucciones.dart';
import 'package:karta/features/viaje/presentation/viaje_cubit.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mLat = 1 / 110540;
const _mLon = 1 / 108900;
LatLng _p(double esteM, double norteM) => LatLng(10.40 + norteM * _mLat, -75.55 + esteM * _mLon);

/// Caminar a Bazurto, T103 hasta La Bodeguita, caminar a Bocagrande.
RouteOption _viaje() => RouteOption(
      resumen: 'T103',
      tiempoTotalMin: 20,
      distanciaCaminataM: 350,
      tramos: [
        Leg(modo: 'caminata', desde: 'Tu ubicación', hasta: 'Estación Bazurto', distanciaM: 200, duracionMin: 3,
            esperaMin: 0, puntos: [_p(0, 0), _p(0, 200)]),
        Leg(modo: 'bus', desde: 'Estación Bazurto', hasta: 'Estación La Bodeguita', distanciaM: 3000,
            duracionMin: 10, esperaMin: 5, ruta: 'T103', tipoRuta: 'troncal', puntos: [_p(0, 200), _p(3000, 200)]),
        Leg(modo: 'caminata', desde: 'Estación La Bodeguita', hasta: 'Bocagrande', distanciaM: 150, duracionMin: 2,
            esperaMin: 0, puntos: [_p(3000, 200), _p(3000, 50)]),
      ],
      riesgo: const RiskSummary(score: 0, nivel: 'BAJO', totalIncidentes: 0),
    );

class _Avisos extends Avisos {
  @override
  Future<bool> pedirPermiso() async => true;
  @override
  Future<void> mostrar(String titulo, String texto, {bool urgente = false}) async {}
  @override
  Future<void> limpiar() async {}
}

class _Preferencia extends PreferenciaDeCompartir {
  final bool si;
  final bool vioElAviso;
  _Preferencia({required this.si, required this.vioElAviso});
  @override
  Future<bool> compartir() async => si;
  @override
  Future<bool> avisoVisto() async => vioElAviso;

  int viajesSumados = 0;

  @override
  Future<void> sumarViajeCompartido() async => viajesSumados++;
}

/// Anota cada llamada al servidor en el orden en que llegan.
class _TiempoReal implements TiempoRealRepository {
  final llamadas = <String>[];
  var _viajes = 0;

  /// Lo que el teléfono envió, sin las consultas (la llegada y cómo se pide la parada).
  Iterable<String> get envios => llamadas.where((l) => !l.startsWith('llegada') && !l.startsWith('como se pide'));

  /// El servidor ya borró el viaje la próxima vez que se mueva.
  bool vencido = false;

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Future<Llegada> llegada(String ruta, {required LatLng desde, required LatLng hasta}) async {
    llamadas.add('llegada $ruta');
    expect(desde, _p(0, 200)); // la subida y la bajada del tramo en bus
    expect(hasta, _p(3000, 200));
    return const Llegada(minutos: 6, fuentes: 2, ocupacion: Ocupacion.dePie);
  }

  @override
  Future<void> avistamiento(String ruta, LatLng punto, {Ocupacion? ocupacion}) async =>
      llamadas.add('avistamiento $ruta ${ocupacion?.api}');

  @override
  Future<String> iniciarViajeCompartido(String ruta, LatLng punto) async {
    llamadas.add('iniciar $ruta');
    return 'v${++_viajes}';
  }

  @override
  Future<bool> moverViajeCompartido(String viaje, LatLng punto, {Ocupacion? ocupacion}) async {
    llamadas.add('mover $viaje${ocupacion != null ? ' ${ocupacion.api}' : ''}');
    if (!vencido) return true;
    vencido = false;
    return false;
  }

  @override
  Future<void> terminarViajeCompartido(String viaje) async => llamadas.add('terminar $viaje');

  @override
  Future<void> reportar(String tipo, Map<String, String> detalles, LatLng punto) async =>
      llamadas.add('reporte $tipo ${detalles.values.join(',')}');

  /// Lo que «saben» los viajeros del paradero de bajada.
  ComoSePideAqui? sabido;

  @override
  Future<void> comoPediLaParada(String ruta, LatLng paradero, ComoSePidio como) async {
    expect(paradero, _p(3000, 200));
    llamadas.add('parada $ruta ${como.api}');
  }

  @override
  Future<void> subida(String ruta, LatLng punto) async => llamadas.add('subida $ruta');

  @override
  Future<ComoSePideAqui?> comoSePide(String ruta, LatLng paradero) async {
    expect(paradero, _p(3000, 200));
    llamadas.add('como se pide $ruta');
    return sabido;
  }
}

/// Cada ruta llega a su hora: para «el que pase primero».
class _TiempoRealPorRuta extends _TiempoReal {
  final Map<String, int?> minutos;

  _TiempoRealPorRuta(this.minutos);

  @override
  Future<Llegada> llegada(String ruta, {required LatLng desde, required LatLng hasta}) async {
    llamadas.add('llegada $ruta');
    return Llegada(minutos: minutos[ruta], fuentes: minutos[ruta] == null ? 0 : 1);
  }
}

/// El mismo servidor, hasta que el teléfono se queda sin red.
class _TiempoRealSinRed extends _TiempoReal {
  final _TiempoReal otro;
  bool sinRed = false;

  _TiempoRealSinRed(this.otro);

  @override
  Future<Llegada> llegada(String ruta, {required LatLng desde, required LatLng hasta}) async {
    if (sinRed) throw ApiException('Sin conexión');
    return otro.llegada(ruta, desde: desde, hasta: hasta);
  }
}

Future<void> _pasa() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TiempoReal servidor;
  late StreamController<LatLng> gps;
  late DateTime ahora;

  setUp(() {
    servidor = _TiempoReal();
    gps = StreamController<LatLng>.broadcast(); // algunas pruebas hacen dos viajes seguidos
    ahora = DateTime(2026, 10, 27, 8);
  });

  ViajeCubit cubit(
          {bool compartir = true,
          bool vioElAviso = true,
          bool sesion = true,
          Duration cadaCuanto = const Duration(seconds: 30)}) =>
      ViajeCubit(
        opcion: _viaje(),
        avisos: _Avisos(),
        fuente: (_) => gps.stream,
        tiempoReal: servidor,
        preferencia: _Preferencia(si: compartir, vioElAviso: vioElAviso),
        haySesion: () => sesion,
        cadaCuanto: cadaCuanto,
        reloj: () => ahora,
      );

  Future<void> en(LatLng punto, {Duration despues = Duration.zero}) async {
    ahora = ahora.add(despues);
    gps.add(punto);
    await _pasa();
    await _pasa();
  }

  test('mientras camina y espera pregunta cuándo llega el bus; a bordo deja de preguntar', () async {
    final c = cubit(cadaCuanto: const Duration(milliseconds: 20));
    await c.iniciar();
    await _pasa();
    expect(c.state.llegada, const Llegada(minutos: 6, fuentes: 2, ocupacion: Ocupacion.dePie));

    await en(_p(0, 195)); // en la parada: el mismo bus, no vuelve a empezar
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(servidor.llamadas.length, greaterThanOrEqualTo(3));

    await en(_p(300, 200)); // subió
    expect(c.state.estado.fase, Fase.aBordo);
    expect(c.state.llegada, isNull);
    final consultas = servidor.llamadas.length;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(servidor.llamadas.length, consultas);
    await c.close();
  });

  test('sin haber visto el aviso, o si lo apagó en Privacidad, no comparte nada al subir', () async {
    for (final c in [cubit(vioElAviso: false), cubit(compartir: false)]) {
      await c.iniciar();
      await en(_p(0, 195));
      await en(_p(300, 200));
      await en(_p(1500, 200), despues: const Duration(minutes: 1));
      expect(c.state.compartiendo, isFalse);
      await c.close();
    }
    expect(servidor.envios, isEmpty);
  });

  test('por defecto comparte al subir, cada 30 s, reinicia si venció y termina al bajarse', () async {
    final c = cubit();
    await c.iniciar();
    await en(_p(0, 195));
    await en(_p(300, 200)); // subió: empieza
    await en(_p(800, 200), despues: const Duration(seconds: 10)); // muy pronto: no envía
    await en(_p(1500, 200), despues: const Duration(seconds: 25));
    servidor.vencido = true;
    await en(_p(2100, 200), despues: const Duration(seconds: 30)); // el servidor lo había borrado
    await en(_p(2990, 200), despues: const Duration(seconds: 30)); // se bajó
    expect(servidor.envios, [
      'iniciar T103',
      'subida T103', // subió en la calle: el punto (sin su nombre) es una pista para ubicar el paradero
      'mover v1',
      'mover v1',
      'iniciar T103',
      'terminar v2',
    ]);
    expect(c.state.compartiendo, isFalse);
    expect(c.state.estado.fase, Fase.caminandoAlDestino);
    // «Buses compartidos» en «Tu impacto»: uno, aunque el viaje compartido se haya reiniciado al vencer.
    expect((c.preferencia as _Preferencia).viajesSumados, 1);
    await c.close();
  });

  test('cómo va el bus: sin compartir va como avistamiento; compartiendo, con la posición del bus', () async {
    final sinCompartir = cubit(compartir: false);
    await sinCompartir.iniciar();
    await en(_p(0, 195));
    await sinCompartir.pasoLleno(); // pasó uno lleno mientras esperaba
    await en(_p(300, 200));
    expect(sinCompartir.puedeContar, isTrue);
    await sinCompartir.contarOcupacion(Ocupacion.dePie);
    expect(sinCompartir.state.ocupacion, Ocupacion.dePie);
    await sinCompartir.close();

    final compartiendo = cubit();
    await compartiendo.iniciar();
    await en(_p(0, 195));
    await en(_p(300, 200));
    await compartiendo.contarOcupacion(Ocupacion.muyLleno);
    expect(servidor.envios, [
      'avistamiento T103 muy_lleno',
      'avistamiento T103 de_pie',
      'iniciar T103',
      'subida T103',
      'mover v1 muy_lleno',
    ]);
    await compartiendo.close();
  });

  test('sin sesión solo consulta: no cuenta ni comparte', () async {
    final c = cubit(sesion: false);
    await c.iniciar();
    await en(_p(0, 195));
    await en(_p(300, 200));
    expect(c.puedeContar, isFalse);
    await c.contarOcupacion(Ocupacion.dePie);
    expect(servidor.envios, isEmpty);
    await c.close();
  });

  test('la llegada se dice con quiénes la respaldan, y sin datos no se inventa', () {
    expect(textoDeLlegada('T103', const Llegada(minutos: 6, fuentes: 3, ocupacion: Ocupacion.dePie, vistoHaceMin: 4)),
        (titulo: 'El T103 llega en unos 6 min', detalle: 'según 3 viajeros · visto hace 4 min · de pie'));
    expect(textoDeLlegada('T103', const Llegada(minutos: 1, fuentes: 1, vistoHaceMin: 0)),
        (titulo: 'El T103 está llegando', detalle: 'según 1 viajero · visto hace un momento'));
    // Sin conexión: el dato envejece, el bus se acerca y se dice.
    const dato = Llegada(minutos: 6, fuentes: 3, vistoHaceMin: 1);
    expect(textoDeLlegada('T103', dato.sinConexionDesde(const Duration(minutes: 2, seconds: 40))),
        (titulo: 'El T103 llega en unos 4 min', detalle: 'sin conexión · según 3 viajeros · visto hace 3 min'));
    expect(dato.sinConexionDesde(const Duration(minutes: 9)).minutos, 0);
    expect(textoDeLlegada('X104', const Llegada()),
        (titulo: 'Nadie ha visto pasar el X104', detalle: 'en la última media hora'));
  });

  test('al esperar: la fila en la estación y dejar bajar cuando el bus llega, sin regañar', () {
    final paradero = _viaje().tramos[1]; // sin estaciones: sube en un paradero de la vía
    final enEstacion = Leg(modo: 'bus', desde: 'Estación Bazurto', hasta: 'Estación La Bodeguita', distanciaM: 3000,
        duracionMin: 10, esperaMin: 5, ruta: 'T103', tipoRuta: 'troncal', puntos: [_p(0, 200), _p(3000, 200)],
        paradas: [(nombre: 'Bazurto', punto: _p(0, 210)), (nombre: 'La Bodeguita', punto: _p(3000, 200))]);
    expect(consejoDeEspera(paradero, null), isNull);
    expect(consejoDeEspera(enEstacion, null), 'Haz la fila del T103: se sube en orden.');
    final conModulo = Leg(modo: 'bus', desde: 'Estación Bazurto', hasta: 'Estación La Bodeguita', distanciaM: 3000,
        duracionMin: 10, esperaMin: 5, ruta: 'T103', tipoRuta: 'troncal', puntos: [_p(0, 200), _p(3000, 200)],
        paradas: [(nombre: 'Bazurto', punto: _p(0, 210)), (nombre: 'La Bodeguita', punto: _p(3000, 200))], modulo: 'A1');
    expect(consejoDeEspera(conModulo, null), 'Haz la fila del T103 en el módulo A1: se sube en orden.');
    expect(consejoDeEspera(enEstacion, const Llegada(minutos: 6, fuentes: 1)), 'Haz la fila del T103: se sube en orden.');
    expect(consejoDeEspera(paradero, const Llegada(minutos: 1, fuentes: 1)), 'Deja bajar primero y sube en orden.');
    // Un dato viejo no sirve para decir que el bus ya está llegando.
    expect(consejoDeEspera(paradero, const Llegada(minutos: 1, fuentes: 1, sinConexion: true)), isNull);
  });

  test('camino a Madre Bernarda advierte que Santa Lucía, la de enfrente, es de alimentadoras', () {
    final bus = Leg.fromJson({
      'modo': 'bus', 'desde': 'Estación Madre Bernarda', 'hasta': 'Estación La Bodeguita', 'distancia_m': 9000,
      'duracion_min': 20, 'ruta': 'T103', 'tipo_ruta': 'troncal', 'modulo': 'A1',
      'advertencia': 'Ojo: Santa Lucía, la estación de enfrente, es solo de alimentadoras. Entra a Madre Bernarda.',
      'geometria': {'type': 'LineString', 'coordinates': [[-75.4786, 10.3951], [-75.5514, 10.4200]]},
    });
    expect(consejoAlCaminar(bus), startsWith('Ojo: Santa Lucía'));
    expect(consejoAlCaminar(null), isNull);
  });

  group('cómo pediste la parada', () {
    test('antes de subir sabe cómo se pide en la bajada; ya abajo pregunta una vez y se puede responder', () async {
      servidor.sabido = const ComoSePideAqui(como: ComoSePidio.timbre, viajeros: 4);
      final c = cubit(compartir: false);
      await c.iniciar();
      await _pasa();
      expect(c.state.comoSePideAqui, servidor.sabido);
      expect(servidor.llamadas.where((l) => l.startsWith('como se pide')), ['como se pide T103']);
      await en(_p(0, 195));
      await en(_p(300, 200));
      await en(_p(2990, 200)); // se bajó en el paradero
      expect(c.state.preguntarComoPediste, 'Estación La Bodeguita');
      expect(c.state.comoSePideAqui, isNull);
      await c.respondiComoPedi(ComoSePidio.timbre);
      expect(c.state.preguntarComoPediste, isNull);
      expect(servidor.llamadas.last, 'parada T103 timbre');
      await c.close();
    });

    test('no pregunta si ya preguntó por un varado, ni sin sesión; y se puede saltar', () async {
      final varado = cubit(compartir: false);
      await varado.iniciar();
      await en(_p(0, 195));
      await en(_p(300, 200));
      await en(_p(1000, 200));
      ahora = ahora.add(const Duration(minutes: 5));
      varado.revisarSiSeVaro();
      expect(varado.state.preguntarVarado, isTrue);
      await en(_p(2990, 200));
      expect(varado.state.preguntarComoPediste, isNull);
      await varado.close();

      final sinSesion = cubit(compartir: false, sesion: false);
      await sinSesion.iniciar();
      await en(_p(0, 195));
      await en(_p(300, 200));
      await en(_p(2990, 200));
      expect(sinSesion.state.preguntarComoPediste, isNull);
      await sinSesion.close();

      final salta = cubit(compartir: false);
      await salta.iniciar();
      await en(_p(0, 195));
      await en(_p(300, 200));
      await en(_p(2990, 200));
      salta.saltarComoPedi();
      expect(salta.state.preguntarComoPediste, isNull);
      expect(servidor.llamadas.where((l) => l.startsWith('parada')), isEmpty);
      await salta.close();
    });

    test('debajo de «¡Toca el timbre!» se dice lo que hicieron los demás', () {
      expect(textoDeLoQueSeSabe(const ComoSePideAqui(como: ComoSePidio.timbre, viajeros: 4)),
          'Así la pidieron 4 viajeros aquí.');
      expect(textoDeLoQueSeSabe(const ComoSePideAqui(como: ComoSePidio.paroSolo, viajeros: 3)),
          'Aquí suele parar solo, según 3 viajeros. Por si acaso, pídela.');
    });
  });

  test('el que pase primero: muestra la ruta que llega antes y, a bordo, se cuenta en la que dijo que va', () async {
    final servidorPorRuta = _TiempoRealPorRuta({'T103': 6, 'T101': 2});
    final base = _viaje();
    final bus = base.tramos[1];
    final opcion = RouteOption(
      resumen: 'T103 o T101', tiempoTotalMin: base.tiempoTotalMin, distanciaCaminataM: base.distanciaCaminataM,
      riesgo: base.riesgo,
      tramos: [
        base.tramos[0],
        Leg(modo: 'bus', desde: bus.desde, hasta: bus.hasta, distanciaM: bus.distanciaM, duracionMin: bus.duracionMin,
            esperaMin: 2, ruta: 'T103', tipoRuta: 'troncal', puntos: bus.puntos, alternativas: const ['T101']),
        base.tramos[2],
      ],
    );
    final c = ViajeCubit(
      opcion: opcion,
      avisos: _Avisos(),
      fuente: (_) => gps.stream,
      tiempoReal: servidorPorRuta,
      preferencia: _Preferencia(si: false, vioElAviso: true),
      haySesion: () => true,
      reloj: () => ahora,
    );
    await c.iniciar();
    await _pasa();
    expect(c.state.rutaQueLlega, 'T101');
    expect(c.state.llegada!.minutos, 2);
    expect(servidorPorRuta.llamadas.where((l) => l.startsWith('llegada')).toSet(), {'llegada T103', 'llegada T101'});

    await en(_p(0, 195));
    await en(_p(300, 200)); // subió: se supone el que llegaba primero
    expect(c.rutaDelBus, 'T101');
    c.voyEn('T103'); // pero dice que va en el T103
    await c.contarOcupacion(Ocupacion.dePie);
    expect(servidorPorRuta.llamadas.last, 'avistamiento T103 de_pie');
    await c.close();
  });

  test('sin conexión mantiene la última llegada unos minutos, envejecida; después no dice nada', () async {
    final falla = _TiempoRealSinRed(servidor);
    final c = ViajeCubit(
      opcion: _viaje(),
      avisos: _Avisos(),
      fuente: (_) => gps.stream,
      tiempoReal: falla,
      preferencia: _Preferencia(si: false, vioElAviso: true),
      haySesion: () => true,
      cadaCuanto: const Duration(milliseconds: 20),
      reloj: () => ahora,
    );
    await c.iniciar();
    await _pasa();
    expect(c.state.llegada!.sinConexion, isFalse);

    falla.sinRed = true;
    ahora = ahora.add(const Duration(minutes: 2));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.state.llegada, const Llegada(minutos: 4, fuentes: 2, ocupacion: Ocupacion.dePie, sinConexion: true));

    ahora = ahora.add(ViajeCubit.vigenciaSinConexion);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.state.llegada, isNull);
    await c.close();
  });

  test('compartir viene activado, pero nada sale sin haber visto el aviso', () async {
    SharedPreferences.setMockInitialValues({});
    final preferencia = PreferenciaDeCompartir();
    expect(await preferencia.compartir(), isTrue);
    expect(await preferencia.avisoVisto(), isFalse);
    await preferencia.marcarAvisoVisto();
    await preferencia.guardar(false);
    expect(await preferencia.avisoVisto(), isTrue);
    expect(await preferencia.compartir(), isFalse);
  });

  group('bus varado', () {
    test('a bordo, cuatro minutos quieto lejos de la bajada pregunta y se puede reportar', () async {
      final c = cubit(compartir: false);
      await c.iniciar();
      await en(_p(0, 195));
      await en(_p(300, 200)); // subió
      await en(_p(1500, 200), despues: const Duration(minutes: 1));
      ahora = ahora.add(const Duration(minutes: 3));
      c.revisarSiSeVaro();
      expect(c.state.preguntarVarado, isFalse); // tres minutos: todavía no
      ahora = ahora.add(const Duration(minutes: 1, seconds: 10));
      c.revisarSiSeVaro();
      expect(c.state.preguntarVarado, isTrue);

      await c.seVaro();
      expect((c.state.preguntarVarado, c.state.varadoReportado), (false, true));
      expect(servidor.llamadas.last, 'reporte bus_varado T103');
      await c.close();
    });

    test('si el bus vuelve a andar, la pregunta se quita; y no se pregunta dos veces en el mismo bus', () async {
      final c = cubit(compartir: false);
      await c.iniciar();
      await en(_p(0, 195));
      await en(_p(300, 200));
      await en(_p(1500, 200));
      ahora = ahora.add(const Duration(minutes: 5));
      c.revisarSiSeVaro();
      expect(c.state.preguntarVarado, isTrue);
      await en(_p(1600, 200)); // arrancó
      expect(c.state.preguntarVarado, isFalse);
      ahora = ahora.add(const Duration(minutes: 6));
      c.revisarSiSeVaro();
      expect(c.state.preguntarVarado, isFalse);
      await c.close();
    });

    test('quieto en una estación o llegando a la bajada no es un bus varado', () async {
      final c = ViajeCubit(
        opcion: _viajeConEstacion(),
        avisos: _Avisos(),
        fuente: (_) => gps.stream,
        tiempoReal: servidor,
        preferencia: _Preferencia(si: false, vioElAviso: true),
        haySesion: () => true,
        reloj: () => ahora,
      );
      await c.iniciar();
      await en(_p(0, 195));
      await en(_p(300, 200));
      await en(_p(1000, 205)); // en la estación de la mitad
      ahora = ahora.add(const Duration(minutes: 8));
      c.revisarSiSeVaro();
      expect(c.state.preguntarVarado, isFalse);
      await en(_p(2850, 200)); // a 150 m de bajarse
      ahora = ahora.add(const Duration(minutes: 8));
      c.revisarSiSeVaro();
      expect(c.state.preguntarVarado, isFalse);
      await c.close();
    });

    test('quien espera ve que un bus se varó antes de su parada', () {
      const llegada = Llegada(varado: Varado(lugar: 'Cerca de Bazurto', metrosAntes: 900, haceMin: 6));
      expect(textoDeLlegada('T103', llegada),
          (titulo: 'Un T103 se varó antes de tu parada', detalle: 'Cerca de Bazurto · hace 6 min · espera el siguiente'));
    });
  });
}

/// El mismo viaje, con una estación a mitad del tramo en bus.
RouteOption _viajeConEstacion() {
  final base = _viaje();
  final bus = base.tramos[1];
  return RouteOption(
    resumen: base.resumen,
    tiempoTotalMin: base.tiempoTotalMin,
    distanciaCaminataM: base.distanciaCaminataM,
    tramos: [
      base.tramos[0],
      Leg(modo: 'bus', desde: bus.desde, hasta: bus.hasta, distanciaM: bus.distanciaM, duracionMin: bus.duracionMin,
          esperaMin: bus.esperaMin, ruta: bus.ruta, tipoRuta: bus.tipoRuta, puntos: bus.puntos,
          paradas: [(nombre: 'Bazurto', punto: _p(0, 200)), (nombre: 'La Popa', punto: _p(1000, 200)),
            (nombre: 'La Bodeguita', punto: _p(3000, 200))]),
      base.tramos[2],
    ],
    riesgo: base.riesgo,
  );
}
