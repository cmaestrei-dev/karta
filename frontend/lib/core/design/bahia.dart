import 'package:flutter/material.dart';

/// Sistema de diseño «Bahía»: noche de bahía con verde agua (oscuro) y su versión clara para el sol.
///
/// Los colores de grupo (servicio, vía, seguridad) y de tipo de ruta son código: dicen qué es algo,
/// nunca decoran. Se leen desde el tema con `Bahia.de(context)`.
@immutable
class Bahia extends ThemeExtension<Bahia> {
  final Color fondo;
  final Color hoja;
  final Color tarjeta;
  final Color campo;
  final Color asa;
  final Color texto;
  final Color textoSuave;
  final Color divisor;
  final Color acento;
  final Color sobreAcento;
  final Color acentoSuave;
  final Color reportar;
  final Color sobreReportar;
  final Color enVivo;
  final Color servicio;
  final Color via;
  final Color seguridad;
  final Color servicioSuave;
  final Color viaSuave;
  final Color seguridadSuave;

  /// Línea de la troncal sobre el mapa y el borde que la separa del fondo.
  final Color troncal;
  final Color bordeDeRuta;

  const Bahia({
    required this.fondo,
    required this.hoja,
    required this.tarjeta,
    required this.campo,
    required this.asa,
    required this.texto,
    required this.textoSuave,
    required this.divisor,
    required this.acento,
    required this.sobreAcento,
    required this.acentoSuave,
    required this.reportar,
    required this.sobreReportar,
    required this.enVivo,
    required this.servicio,
    required this.via,
    required this.seguridad,
    required this.servicioSuave,
    required this.viaSuave,
    required this.seguridadSuave,
    required this.troncal,
    required this.bordeDeRuta,
  });

  static const oscura = Bahia(
    fondo: Color(0xFF0B1621),
    hoja: Color(0xFF0F1C29),
    tarjeta: Color(0xFF162738),
    campo: Color(0xFF1D3246),
    asa: Color(0xFF3A5168),
    texto: Color(0xFFEAF2F7),
    textoSuave: Color(0xFF9DB2C4),
    divisor: Color(0x14EAF2F7),
    acento: Color(0xFF3DDBB5),
    sobreAcento: Color(0xFF04261D),
    acentoSuave: Color(0x243DDBB5),
    reportar: Color(0xFFFFC247),
    sobreReportar: Color(0xFF2A1C00),
    enVivo: Color(0xFF4BE38B),
    servicio: Color(0xFF7FA8FF),
    via: Color(0xFFFFC247),
    seguridad: Color(0xFFFF7A6B),
    servicioSuave: Color(0x297FA8FF),
    viaSuave: Color(0x29FFC247),
    seguridadSuave: Color(0x29FF7A6B),
    troncal: Color(0xFF2EC4B6),
    bordeDeRuta: Color(0xFF0B1621),
  );

  static const clara = Bahia(
    fondo: Color(0xFFEEF3F6),
    hoja: Color(0xFFFFFFFF),
    tarjeta: Color(0xFFF1F5F8),
    campo: Color(0xFFE8EFF3),
    asa: Color(0xFFC3CFD6),
    texto: Color(0xFF0B1621),
    textoSuave: Color(0xFF4B5F70),
    divisor: Color(0x140B1621),
    acento: Color(0xFF0B7F66),
    sobreAcento: Color(0xFFFFFFFF),
    acentoSuave: Color(0x1F0B7F66),
    reportar: Color(0xFFFFB61E),
    sobreReportar: Color(0xFF2A1C00),
    enVivo: Color(0xFF0E8F4A),
    servicio: Color(0xFF2F5BD3),
    via: Color(0xFFD99400),
    seguridad: Color(0xFFD23B2C),
    servicioSuave: Color(0x1F2F5BD3),
    viaSuave: Color(0x29E9A400),
    seguridadSuave: Color(0x1FD23B2C),
    troncal: Color(0xFF0B6E6E),
    bordeDeRuta: Color(0xFFFFFFFF),
  );

  static Bahia de(BuildContext context) => Theme.of(context).extension<Bahia>() ?? oscura;

  /// Tinta legible sobre un color de relleno: oscura sobre los claros, blanca sobre los oscuros.
  static Color tintaSobre(Color relleno) =>
      ThemeData.estimateBrightnessForColor(relleno) == Brightness.light ? const Color(0xFF14181F) : Colors.white;

  /// Color y fondo suave de un grupo de reporte ("servicio", "via" o "seguridad").
  (Color, Color) delGrupo(String grupo) => switch (grupo) {
        'servicio' => (servicio, servicioSuave),
        'seguridad' => (seguridad, seguridadSuave),
        _ => (via, viaSuave),
      };

  @override
  Bahia copyWith() => this;

  @override
  Bahia lerp(Bahia? otra, double t) {
    if (otra == null) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return Bahia(
      fondo: m(fondo, otra.fondo),
      hoja: m(hoja, otra.hoja),
      tarjeta: m(tarjeta, otra.tarjeta),
      campo: m(campo, otra.campo),
      asa: m(asa, otra.asa),
      texto: m(texto, otra.texto),
      textoSuave: m(textoSuave, otra.textoSuave),
      divisor: m(divisor, otra.divisor),
      acento: m(acento, otra.acento),
      sobreAcento: m(sobreAcento, otra.sobreAcento),
      acentoSuave: m(acentoSuave, otra.acentoSuave),
      reportar: m(reportar, otra.reportar),
      sobreReportar: m(sobreReportar, otra.sobreReportar),
      enVivo: m(enVivo, otra.enVivo),
      servicio: m(servicio, otra.servicio),
      via: m(via, otra.via),
      seguridad: m(seguridad, otra.seguridad),
      servicioSuave: m(servicioSuave, otra.servicioSuave),
      viaSuave: m(viaSuave, otra.viaSuave),
      seguridadSuave: m(seguridadSuave, otra.seguridadSuave),
      troncal: m(troncal, otra.troncal),
      bordeDeRuta: m(bordeDeRuta, otra.bordeDeRuta),
    );
  }
}

/// Colores de los tipos de ruta de Transcaribe: iguales en los dos temas y con texto blanco legible.
abstract final class ColoresDeRuta {
  static const troncal = Color(0xFF0B6E6E);
  static const pretroncal = Color(0xFFA61E5A);
  static const alimentadora = Color(0xFF7A4A1C);
  static const complementaria = Color(0xFF5B3A8C);

  static Color de(String? tipo) => switch (tipo) {
        'troncal' => troncal,
        'pretroncal' => pretroncal,
        'alimentadora' => alimentadora,
        'complementaria' => complementaria,
        _ => const Color(0xFF4B5F70),
      };
}

/// Niveles de riesgo de una ruta. Iguales en los dos temas; el nivel siempre va también con ícono y texto.
abstract final class ColoresDeRiesgo {
  static const critico = Color(0xFF7F1D12);
  static const alto = Color(0xFFB23A26);
  static const medio = Color(0xFFE3A72F);
  static const sobreMedio = Color(0xFF2A1E00);
  static const bajo = Color(0xFF2E7D4F);
  static const sinDatos = Color(0xFF4B5F70);
}

/// Cifras de ancho fijo: los minutos y metros de distintas opciones quedan alineados.
const tabularFigures = [FontFeature.tabularFigures()];

/// Familia tipográfica del sistema, empaquetada en la app (assets/fonts/Manrope-*.ttf).
const fuenteBahia = 'Manrope';
