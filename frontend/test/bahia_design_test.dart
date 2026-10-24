import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/design/bahia.dart';
import 'package:karta/core/design/ilustracion.dart';

double contraste(Color a, Color b) {
  final (claro, oscuro) = a.computeLuminance() > b.computeLuminance() ? (a, b) : (b, a);
  return (claro.computeLuminance() + 0.05) / (oscuro.computeLuminance() + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (nombre, p) in [('oscura', Bahia.oscura), ('clara', Bahia.clara)]) {
    group('paleta $nombre: texto legible (≥ 4,5:1)', () {
      final pares = {
        'texto sobre fondo': (p.texto, p.fondo),
        'texto sobre hoja': (p.texto, p.hoja),
        'texto sobre tarjeta': (p.texto, p.tarjeta),
        'texto suave sobre hoja': (p.textoSuave, p.hoja),
        'texto suave sobre tarjeta': (p.textoSuave, p.tarjeta),
        'texto sobre el acento': (p.sobreAcento, p.acento),
        'texto sobre el botón de reportar': (p.sobreReportar, p.reportar),
      };
      for (final MapEntry(key: caso, value: (frente, fondo)) in pares.entries) {
        test(caso, () => expect(contraste(frente, fondo), greaterThanOrEqualTo(4.5)));
      }
    });
  }

  test('los botones del color de un grupo llevan tinta legible (≥ 4,5:1) en los dos temas', () {
    for (final p in [Bahia.oscura, Bahia.clara]) {
      for (final color in [p.servicio, p.via, p.seguridad]) {
        expect(contraste(Bahia.tintaSobre(color), color), greaterThanOrEqualTo(4.5), reason: '$color');
      }
    }
  });

  test('las cápsulas de ruta admiten texto blanco (≥ 4,5:1)', () {
    for (final tipo in ['troncal', 'pretroncal', 'alimentadora', 'complementaria']) {
      expect(contraste(Colors.white, ColoresDeRuta.de(tipo)), greaterThanOrEqualTo(4.5), reason: tipo);
    }
  });

  test('cada tipo ilustrado tiene su SVG en los recursos', () async {
    for (final tipo in TipoIlustrado.values) {
      final svg = await rootBundle.loadString(tipo.recurso);
      expect(svg, startsWith('<svg'), reason: tipo.clave);
      expect(svg, contains('viewBox="0 0 64 64"'), reason: tipo.clave);
    }
    expect(TipoIlustrado.deClave('calle_inundada'), TipoIlustrado.calleInundada);
    expect(TipoIlustrado.deClave('no_existe'), isNull);
  });

  test('los estilos de mapa «Bahía» son estilos MapLibre v8 sobre OpenFreeMap', () async {
    for (final archivo in ['bahia_oscuro', 'bahia_claro']) {
      final estilo = jsonDecode(await rootBundle.loadString('assets/mapa/$archivo.json')) as Map<String, dynamic>;
      expect(estilo['version'], 8);
      expect((estilo['sources'] as Map).keys, contains('openmaptiles'));
      final capas = (estilo['layers'] as List).map((c) => c['id']).toSet();
      expect(capas, containsAll(['fondo', 'agua', 'principales', 'barrios']));
    }
  });
}
