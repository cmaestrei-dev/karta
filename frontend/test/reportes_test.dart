import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/incidents/domain/models/incident_models.dart';

import 'datos/reportes.dart';

void main() {
  final catalogo = CatalogoDeReportes.fromJson(catalogoJson);

  group('catálogo de reportes', () {
    test('lee los grupos, los tipos y sus preguntas', () {
      expect(catalogo.grupos.map((g) => g.clave), ['servicio', 'via']);
      final noPasa = catalogo.tipo('bus_no_pasa')!;
      expect(noPasa.grupo, 'servicio');
      expect(noPasa.campos.first.esRuta, isTrue);
      expect(noPasa.campos.last.opciones.map((o) => o.etiqueta), ['10 min', '20 min', '30 min o más']);
      expect(noPasa.ilustracion?.clave, 'bus_no_pasa');
      expect(catalogo.tipo('no_existe'), isNull);
    });

    test('resume las respuestas en palabras, en el orden de las preguntas', () {
      expect(catalogo.resumen(Incident.fromJson(incidenteJson())), 'Ruta T103 · 20 min');
      final inundada = Incident.fromJson(incidenteJson(tipo: 'calle_inundada', detalles: {'paso': 'no_se_puede'}));
      expect(catalogo.resumen(inundada), 'No se puede');
      expect(catalogo.resumen(Incident.fromJson(incidenteJson(tipo: 'trancon', detalles: {}))), '');
    });

    test('el botón de enviar dice qué se reporta', () {
      final noPasa = catalogo.tipo('bus_no_pasa')!;
      expect(noPasa.fraseDeEnvio({'ruta': 'T103'}), 'el T103 no pasa');
      expect(noPasa.fraseDeEnvio({}), 'el bus no pasa');
      expect(catalogo.tipo('calle_inundada')!.fraseDeEnvio({}), 'calle inundada');
      const noParo = TipoDeReporte(clave: 'bus_lleno', nombre: 'El bus no paró', grupo: 'servicio', vigenciaMin: 30, campos: []);
      expect(noParo.fraseDeEnvio({'ruta': 'X103', 'motivo': 'no_se_acerco'}), 'el X103 no paró');
      expect(noParo.fraseDeEnvio({}), 'el bus no paró');
    });

    test('la vigencia se dice en palabras', () {
      expect(catalogo.tipo('bus_no_pasa')!.vigenciaEnPalabras, '1 hora');
      expect(catalogo.tipo('estacion_cerrada')!.vigenciaEnPalabras, '4 horas');
      expect(catalogo.tipo('bus_no_pasa')!.vigenciaEnPalabras, '1 hora');
      const corto = TipoDeReporte(clave: 'x', nombre: 'X', grupo: 'via', vigenciaMin: 30, campos: []);
      const largo = TipoDeReporte(clave: 'x', nombre: 'X', grupo: 'via', vigenciaMin: 90, campos: []);
      expect(corto.vigenciaEnPalabras, '30 min');
      expect(largo.vigenciaEnPalabras, '1 hora y 30 min');
    });

    test('solo acepta códigos de ruta de Transcaribe', () {
      for (final codigo in ['T103', 'X104', 'A110', 'C001', 'T101E']) {
        expect(patronDeRuta.hasMatch(codigo), isTrue, reason: codigo);
      }
      for (final codigo in ['103', 'T10', 'B103', 't103', 'T1034']) {
        expect(patronDeRuta.hasMatch(codigo), isFalse, reason: codigo);
      }
    });
  });

  group('Incident', () {
    test('fromJson lee tipo, detalles, lugar, votos y fechas', () {
      final incidente = Incident.fromJson(incidenteJson(votosSi: 3));
      expect(incidente.grupo, 'servicio');
      expect(incidente.detalles, {'ruta': 'T103', 'espera': '20'});
      expect(incidente.lugar, 'Estación Bazurto');
      expect(incidente.votosSi, 3);
      expect(incidente.expiraEn!.difference(incidente.creadoEn!), const Duration(hours: 1));
      expect(incidente.punto.latitude, 10.4139);
    });

    test('el detalle sabe si el viajero puede votar', () {
      final base = {...incidenteJson(), 'reportado_por_alias': 'Ana P.'};
      final ajeno = IncidentDetail.fromJson({...base, 'es_mio': false});
      expect(ajeno.puedeVotar, isTrue);
      expect(ajeno.aliasAutor, 'Ana P.');
      expect(IncidentDetail.fromJson({...base, 'es_mio': true}).puedeVotar, isFalse);
      expect(IncidentDetail.fromJson({...base, 'es_mio': false, 'mi_voto': true}).puedeVotar, isFalse);
      expect(ajeno.conVoto(ajeno.incidente, false).miVoto, isFalse);
      // El nivel del autor se conserva al votar y al agradecer; si no viene, es 1.
      final confiable = IncidentDetail.fromJson({...base, 'es_mio': false, 'nivel_autor': 4});
      expect(confiable.conVoto(confiable.incidente, true).nivelAutor, 4);
      expect(confiable.conGracias(confiable.incidente).nivelAutor, 4);
      expect(ajeno.nivelAutor, 1);
    });
  });
}
