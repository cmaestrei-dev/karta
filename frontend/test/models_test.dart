import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/incidents/domain/models/incident_models.dart';
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
        {'id': '665f1c2b9a1e4b0012345678', 'categoria': 'Seguridad', 'intensidad': 5},
      ],
    });

    expect(risk.score, 75);
    expect(risk.nivel, 'CRÍTICO');
    expect(risk.detalleIncidentes.single.categoria, 'Seguridad');
    expect(risk.detalleIncidentes.single.id, '665f1c2b9a1e4b0012345678');
  });

  test('Incident.fromJson acepta los ids de MongoDB', () {
    final incident = Incident.fromJson({
      'id': '665f1c2b9a1e4b0012345678',
      'categoria': 'Tráfico',
      'intensidad': 3,
      'latitud': 10.42,
      'longitud': -75.54,
      'creado_en': '2026-10-22T18:00:00Z',
      'expira_en': '2026-10-22T21:00:00Z',
    });
    expect(incident.id, '665f1c2b9a1e4b0012345678');
    expect(incident.latitud, 10.42);
  });
}
