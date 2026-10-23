import 'package:flutter/material.dart';

import '../../../../core/theme/karta_theme.dart';

class IncidentCreate {
  final String categoria;
  final int intensidad;
  final double latitud;
  final double longitud;

  IncidentCreate({
    required this.categoria,
    required this.intensidad,
    required this.latitud,
    required this.longitud,
  });

  /// El autor no viaja en el cuerpo: la API lo toma del token de sesión.
  Map<String, dynamic> toJson() {
    return {
      'categoria': categoria,
      'intensidad': intensidad,
      'latitud': latitud,
      'longitud': longitud,
    };
  }
}

class Incident {
  final String id;
  final String categoria;
  final int intensidad;
  final double latitud;
  final double longitud;
  final DateTime? creadoEn;
  final DateTime? expiraEn;

  Incident({
    required this.id,
    required this.categoria,
    required this.intensidad,
    required this.latitud,
    required this.longitud,
    this.creadoEn,
    this.expiraEn,
  });

  bool get esSeguridad => categoria == 'Seguridad';

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      categoria: json['categoria'] as String,
      intensidad: json['intensidad'] as int,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      creadoEn: DateTime.tryParse(json['creado_en'] as String? ?? '')?.toLocal(),
      expiraEn: DateTime.tryParse(json['expira_en'] as String? ?? '')?.toLocal(),
    );
  }
}

/// Apariencia de cada categoría: ocre para precaución (tráfico), ladrillo para peligro (seguridad).
/// Qué pasa: nombre y glifo de la categoría. El color del incidente lo pone su intensidad.
class IncidentCategoryStyle {
  final String nombre;
  final IconData icono;

  const IncidentCategoryStyle(this.nombre, this.icono);

  static const trafico = IncidentCategoryStyle('Tráfico', Icons.directions_car_filled);
  static const seguridad = IncidentCategoryStyle('Seguridad', Icons.gpp_maybe);

  static IncidentCategoryStyle of(String categoria) => categoria == 'Seguridad' ? seguridad : trafico;
}

/// Qué tan fuerte es, con la misma escala de color del riesgo de las rutas:
/// 1–2 leve/bajo (verde balcón), 3 medio (ocre), 4 fuerte (ladrillo), 5 grave (ladrillo profundo).
class IntensityStyle {
  final Color color;
  final Color onColor;

  const IntensityStyle(this.color, this.onColor);

  static IntensityStyle of(int intensidad) => switch (intensidad) {
        <= 2 => const IntensityStyle(KartaColors.balcon, Colors.white),
        3 => const IntensityStyle(KartaColors.ocre, KartaColors.tintaSobreOcre),
        4 => const IntensityStyle(KartaColors.ladrillo, Colors.white),
        _ => const IntensityStyle(KartaColors.ladrilloProfundo, Colors.white),
      };
}

/// Significado de la escala de intensidad, para que 1–5 no sea un número sin ancla.
const etiquetasIntensidad = {1: 'Leve', 2: 'Bajo', 3: 'Medio', 4: 'Fuerte', 5: 'Grave'};
