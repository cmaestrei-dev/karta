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
}

/// Anota cada llamada al servidor en el orden en que llegan.
class _TiempoReal implements TiempoRealRepository {
  final llamadas = <String>[];
  var _viajes = 0;

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
    expect(servidor.llamadas.where((l) => !l.startsWith('llegada')), isEmpty);
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
    expect(servidor.llamadas.where((l) => !l.startsWith('llegada')), [
      'iniciar T103',
      'mover v1',
      'mover v1',
      'iniciar T103',
      'terminar v2',
    ]);
    expect(c.state.compartiendo, isFalse);
    expect(c.state.estado.fase, Fase.caminandoAlDestino);
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
    expect(servidor.llamadas.where((l) => !l.startsWith('llegada')), [
      'avistamiento T103 muy_lleno',
      'avistamiento T103 de_pie',
      'iniciar T103',
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
    expect(servidor.llamadas.where((l) => !l.startsWith('llegada')), isEmpty);
    await c.close();
  });

  test('la llegada se dice con quiénes la respaldan, y sin datos no se inventa', () {
    expect(textoDeLlegada('T103', const Llegada(minutos: 6, fuentes: 3, ocupacion: Ocupacion.dePie, vistoHaceMin: 4)),
        (titulo: 'El T103 llega en unos 6 min', detalle: 'según 3 viajeros · visto hace 4 min · de pie'));
    expect(textoDeLlegada('T103', const Llegada(minutos: 1, fuentes: 1, vistoHaceMin: 0)),
        (titulo: 'El T103 está llegando', detalle: 'según 1 viajero'));
    expect(textoDeLlegada('X104', const Llegada()),
        (titulo: 'Nadie ha visto pasar el X104', detalle: 'en la última media hora'));
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
}
