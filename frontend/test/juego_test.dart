import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/api_client.dart';
import 'package:karta/core/design/tema.dart';
import 'package:karta/features/juego/data/progreso_local.dart';
import 'package:karta/features/juego/domain/album.dart';
import 'package:karta/features/juego/domain/logros.dart';
import 'package:karta/features/juego/domain/progreso.dart';
import 'package:karta/features/juego/domain/sellos.dart';
import 'package:karta/features/juego/presentation/album_screen.dart';
import 'package:karta/features/juego/presentation/celebracion.dart';
import 'package:karta/features/juego/presentation/lamina_screen.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:karta/features/viaje/data/avisos.dart';
import 'package:karta/features/viaje/data/preferencia_de_compartir.dart';
import 'package:karta/features/viaje/data/tiempo_real_repository.dart';
import 'package:karta/features/viaje/domain/resultado_del_viaje.dart';
import 'package:karta/features/viaje/presentation/viaje_cubit.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El juego de la fase A (docs/plan-juego.md): álbum, tarjeta de sellos y medallas de viaje, en el teléfono.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('álbum de estaciones', () {
    test('reconoce las estaciones como las nombra la API, con o sin tilde', () {
      expect(Album.estacion('Estación La Popa')?.id, 'la-popa');
      expect(Album.estacion('Chambacu')?.id, 'chambacu');
      expect(Album.estacion('Patio Portal')?.numero, 1);
      expect(Album.estacion('Portal')?.id, 'portal');
      expect(Album.estacion('Kr 10'), isNull);
      expect(estacionesDelAlbum.map((e) => e.numero), List.generate(19, (k) => k + 1));
    });

    test('la primera vez es una lámina nueva; las siguientes, una vez más', () {
      final lunes = DateTime(2026, 11, 16, 7, 10);
      var r = const Album().pasoPor('La Popa', ruta: 'T101', cuando: lunes);
      expect(r.nueva?.nombre, 'La Popa');
      expect(r.album.conseguidas, 1);
      expect(r.album.nueva, 'la-popa');
      r = r.album.pasoPor('Estación La Popa', ruta: 'T103', cuando: lunes.add(const Duration(days: 1)));
      expect(r.nueva, isNull);
      final lamina = r.album.laminas['la-popa']!;
      expect((lamina.veces, lamina.ruta, lamina.conseguida), (2, 'T101', lunes)); // se conserva la primera vez
      expect(r.album.vista().nueva, isNull);
      expect(Album.fromJson(r.album.toJson()), r.album);
    });

    test('la siguiente por conseguir sigue el orden del álbum desde la última', () {
      final ahora = DateTime(2026, 11, 18);
      var album = const Album();
      for (final n in ['Bazurto', 'La Popa']) {
        album = album.pasoPor(n, cuando: ahora).album;
      }
      expect(album.siguientePorConseguir(despuesDe: 'la-popa')?.nombre, 'Lo Amador');
      expect(album.siguientePorConseguir()?.nombre, 'Patio Portal');
    });
  });

  group('tarjeta de sellos', () {
    test('un sello por día; los días no tienen que ser seguidos', () {
      var tarjeta = const TarjetaDeSellos();
      var r = tarjeta.sellar(DateTime(2026, 11, 2, 6, 30));
      expect((r.sellado, r.tarjeta.sellos), (true, 1));
      r = r.tarjeta.sellar(DateTime(2026, 11, 2, 18)); // mismo día
      expect((r.sellado, r.tarjeta.sellos), (false, 1));
      tarjeta = r.tarjeta;
      for (final dia in [5, 9, 10, 20, 21]) {
        tarjeta = tarjeta.sellar(DateTime(2026, 11, dia, 8)).tarjeta;
      }
      expect(tarjeta.sellos, 6);
      r = tarjeta.sellar(DateTime(2026, 12, 1, 8));
      expect((r.sellado, r.llena, r.tarjeta.sellos, r.tarjeta.llenas), (true, true, 0, 1));
      expect(TarjetaDeSellos.fromJson(tarjeta.toJson()), tarjeta);
    });
  });

  group('medallas de viaje', () {
    test('suben de bronce a platino', () {
      expect(madrugador.nivel(0), NivelDeMedalla.ninguno);
      expect(madrugador.nivel(1), NivelDeMedalla.bronce);
      expect(madrugador.nivel(15), NivelDeMedalla.oro);
      expect(troncalero.nivel(400), NivelDeMedalla.platino);
      expect(troncalero.siguienteMeta(12), 50);
      expect(troncalero.siguienteMeta(500), isNull);
    });
  });

  test('el progreso se guarda en el teléfono y se borra con la cuenta', () async {
    final local = ProgresoLocal();
    final hoy = DateTime(2026, 11, 18, 5, 40);
    await Future.wait([
      local.cambiar((p) => (progreso: p.copyWith(tarjeta: p.tarjeta.sellar(hoy).tarjeta), resultado: null)),
      local.cambiar((p) => (progreso: p.copyWith(album: p.album.pasoPor('Bazurto', cuando: hoy).album), resultado: null)),
    ]);
    final leido = await local.leer();
    expect((leido.tarjeta.sellos, leido.album.conseguidas), (1, 1)); // en fila: ninguna escritura pisa a la otra
    await local.borrar();
    expect(await local.leer(), const ProgresoDeJuego());
  });

  group('pantallas', () {
    testWidgets('el álbum muestra cuántas lleva; la nueva se abre y deja de serlo', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // un teléfono
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final local = ProgresoLocal();
      final hoy = DateTime.now();
      await local.cambiar((p) {
        var album = p.album.pasoPor('Bazurto', ruta: 'T101', cuando: hoy).album;
        album = album.pasoPor('La Popa', ruta: 'T101', cuando: hoy).album;
        return (progreso: p.copyWith(album: album), resultado: null);
      });
      await tester.pumpWidget(MaterialApp(theme: TemaBahia.oscuro, home: AlbumScreen(progreso: local)));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text(' de 19'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Chambacú'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Nueva'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Chambacú, número 17: te falta')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('La Popa, número 15, nueva')));
      await tester.pumpAndSettle();
      expect(find.text('La Popa'), findsOneWidget);
      expect(find.text('La conseguiste hoy, en la T101.'), findsOneWidget);
      expect(find.text('Nueva en tu álbum'), findsOneWidget);
      expect((await local.leer()).album.nueva, isNull);
    });

    test('la fecha de la lámina se lee como se dice', () {
      final ahora = DateTime(2026, 11, 18, 9);
      expect(cuandoLaConsiguio(DateTime(2026, 11, 18, 6), ahora: ahora), 'hoy');
      expect(cuandoLaConsiguio(DateTime(2026, 11, 17, 22), ahora: ahora), 'ayer');
      expect(cuandoLaConsiguio(DateTime(2026, 11, 2), ahora: ahora), 'el 2 de noviembre');
      expect(cuandoLaConsiguio(DateTime(2025, 12, 24), ahora: ahora), 'el 24 de diciembre de 2025');
    });

    testWidgets('la celebración se va sola y avisa que ya se vio', (tester) async {
      var vistos = 0;
      await tester.pumpWidget(MaterialApp(
        theme: TemaBahia.oscuro,
        home: Scaffold(
          body: CelebracionDeLogro(logro: const SelloDelDia(sellos: 3, llena: false), onVisto: () => vistos++),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Sello del día'), findsOneWidget);
      expect(find.text('Llevas 3 de 7 en tu tarjeta'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(vistos, 1);
    });
  });

  group('en el viaje', () {
    late StreamController<LatLng> gps;
    late _TiempoReal servidor;
    late ProgresoLocal local;
    late DateTime ahora;

    setUp(() {
      gps = StreamController<LatLng>();
      servidor = _TiempoReal();
      local = ProgresoLocal();
      ahora = DateTime(2026, 11, 18, 5, 30);
    });

    ViajeCubit cubit({bool compartir = true}) => ViajeCubit(
          opcion: _viaje(),
          avisos: _Avisos(),
          fuente: (_) => gps.stream,
          tiempoReal: servidor,
          preferencia: _Preferencia(compartir),
          juego: local,
          haySesion: () => true,
          reloj: () => ahora,
        );

    Future<void> en(LatLng punto) async {
      ahora = ahora.add(const Duration(minutes: 2));
      gps.add(punto);
      for (var k = 0; k < 6; k++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('compartiendo: el sello del día, las estaciones por las que pasa y los km de la troncal', () async {
      final c = cubit();
      await c.iniciar();
      final logros = <LogroDelViaje>[];
      final sub = c.stream.listen((s) {
        if (s.logro != null && (logros.isEmpty || logros.last != s.logro)) logros.add(s.logro!);
      });
      for (final p in [_p(0, 195), _p(300, 200), _p(1000, 200), _p(2000, 200), _p(2990, 200), _p(3000, 60)]) {
        await en(p);
        while (c.state.logro != null) {
          c.logroVisto();
        }
      }
      await sub.cancel();
      await c.close();
      final progreso = await local.leer();
      expect(progreso.tarjeta.sellos, 1);
      expect(progreso.madrugadas, 1); // compartió antes de las 6
      expect(progreso.album.laminas.keys, containsAll(['la-popa', 'chambacu', 'la-bodeguita']));
      expect(progreso.kmTroncal, closeTo(2.7, 0.1)); // de donde subió a donde se bajó
      expect(logros.first, const SelloDelDia(sellos: 1, llena: false));
      expect(logros.whereType<LaminaNueva>().map((l) => l.estacion.id), containsAll(['la-popa', 'chambacu']));
    });

    test('sin compartir el viaje no se gana nada', () async {
      final c = cubit(compartir: false);
      await c.iniciar();
      for (final p in [_p(0, 195), _p(300, 200), _p(1000, 200), _p(2990, 200), _p(3000, 60)]) {
        await en(p);
      }
      await c.close();
      expect(await local.leer(), const ProgresoDeJuego());
    });
  });
}

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
  _Preferencia(this.si);
  @override
  Future<bool> compartir() async => si;
  @override
  Future<bool> avisoVisto() async => true;
  @override
  Future<void> sumarViajeCompartido() async {}
}

/// Un servidor que acepta todo.
class _TiempoReal implements TiempoRealRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<Llegada> llegada(String ruta, {required LatLng desde, required LatLng hasta}) async =>
      const Llegada(minutos: 5, fuentes: 1);
  @override
  Future<void> avistamiento(String ruta, LatLng punto, {Ocupacion? ocupacion}) async {}
  @override
  Future<String> iniciarViajeCompartido(String ruta, LatLng punto) async => 'v1';
  @override
  Future<bool> moverViajeCompartido(String viaje, LatLng punto, {Ocupacion? ocupacion}) async => true;
  @override
  Future<void> terminarViajeCompartido(String viaje) async {}
  @override
  Future<void> reportar(String tipo, Map<String, String> detalles, LatLng punto) async {}
  @override
  Future<void> comoPediLaParada(String ruta, LatLng paradero, ComoSePidio como) async {}
  @override
  Future<void> subida(String ruta, LatLng punto, {String? modulo}) async {}
  @override
  Future<ComoSePideAqui?> comoSePide(String ruta, LatLng paradero) async => null;
  @override
  Future<void> resultadoDelViaje(ResultadoDelViaje resultado) async {}
}
