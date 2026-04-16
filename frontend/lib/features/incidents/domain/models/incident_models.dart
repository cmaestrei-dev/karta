class IncidentCreate {
  final int idUsuario;
  final String categoria;
  final int intensidad;
  final double latitud;
  final double longitud;

  IncidentCreate({
    required this.idUsuario,
    required this.categoria,
    required this.intensidad,
    required this.latitud,
    required this.longitud,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': idUsuario,
      'categoria': categoria,
      'intensidad': intensidad,
      'latitud': latitud,
      'longitud': longitud,
    };
  }
}

class Incident {
  final int id;
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
      id: json['id_incidente'] as int,
      categoria: json['categoria'] as String,
      intensidad: json['intensidad'] as int,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
    );
  }
}