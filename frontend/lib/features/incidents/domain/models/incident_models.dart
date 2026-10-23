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

  Incident({
    required this.id,
    required this.categoria,
    required this.intensidad,
    required this.latitud,
    required this.longitud,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      categoria: json['categoria'] as String,
      intensidad: json['intensidad'] as int,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
    );
  }
}
