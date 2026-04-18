class RouteRisk {
  final int score;
  final String nivel;
  final int totalIncidentes;
  final List<IncidentDetail> detalleIncidentes;

  RouteRisk({
    required this.score,
    required this.nivel,
    required this.totalIncidentes,
    required this.detalleIncidentes,
  });

  factory RouteRisk.fromJson(Map<String, dynamic> json) {
    return RouteRisk(
      score: json['score'] ?? 0,
      nivel: json['nivel'] ?? 'BAJO',
      totalIncidentes: json['total_incidentes'] ?? 0,
      detalleIncidentes: (json['detalle_incidentes'] as List<dynamic>?)
              ?.map((e) => IncidentDetail.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class IncidentDetail {
  final int id;
  final String categoria;
  final int intensidad;

  IncidentDetail({
    required this.id,
    required this.categoria,
    required this.intensidad,
  });

  factory IncidentDetail.fromJson(Map<String, dynamic> json) {
    return IncidentDetail(
      id: json['id'] ?? 0,
      categoria: json['categoria'] ?? '',
      intensidad: json['intensidad'] ?? 1,
    );
  }
}