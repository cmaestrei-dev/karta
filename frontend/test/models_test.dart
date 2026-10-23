import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/format.dart';
import 'package:karta/core/theme/karta_theme.dart';
import 'package:karta/core/widgets/risk_badge.dart';
import 'package:karta/features/incidents/domain/models/incident_models.dart';
import 'package:karta/features/places/domain/place_models.dart';
import 'package:karta/features/trip/domain/trip_models.dart';

void main() {
  group('RiskStyle.forLevel', () {
    test('cada nivel tiene su color, ícono y texto', () {
      expect(RiskStyle.forLevel('CRÍTICO').color, KartaColors.ladrilloProfundo);
      expect(RiskStyle.forLevel('CRITICO').color, KartaColors.ladrilloProfundo);
      expect(RiskStyle.forLevel('ALTO').color, KartaColors.ladrillo);
      expect(RiskStyle.forLevel('MEDIO').color, KartaColors.ocre);
      expect(RiskStyle.forLevel('BAJO').color, KartaColors.balcon);
      expect(RiskStyle.forLevel('BAJO').etiqueta, 'Riesgo bajo');
    });

    test('un nivel desconocido no se presenta como seguro', () {
      final desconocido = RiskStyle.forLevel('???');
      expect(desconocido.color, isNot(KartaColors.balcon));
      expect(desconocido.icon, Icons.help_outline);
    });

    test('sobre el ocre el texto es oscuro, nunca blanco', () {
      expect(RiskStyle.forLevel('MEDIO').onColor, KartaColors.tintaSobreOcre);
    });
  });

  test('RouteSuggestions.fromJson lee los tramos y convierte GeoJSON [lon, lat]', () {
    final sugerencias = RouteSuggestions.fromJson({
      'opciones': [
        {
          'resumen': 'Transcaribe T103',
          'tiempo_total_min': 29,
          'distancia_caminata_m': 427,
          'tramos': [
            {
              'modo': 'bus',
              'desde': 'Estación Bazurto',
              'hasta': 'Paradero cerca de Bocagrande',
              'distancia_m': 6650,
              'duracion_min': 18,
              'espera_min': 5,
              'ruta': 'T103',
              'nombre_ruta': 'Troncal 103',
              'tipo_ruta': 'troncal',
              'geometria': {
                'type': 'LineString',
                'coordinates': [
                  [-75.5245, 10.4135],
                  [-75.5545, 10.399],
                ],
              },
            },
          ],
          'riesgo': {'score': 12, 'nivel': 'MEDIO', 'total_incidentes': 2},
        },
      ],
      'nota': 'Tiempos estimados.',
      'fuente': 'OpenStreetMap',
    });

    final opcion = sugerencias.opciones.single;
    expect(opcion.bus?.ruta, 'T103');
    expect(opcion.puntos.first.latitude, 10.4135);
    expect(opcion.puntos.first.longitude, -75.5245);
    expect(opcion.riesgo.nivel, 'MEDIO');
  });

  test('un riesgo sin nivel no se asume bajo', () {
    final riesgo = RiskSummary.fromJson({'score': 0, 'total_incidentes': 0});
    expect(RiskStyle.forLevel(riesgo.nivel).etiqueta, 'Riesgo sin datos');
  });

  test('Incident.fromJson lee los ids de MongoDB y las fechas', () {
    final incidente = Incident.fromJson({
      'id': '665f1c2b9a1e4b0012345678',
      'categoria': 'Seguridad',
      'intensidad': 4,
      'latitud': 10.42,
      'longitud': -75.54,
      'creado_en': '2026-10-22T18:00:00Z',
      'expira_en': '2026-10-23T06:00:00Z',
    });
    expect(incidente.esSeguridad, isTrue);
    expect(incidente.expiraEn!.difference(incidente.creadoEn!), const Duration(hours: 12));
  });

  test('tipo de ruta según el código', () {
    expect(tipoDeRuta('T101'), 'troncal');
    expect(tipoDeRuta('X105'), 'pretroncal');
    expect(tipoDeRuta('A104'), 'alimentadora');
    expect(tipoDeRuta('C001'), 'complementaria');
    expect(SavedPlaceIcon.fromApi('desconocido'), SavedPlaceIcon.favorito);
  });

  test('formatos en español', () {
    expect(metros(347), '350${nbsp}m');
    expect(metros(1240), '1,2${nbsp}km');
    expect(minutos(4), '4${nbsp}min');
    final ahora = DateTime(2026, 10, 23, 12);
    expect(haceCuanto(ahora.subtract(const Duration(minutes: 25)), ahora: ahora), 'hace 25 min');
    expect(dentroDe(ahora.add(const Duration(hours: 2, minutes: 35)), ahora: ahora), '2 h 35 min');
  });

  test('el color del incidente sube con su intensidad', () {
    // La misma escala del riesgo: bajo verde, medio ocre, alto ladrillo, crítico ladrillo profundo.
    expect(IntensityStyle.of(1).color, KartaColors.balcon);
    expect(IntensityStyle.of(2).color, KartaColors.balcon);
    expect(IntensityStyle.of(3).color, KartaColors.ocre);
    expect(IntensityStyle.of(3).onColor, KartaColors.tintaSobreOcre);
    expect(IntensityStyle.of(4).color, KartaColors.ladrillo);
    expect(IntensityStyle.of(5).color, KartaColors.ladrilloProfundo);
  });

  test('los colores de ruta no se confunden con la interfaz ni con el riesgo', () {
    final reservados = <Color>{
      KartaColors.cobalto, KartaColors.ocre, KartaColors.ladrillo, KartaColors.ladrilloProfundo, KartaColors.balcon,
    };
    for (final ruta in const [
      KartaColors.troncal, KartaColors.pretroncal, KartaColors.alimentadora, KartaColors.complementaria,
    ]) {
      expect(reservados.contains(ruta), isFalse);
    }
  });

  test('Stop.fromJson usa la caminata estimada por el backend', () {
    final estacion = Stop.fromJson({
      'id': 'bazurto',
      'nombre': 'Bazurto',
      'latitud': 10.4135,
      'longitud': -75.5245,
      'rutas': ['T101', 'X104'],
      'distancia_m': 48,
      'caminata_m': 62,
      'caminata_min': 1,
    });
    expect(estacion.caminataM, 62);
    expect(estacion.caminataMin, 1);
    expect(estacion.rutas, ['T101', 'X104']);
  });
}
