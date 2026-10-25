import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/format.dart';
import 'package:karta/core/design/bahia.dart';
import 'package:karta/features/auth/domain/models/usuario.dart';
import 'package:karta/core/widgets/risk_badge.dart';
import 'package:karta/features/places/domain/place_models.dart';
import 'package:karta/features/trip/domain/trip_models.dart';

void main() {
  group('RiskStyle.forLevel', () {
    test('cada nivel tiene su color, ícono y texto', () {
      expect(RiskStyle.forLevel('CRÍTICO').color, ColoresDeRiesgo.critico);
      expect(RiskStyle.forLevel('CRITICO').color, ColoresDeRiesgo.critico);
      expect(RiskStyle.forLevel('ALTO').color, ColoresDeRiesgo.alto);
      expect(RiskStyle.forLevel('MEDIO').color, ColoresDeRiesgo.medio);
      expect(RiskStyle.forLevel('BAJO').color, ColoresDeRiesgo.bajo);
      expect(RiskStyle.forLevel('BAJO').etiqueta, 'Riesgo bajo');
    });

    test('un nivel desconocido no se presenta como seguro', () {
      final desconocido = RiskStyle.forLevel('???');
      expect(desconocido.color, isNot(ColoresDeRiesgo.bajo));
      expect(desconocido.icon, Icons.help_outline);
    });

    test('sobre el ocre el texto es oscuro, nunca blanco', () {
      expect(RiskStyle.forLevel('MEDIO').onColor, ColoresDeRiesgo.sobreMedio);
    });
  });

  test('la caminata de un transbordo integrado trae cómo hacerlo, y la franja usa la primera frase', () {
    final cambio = Leg.fromJson({
      'modo': 'caminata', 'desde': 'Estación Santa Lucía', 'hasta': 'Estación Madre Bernarda', 'distancia_m': 40,
      'duracion_min': 2, 'espera_min': 0,
      'indicacion': 'Sal de Santa Lucía y cruza por la cebra hasta Madre Bernarda: 40 m. Al entrar vuelves a pasar '
          'la tarjeta, pero no te cobra si cambias en menos de 90 minutos.',
      'geometria': {'type': 'LineString', 'coordinates': [[-75.478, 10.3952], [-75.4786, 10.3951]]},
    });
    expect(cambio.indicacionCorta, 'Sal de Santa Lucía y cruza por la cebra hasta Madre Bernarda: 40 m');
    expect(cambio.comoAbordar, isNull);
    final t101 = Leg.fromJson({
      'modo': 'bus', 'desde': 'Estación Madre Bernarda', 'hasta': 'Estación La Bodeguita', 'distancia_m': 9000,
      'duracion_min': 26, 'espera_min': 5, 'ruta': 'T101', 'modulo': 'A1', 'hacia': 'Centro',
      'geometria': {'type': 'LineString', 'coordinates': [[-75.4786, 10.3951], [-75.5514, 10.42]]},
    });
    expect(t101.comoAbordar, 'módulo A1, hacia Centro');
    expect(const Leg(modo: 'caminata', desde: 'a', hasta: 'b', distanciaM: 1, duracionMin: 1, esperaMin: 0, puntos: [])
        .indicacionCorta, isNull);
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

  test('los colores de ruta no se confunden con los de riesgo', () {
    final riesgo = <Color>{
      ColoresDeRiesgo.critico, ColoresDeRiesgo.alto, ColoresDeRiesgo.medio, ColoresDeRiesgo.bajo, ColoresDeRiesgo.sinDatos,
    };
    for (final tipo in ['troncal', 'pretroncal', 'alimentadora', 'complementaria']) {
      expect(riesgo.contains(ColoresDeRuta.de(tipo)), isFalse, reason: tipo);
    }
  });

  test('RutaEnMapa.fromJson convierte el trazado GeoJSON [lon, lat]', () {
    final ruta = RutaEnMapa.fromJson({
      'codigo': 'T103',
      'nombre': 'Troncal 103',
      'tipo': 'troncal',
      'geometria': {
        'type': 'LineString',
        'coordinates': [
          [-75.5245, 10.4135],
          [-75.5545, 10.399],
        ],
      },
    });
    expect(ruta.puntos.first.latitude, 10.4135);
    expect(ruta.puntos.last.longitude, -75.5545);
  });

  group('Usuario', () {
    test('un perfil guardado antes de los reportes v2 calcula alias y nivel como el backend', () {
      final usuario = Usuario.fromJson({
        'id': '1', 'email': 'ana@karta.app', 'nombre': 'Ana María Pérez', 'tipo_viajero': 'Residente', 'reputacion': 205,
      });
      expect(usuario.alias, 'Ana M.');
      expect(usuario.nivel, 3);
      expect(usuario.iniciales, 'AM');
      expect(usuario.faltaParaSubir, 95);
    });

    test('los niveles empiezan en 150, 200, 300 y 450', () {
      expect(nivelPorReputacion(100), 1);
      expect(nivelPorReputacion(149), 1);
      expect(nivelPorReputacion(150), 2);
      expect(nivelPorReputacion(300), 4);
      expect(nivelPorReputacion(999), 5);
      expect(aliasPublico('  '), 'Viajero');
      expect(aliasPublico('Camilo'), 'Camilo');
    });

    test('en el nivel más alto no falta nada para subir', () {
      final usuario = Usuario.fromJson({
        'id': '1', 'email': 'a@b.co', 'nombre': 'Ana', 'tipo_viajero': 'Residente', 'reputacion': 460,
        'alias': 'Ana', 'nivel': 5,
      });
      expect(usuario.faltaParaSubir, isNull);
      expect(Usuario.fromJson(usuario.toJson()), usuario);
    });

    test('el marco sale del nivel; las insignias y la siguiente vienen del servidor y se guardan', () {
      final usuario = Usuario.fromJson({
        'id': '1', 'email': 'a@b.co', 'nombre': 'Ana', 'tipo_viajero': 'Residente', 'reputacion': 210,
        'alias': 'Ana', 'nivel': 3,
        'insignias': [
          {'clave': 'primer_aviso', 'nombre': 'Primer aviso', 'descripcion': 'Alguien confirmó uno de tus reportes'},
        ],
        'siguiente_insignia': {
          'insignia': {'clave': 'ojo_de_halcon', 'nombre': 'Ojo de halcón', 'descripcion': '…'},
          'llevas': 3, 'meta': 10, 'unidad': 'confirmaciones',
        },
      });
      expect(usuario.marco, 'Bahía');
      expect(usuario.insignias.single.nombre, 'Primer aviso');
      expect(usuario.siguienteInsignia!.fraccion, closeTo(0.3, 1e-9));
      expect(Usuario.fromJson(usuario.toJson()), usuario);
      expect(Usuario.fromJson({'id': '2', 'reputacion': 100}).marco, isNull);
      expect(Usuario.fromJson({'id': '2', 'reputacion': 100}).insignias, isEmpty);
    });
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

  group('resaltar lo que coincide en el buscador', () {
    test('marca el comienzo de palabra sin importar tildes ni mayúsculas', () {
      expect(tramosResaltados('Bocagrande', 'boca'), [('Boca', true), ('grande', false)]);
      expect(tramosResaltados('Centro Comercial Bocagrande', 'BOCA'),
          [('Centro Comercial ', false), ('Boca', true), ('grande', false)]);
      expect(tramosResaltados('Estación Bazurto', 'estacion baz'), [('Estación', true), (' ', false), ('Baz', true), ('urto', false)]);
    });

    test('no marca coincidencias en medio de una palabra', () {
      expect(tramosResaltados('Embocadura', 'boca'), [('Embocadura', false)]);
      expect(tramosResaltados('La Popa', 'a'), [('La Popa', false)]);
    });
  });

  test('horas del horario en formato de Colombia', () {
    expect(horaLegible('05:30'), '5:30${nbsp}a.${nbsp}m.');
    expect(horaLegible('21:00'), '9:00${nbsp}p.${nbsp}m.');
    expect(horaLegible('12:15'), '12:15${nbsp}p.${nbsp}m.');
    expect(horaLegible('00:05'), '12:05${nbsp}a.${nbsp}m.');
  });

  test('una dirección del buscador muestra su detalle y su ícono', () {
    final lugar = Place.fromJson({
      'id': null, 'nombre': 'Calle 9 # 3-50', 'tipo': 'Dirección', 'latitud': 10.4043, 'longitud': -75.5524,
      'detalle': 'Dirección aproximada · Bocagrande',
    });
    expect(lugar.subtitulo, 'Dirección aproximada · Bocagrande');
    expect(lugar.icono, Icons.signpost_outlined);
    const barrio = Place(nombre: 'Bocagrande', tipo: 'Barrio', punto: LatLng(10.399, -75.554));
    expect(barrio.subtitulo, 'Barrio'); // sin detalle, el tipo
  });
}
