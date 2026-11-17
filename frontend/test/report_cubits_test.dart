import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/api_client.dart';
import 'package:karta/core/api_errors.dart';
import 'package:karta/features/incidents/data/repositories/incident_repository.dart';
import 'package:karta/features/incidents/domain/models/incident_models.dart';
import 'package:karta/features/incidents/presentation/cubit/report_cubits.dart';
import 'package:latlong2/latlong.dart';

import 'datos/reportes.dart';

/// Repositorio en memoria que anota lo que se le pide.
class FakeIncidentRepository implements IncidentRepository {
  Map<String, String>? detallesEnviados;
  bool sesionVencida = false;
  bool retirarAlVotar = false;
  IncidentDetail detalle = IncidentDetail.fromJson({...incidenteJson(), 'reportado_por_alias': 'Ana P.', 'es_mio': false});

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Future<CatalogoDeReportes> catalogo() async => CatalogoDeReportes.fromJson(catalogoJson);

  @override
  Future<List<Incident>> getActiveIncidents() async => [];

  @override
  Future<Incident> report({required String tipo, required Map<String, String> detalles, required LatLng punto}) async {
    if (sesionVencida) throw SessionExpiredException();
    detallesEnviados = detalles;
    return Incident.fromJson(incidenteJson(tipo: tipo, detalles: detalles));
  }

  @override
  Future<IncidentDetail> detail(String id) async => detalle;

  @override
  Future<(Incident, bool)> vote(String id, {required bool sigue}) async {
    final votos = detalle.incidente.votosSi + (sigue ? 1 : 0);
    return (Incident.fromJson(incidenteJson(votosSi: votos)), retirarAlVotar);
  }

  int graciasDadas = 0;

  @override
  Future<Incident> thank(String id) async {
    graciasDadas++;
    return Incident.fromJson({...incidenteJson(), 'gracias': detalle.incidente.gracias + 1});
  }
}

void main() {
  const bazurto = LatLng(10.4139, -75.5243);
  late FakeIncidentRepository repositorio;

  setUp(() => repositorio = FakeIncidentRepository());

  group('reportar en dos pasos', () {
    test('elegir un tipo pasa a sus preguntas; volver lo olvida', () async {
      final cubit = ReportCubit(repository: repositorio, punto: bazurto);
      await cubit.cargar();
      expect(cubit.state.paso, PasoDeReporte.eligiendo);

      cubit.elegir(cubit.state.catalogo!.tipo('bus_no_pasa')!);
      expect(cubit.state.paso, PasoDeReporte.detallando);
      cubit.responder('ruta', 'T103');
      cubit.volver();
      expect(cubit.state.paso, PasoDeReporte.eligiendo);
      expect(cubit.state.tipo, isNull);
      expect(cubit.state.respuestas, isEmpty);
    });

    test('no se envía hasta responder lo obligatorio; tocar de nuevo una opción la quita', () async {
      final cubit = ReportCubit(repository: repositorio, punto: bazurto);
      await cubit.cargar();
      cubit.elegir(cubit.state.catalogo!.tipo('bus_no_pasa')!);
      expect(cubit.state.completo, isFalse);

      await cubit.enviar();
      expect(repositorio.detallesEnviados, isNull);

      cubit.responder('espera', '20');
      cubit.responder('espera', '20');
      expect(cubit.state.respuestas, isEmpty);

      cubit.escribir('ruta', ' t103 ');
      cubit.responder('espera', '30');
      expect(cubit.state.completo, isTrue);
      await cubit.enviar();
      expect(repositorio.detallesEnviados, {'ruta': 'T103', 'espera': '30'});
      expect(cubit.state.paso, PasoDeReporte.enviado);
      expect(cubit.state.creado?.tipo, 'bus_no_pasa');
    });

    test('un tipo sin preguntas se envía directo', () async {
      final cubit = ReportCubit(repository: repositorio, punto: bazurto);
      await cubit.cargar();
      cubit.elegir(cubit.state.catalogo!.tipo('trancon')!);
      expect(cubit.state.completo, isTrue);
      await cubit.enviar();
      expect(repositorio.detallesEnviados, isEmpty);
    });

    test('si la sesión venció, lo dice y conserva las respuestas', () async {
      repositorio.sesionVencida = true;
      final cubit = ReportCubit(repository: repositorio, punto: bazurto);
      await cubit.cargar();
      cubit.elegir(cubit.state.catalogo!.tipo('trancon')!);
      await cubit.enviar();
      expect(cubit.state.sesionExpirada, isTrue);
      expect(cubit.state.paso, PasoDeReporte.detallando);
    });
  });

  group('«¿Sigue ahí?»', () {
    test('confirmar suma el voto y ya no deja votar otra vez', () async {
      final cubit = IncidentDetailCubit(repository: repositorio);
      await cubit.cargar('x');
      expect(cubit.state.detalle!.puedeVotar, isTrue);

      await cubit.votar(sigue: true);
      expect(cubit.state.estado, EstadoDelDetalle.listo);
      expect(cubit.state.detalle!.miVoto, isTrue);
      expect(cubit.state.detalle!.incidente.votosSi, 1);
      expect(cubit.state.detalle!.puedeVotar, isFalse);
    });

    test('cuando la comunidad lo desmiente, avisa al mapa para quitarlo', () async {
      repositorio.retirarAlVotar = true;
      String? retirado;
      final cubit = IncidentDetailCubit(repository: repositorio, onRetirado: (id) => retirado = id);
      await cubit.cargar('x');
      await cubit.votar(sigue: false);
      expect(cubit.state.estado, EstadoDelDetalle.retirado);
      expect(retirado, '665f1c2b9a1e4b0012345678');
    });

    test('en un reporte propio no se vota ni se dan las gracias', () async {
      repositorio.detalle = IncidentDetail.fromJson({...incidenteJson(), 'reportado_por_alias': 'Yo', 'es_mio': true});
      final cubit = IncidentDetailCubit(repository: repositorio);
      await cubit.cargar('x');
      await cubit.votar(sigue: true);
      await cubit.darGracias();
      expect(cubit.state.detalle!.miVoto, isNull);
      expect(repositorio.graciasDadas, 0);
    });

    test('las gracias se dan una sola vez y no cambian el voto', () async {
      final cubit = IncidentDetailCubit(repository: repositorio);
      await cubit.cargar('x');
      await cubit.darGracias();
      await cubit.darGracias();
      expect(repositorio.graciasDadas, 1);
      expect(cubit.state.detalle!.misGracias, isTrue);
      expect(cubit.state.detalle!.incidente.gracias, 1);
      expect(cubit.state.detalle!.puedeVotar, isTrue);
    });
  });
}
