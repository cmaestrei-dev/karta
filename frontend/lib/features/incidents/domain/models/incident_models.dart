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