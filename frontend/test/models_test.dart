import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/routing/domain/models/route_risk.dart';
import 'package:karta/features/routing/presentation/risk_style.dart';

void main() {
  group('RiskStyle.forLevel', () {
    test('CRÍTICO se muestra en rojo, nunca en verde', () {
      expect(RiskStyle.forLevel('CRÍTICO').color, Colors.red);
      expect(RiskStyle.forLevel('CRITICO').color, Colors.red);
    });

    test('cada nivel conocido tiene su color', () {
      expect(RiskStyle.forLevel('ALTO').color, Colors.redAccent);
      expect(RiskStyle.forLevel('MEDIO').color, Colors.orangeAccent);
      expect(RiskStyle.forLevel('BAJO').color, Colors.green);
    });

    test('un nivel desconocido no se presenta como seguro', () {
      expect(RiskStyle.forLevel('???').color, isNot(Colors.green));
    });
  });

  test('RouteRisk.fromJson interpreta la respuesta de /routes/risk', () {
    final risk = RouteRisk.fromJson({
      'score': 75,
      'nivel': 'CRÍTICO',
      'total_incidentes': 1,
      'detalle_incidentes': [
        {'id': 1, 'categoria': 'Seguridad', 'intensidad': 5},
      ],
    });

    expect(risk.score, 75);
    expect(risk.nivel, 'CRÍTICO');
    expect(risk.detalleIncidentes.single.categoria, 'Seguridad');
  });
}
