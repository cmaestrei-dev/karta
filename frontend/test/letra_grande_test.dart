import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/design/tema.dart';
import 'package:karta/features/legal/data/politica_repository.dart';
import 'package:karta/features/legal/presentation/aviso_de_privacidad.dart';
import 'package:karta/features/legal/presentation/politica_screen.dart';
import 'package:karta/features/trip/domain/trip_models.dart';
import 'package:karta/features/trip/presentation/widgets/tarjeta_de_opcion.dart';
import 'package:latlong2/latlong.dart';

/// Con la letra grande de Android (1,3) y la más grande (2,0) en un teléfono de 360 dp de ancho, nada se desborda:
/// un desborde es un error de Flutter y hace fallar la prueba.
const _escalas = [1.3, 2.0];

class _Politica implements PoliticaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Politica> politica() async => const Politica(
        version: '1.1',
        vigenteDesde: '1 de noviembre de 2026',
        correo: 'consultas.y.reclamos.de.datos@karta.test',
        texto: '# Política de tratamiento de datos personales de Karta\n\n'
            '## 2. Qué datos tratamos, para qué y por cuánto tiempo\n\n'
            '- **Cuánto tardaste.** Si compartes el viaje, al llegar se envía cuánto estimó Karta y cuánto tardaste.',
      );
}

/// Portal a Bocagrande: alimentadora, troncal con «el que pase primero» y una caminata, con nombres largos.
RouteOption _opcion() {
  const p = LatLng(10.40, -75.50);
  return const RouteOption(
    resumen: 'A105 → T103 o T101',
    tiempoTotalMin: 58,
    distanciaCaminataM: 1240,
    transbordos: 1,
    tramos: [
      Leg(modo: 'caminata', desde: 'Tu ubicación', hasta: 'Paradero Calle 31 con Carrera 80', distanciaM: 420,
          duracionMin: 6, esperaMin: 0, puntos: [p, p]),
      Leg(modo: 'bus', desde: 'Paradero Calle 31 con Carrera 80', hasta: 'Estación Portal de Transcaribe',
          distanciaM: 5200, duracionMin: 18, esperaMin: 9, ruta: 'A105', tipoRuta: 'alimentadora', puntos: [p, p]),
      Leg(modo: 'bus', desde: 'Estación Portal de Transcaribe', hasta: 'Estación Bocagrande', distanciaM: 14800,
          duracionMin: 21, esperaMin: 4, ruta: 'T103', tipoRuta: 'troncal', alternativas: ['T101'], puntos: [p, p]),
      Leg(modo: 'caminata', desde: 'Estación Bocagrande', hasta: 'Hotel Caribe, Avenida San Martín',
          distanciaM: 820, duracionMin: 11, esperaMin: 0, puntos: [p, p]),
    ],
    riesgo: RiskSummary(score: 0, nivel: 'BAJO', totalIncidentes: 0),
  );
}

Future<void> _montar(WidgetTester tester, double escala, Widget hijo) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepositoryProvider<PoliticaRepository>(
    create: (_) => _Politica(),
    child: MaterialApp(
      theme: TemaBahia.oscuro,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: hijo,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  // Con Manrope de verdad: la fuente de las pruebas tiene cada letra cuadrada y mide de más.
  setUpAll(() async {
    final manrope = FontLoader('Manrope');
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      manrope.addFont(rootBundle.load('assets/fonts/Manrope-$peso.ttf'));
    }
    await manrope.load();
  });

  for (final escala in _escalas) {
    group('letra a $escala', () {
      testWidgets('el aviso de privacidad se lee entero y el botón de aceptar se alcanza', (tester) async {
        await _montar(tester, escala, AvisoDePrivacidad(onAceptar: (_) {}));
        await tester.scrollUntilVisible(find.textContaining('Leer la política completa'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(tester.getRect(find.text('Acepto y continuar')).bottom, lessThanOrEqualTo(740));
        await tester.tap(find.text('Tengo 18 años o más'));
        await tester.pump();
      });

      testWidgets('la política completa', (tester) async {
        await _montar(tester, escala, const PoliticaScreen());
        expect(find.textContaining('Cuánto tardaste'), findsOneWidget);
      });

      testWidgets('la tarjeta de una opción con dos buses y nombres largos', (tester) async {
        await _montar(
          tester,
          escala,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TarjetaDeOpcion(opcion: _opcion(), enElCamino: const [], elegida: true, onTap: () {}),
            ),
          ),
        );
        // Los minutos caben en su columna: un número cortado no es un error de Flutter, así que se mide.
        final minutos = tester.renderObject<RenderParagraph>(find.text('58'));
        expect(minutos.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(minutos.size.width + 0.5));
      });
    });
  }
}
