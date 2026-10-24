import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/ilustracion.dart';

/// Códigos de Transcaribe que acepta el backend: T103, X104, A110, C001, T101E.
final patronDeRuta = RegExp(r'^[ATXC]\d{3}E?$');

/// Una opción de respuesta a una pregunta del reporte («20 min», «No se puede»).
class OpcionDeRespuesta extends Equatable {
  final String valor;
  final String etiqueta;

  const OpcionDeRespuesta(this.valor, this.etiqueta);

  factory OpcionDeRespuesta.fromJson(Map<String, dynamic> json) =>
      OpcionDeRespuesta(json['valor'] as String, json['etiqueta'] as String);

  @override
  List<Object?> get props => [valor, etiqueta];
}

/// Una pregunta concreta de un tipo de reporte. Tipo "ruta" = se responde con un código de Transcaribe.
class CampoDeReporte extends Equatable {
  final String clave;
  final String pregunta;
  final String tipo;
  final bool obligatorio;
  final List<OpcionDeRespuesta> opciones;

  const CampoDeReporte({
    required this.clave,
    required this.pregunta,
    required this.tipo,
    required this.obligatorio,
    required this.opciones,
  });

  bool get esRuta => tipo == 'ruta';

  factory CampoDeReporte.fromJson(Map<String, dynamic> json) => CampoDeReporte(
        clave: json['clave'] as String,
        pregunta: json['pregunta'] as String,
        tipo: json['tipo'] as String,
        obligatorio: json['obligatorio'] as bool,
        opciones: [for (final o in json['opciones'] as List) OpcionDeRespuesta.fromJson(o as Map<String, dynamic>)],
      );

  @override
  List<Object?> get props => [clave, pregunta, tipo, obligatorio, opciones];
}

/// Un tipo del catálogo del backend («El bus no pasa») con sus preguntas y cuánto vive sin confirmaciones.
class TipoDeReporte extends Equatable {
  final String clave;
  final String nombre;
  final String grupo;
  final int vigenciaMin;
  final List<CampoDeReporte> campos;

  const TipoDeReporte({
    required this.clave,
    required this.nombre,
    required this.grupo,
    required this.vigenciaMin,
    required this.campos,
  });

  TipoIlustrado? get ilustracion => TipoIlustrado.deClave(clave);

  /// Lo que dice el botón de enviar, con la ruta si ya se eligió: «el T103 no pasa», «trancón».
  String fraseDeEnvio(Map<String, String> respuestas) {
    final ruta = respuestas['ruta'];
    return switch (clave) {
      'bus_no_pasa' => ruta != null ? 'el $ruta no pasa' : 'el bus no pasa',
      'bus_lleno' => ruta != null ? 'el $ruta va lleno' : 'bus lleno',
      _ => nombre.isEmpty ? nombre : nombre[0].toLowerCase() + nombre.substring(1),
    };
  }

  /// «1 hora», «30 min», «12 horas»: cuánto vive el reporte si nadie lo confirma.
  String get vigenciaEnPalabras {
    if (vigenciaMin < 60) return '$vigenciaMin min';
    final horas = vigenciaMin ~/ 60;
    final resto = vigenciaMin % 60;
    final enHoras = horas == 1 ? '1 hora' : '$horas horas';
    return resto == 0 ? enHoras : '$enHoras y $resto min';
  }

  factory TipoDeReporte.fromJson(Map<String, dynamic> json, String grupo) => TipoDeReporte(
        clave: json['clave'] as String,
        nombre: json['nombre'] as String,
        grupo: grupo,
        vigenciaMin: json['vigencia_min'] as int,
        campos: [for (final c in json['campos'] as List) CampoDeReporte.fromJson(c as Map<String, dynamic>)],
      );

  @override
  List<Object?> get props => [clave, nombre, grupo, vigenciaMin, campos];
}

class GrupoDeReportes extends Equatable {
  final String clave;
  final String nombre;
  final List<TipoDeReporte> tipos;

  const GrupoDeReportes({required this.clave, required this.nombre, required this.tipos});

  factory GrupoDeReportes.fromJson(Map<String, dynamic> json) {
    final clave = json['clave'] as String;
    return GrupoDeReportes(
      clave: clave,
      nombre: json['nombre'] as String,
      tipos: [for (final t in json['tipos'] as List) TipoDeReporte.fromJson(t as Map<String, dynamic>, clave)],
    );
  }

  @override
  List<Object?> get props => [clave, nombre, tipos];
}

/// El catálogo completo, con búsqueda por clave.
class CatalogoDeReportes extends Equatable {
  final List<GrupoDeReportes> grupos;

  const CatalogoDeReportes(this.grupos);

  factory CatalogoDeReportes.fromJson(List<dynamic> json) =>
      CatalogoDeReportes([for (final g in json) GrupoDeReportes.fromJson(g as Map<String, dynamic>)]);

  TipoDeReporte? tipo(String clave) {
    for (final grupo in grupos) {
      for (final tipo in grupo.tipos) {
        if (tipo.clave == clave) return tipo;
      }
    }
    return null;
  }

  /// «Ruta T103 · 20 min»: las respuestas del reporte en palabras, en el orden de las preguntas.
  String resumen(Incident incidente) {
    final tipo = this.tipo(incidente.tipo);
    if (tipo == null) return '';
    final partes = <String>[];
    for (final campo in tipo.campos) {
      final valor = incidente.detalles[campo.clave];
      if (valor == null) continue;
      if (campo.esRuta) {
        partes.add('Ruta $valor');
      } else {
        final opcion = campo.opciones.where((o) => o.valor == valor).firstOrNull;
        if (opcion != null) partes.add(opcion.etiqueta);
      }
    }
    return partes.join(' · ');
  }

  @override
  List<Object?> get props => [grupos];
}

/// Reporte vigente de la comunidad, tal como lo dibuja el mapa.
class Incident extends Equatable {
  final String id;
  final String grupo;
  final String tipo;
  final Map<String, String> detalles;
  final double latitud;
  final double longitud;
  final String? lugar;
  final int votosSi;
  final int votosNo;
  final DateTime? creadoEn;
  final DateTime? expiraEn;

  const Incident({
    required this.id,
    required this.grupo,
    required this.tipo,
    required this.detalles,
    required this.latitud,
    required this.longitud,
    this.lugar,
    this.votosSi = 0,
    this.votosNo = 0,
    this.creadoEn,
    this.expiraEn,
  });

  LatLng get punto => LatLng(latitud, longitud);
  TipoIlustrado? get ilustracion => TipoIlustrado.deClave(tipo);

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'] as String,
        grupo: json['grupo'] as String,
        tipo: json['tipo'] as String,
        detalles: (json['detalles'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, '$v')),
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        lugar: json['lugar'] as String?,
        votosSi: json['votos_si'] as int? ?? 0,
        votosNo: json['votos_no'] as int? ?? 0,
        creadoEn: DateTime.tryParse(json['creado_en'] as String? ?? '')?.toLocal(),
        expiraEn: DateTime.tryParse(json['expira_en'] as String? ?? '')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, grupo, tipo, detalles, latitud, longitud, lugar, votosSi, votosNo, creadoEn, expiraEn];
}

/// Lo que se ve al tocar un reporte: quién lo hizo y si el viajero ya lo validó.
class IncidentDetail extends Equatable {
  final Incident incidente;
  final String aliasAutor;
  final bool esMio;
  final bool? miVoto;

  const IncidentDetail({required this.incidente, required this.aliasAutor, required this.esMio, this.miVoto});

  bool get puedeVotar => !esMio && miVoto == null;

  factory IncidentDetail.fromJson(Map<String, dynamic> json) => IncidentDetail(
        incidente: Incident.fromJson(json),
        aliasAutor: json['reportado_por_alias'] as String? ?? 'Un viajero',
        esMio: json['es_mio'] as bool? ?? false,
        miVoto: json['mi_voto'] as bool?,
      );

  IncidentDetail conVoto(Incident actualizado, bool sigue) =>
      IncidentDetail(incidente: actualizado, aliasAutor: aliasAutor, esMio: esMio, miVoto: sigue);

  @override
  List<Object?> get props => [incidente, aliasAutor, esMio, miVoto];
}
