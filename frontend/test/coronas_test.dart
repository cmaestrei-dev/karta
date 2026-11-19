import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/api_client.dart';
import 'package:karta/core/design/tema.dart';
import 'package:karta/features/coronas/data/corona_repository.dart';
import 'package:karta/features/coronas/domain/corona_models.dart';
import 'package:karta/features/coronas/presentation/estacion_screen.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:latlong2/latlong.dart';

/// La página de la estación con su corona (docs/plan-juego.md, fase B).
void main() {
  const bazurto = Stop(
    id: 'bazurto', nombre: 'Bazurto', punto: LatLng(10.4139, -75.5244), rutas: ['T101', 'X103'],
    caminataM: 120, caminataMin: 2,
  );

  Future<_Coronas> abrir(WidgetTester tester, _Coronas coronas) async {
    tester.view.physicalSize = const Size(390, 1500); // un teléfono largo: todo a la vista, sin desplazar
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<CoronaRepository>.value(
      value: coronas,
      child: MaterialApp(theme: TemaBahia.oscuro, home: const EstacionScreen(estacion: bazurto)),
    ));
    await tester.pumpAndSettle();
    return coronas;
  }

  testWidgets('el apodo va debajo del nombre oficial, y se ve quién reina y cuánto falta', (tester) async {
    await abrir(tester, _Coronas(CoronaDeEstacion(
      estacion: 'bazurto', rey: 'un karteño', desde: DateTime(2026, 11, 12),
      apodo: 'La esquina del raspao', apodoHasta: DateTime.now().add(const Duration(hours: 5)),
      tu: const TuCorona(participas: true, llevas: 2, faltan: 3, puedesPonerApodo: false),
    )));
    expect(find.text('Estación Bazurto'), findsOneWidget); // el nombre oficial, siempre
    expect(find.text('«La esquina del raspao»'), findsOneWidget);
    expect(find.text('La tiene un karteño'), findsOneWidget);
    expect(find.text('Reina desde el 12 de noviembre'), findsOneWidget);
    expect(find.text('Llevas 2 días de aportes'), findsOneWidget);
    expect(find.text('te faltan 3'), findsOneWidget);
    expect(find.text('Cómo llegar'), findsOneWidget);
    expect(find.text('Reportar'), findsOneWidget);
  });

  testWidgets('para participar se explica qué se guarda y se pregunta', (tester) async {
    final coronas = await abrir(tester, _Coronas(const CoronaDeEstacion(
      estacion: 'bazurto',
      tu: TuCorona(participas: null, llevas: 0, faltan: 2, puedesPonerApodo: false),
    )));
    expect(find.text('Nadie reina todavía'), findsOneWidget);
    await tester.tap(find.text('Ver cómo funciona'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sin la hora ni el punto, por 31 días'), findsOneWidget);
    coronas.siguiente = const CoronaDeEstacion(
      estacion: 'bazurto', tu: TuCorona(participas: true, llevas: 0, faltan: 2, puedesPonerApodo: false));
    await tester.tap(find.text('Participar'));
    await tester.pumpAndSettle();
    expect(coronas.respuestas, [true]);
    expect(find.text('Llevas 0 días de aportes'), findsOneWidget);
  });

  testWidgets('quien reina pone el apodo; si no pasa el filtro, se le dice por qué', (tester) async {
    final coronas = await abrir(tester, _Coronas(const CoronaDeEstacion(
      estacion: 'bazurto', rey: 'un karteño', eresRey: true,
      tu: TuCorona(participas: true, llevas: 4, faltan: null, puedesPonerApodo: true),
    )));
    expect(find.text('La tienes tú'), findsOneWidget);
    await tester.tap(find.text('Ponle el apodo del día'));
    await tester.pumpAndSettle();
    expect(find.text('Ahora reinas en Bazurto'), findsOneWidget);

    coronas.rechazo = 'Sin números de teléfono.';
    await tester.enterText(find.byType(TextField), 'Llama al 3001234567');
    await tester.pump();
    expect(find.text('Hoy le dicen «Llama al 3001234567»'), findsOneWidget); // la vista previa
    await tester.tap(find.text('Poner apodo'));
    await tester.pumpAndSettle();
    expect(find.text('Sin números de teléfono.'), findsOneWidget);

    coronas.rechazo = null;
    coronas.siguiente = CoronaDeEstacion(
      estacion: 'bazurto', rey: 'un karteño', eresRey: true, apodo: 'El mejor raspao',
      apodoHasta: DateTime.now().add(const Duration(hours: 24)),
      tu: const TuCorona(participas: true, llevas: 4, faltan: null, puedesPonerApodo: false));
    await tester.tap(find.text('El mejor raspao'));
    await tester.pump();
    await tester.tap(find.text('Poner apodo'));
    await tester.pumpAndSettle();
    expect(coronas.apodos, ['Llama al 3001234567', 'El mejor raspao']);
    expect(find.text('«El mejor raspao»'), findsOneWidget); // de vuelta en la estación
    expect(find.text('Ya pusiste el apodo de esta semana.'), findsOneWidget);
    expect(find.text('Reportar'), findsNothing); // el propio no se reporta
  });
}

/// Un servidor de coronas de mentiras.
class _Coronas extends CoronaRepository {
  CoronaDeEstacion actual;
  CoronaDeEstacion? siguiente;
  String? rechazo;
  final respuestas = <bool>[];
  final apodos = <String>[];

  _Coronas(this.actual) : super(api: ApiClient(token: () => null));

  @override
  Future<CoronaDeEstacion> corona(String estacion) async {
    if (siguiente != null) {
      actual = siguiente!;
      siguiente = null;
    }
    return actual;
  }

  @override
  Future<AjustesDeCorona> ajustar({bool? participa, bool? visible, String? apodo}) async {
    if (participa != null) respuestas.add(participa);
    return AjustesDeCorona(participa: participa);
  }

  @override
  Future<CoronaDeEstacion> ponerApodo(String estacion, String texto) async {
    apodos.add(texto);
    if (rechazo != null) throw ApiException(rechazo!, codigo: 422);
    return siguiente ?? actual;
  }
}
