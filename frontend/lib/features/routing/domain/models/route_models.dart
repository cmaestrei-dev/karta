class RouteOption {
  final String modalidad;
  final int tiempoMinutos;
  final int costoCop;

  RouteOption({
    required this.modalidad,
    required this.tiempoMinutos,
    required this.costoCop,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      modalidad: json['modalidad'] ?? '',
      tiempoMinutos: json['tiempo_minutos'] ?? 0,
      costoCop: json['costo_cop'] ?? 0,
    );
  }
}

class DecisionResponse {
  final RouteOption opcionActual;
  final RouteOption opcionAlternativa;
  final bool sugiereSalto;
  final int tiempoAhorrado;

  DecisionResponse({
    required this.opcionActual,
    required this.opcionAlternativa,
    required this.sugiereSalto,
    required this.tiempoAhorrado,
  });

  factory DecisionResponse.fromJson(Map<String, dynamic> json) {
    return DecisionResponse(
      opcionActual: RouteOption.fromJson(json['opcion_actual']),
      opcionAlternativa: RouteOption.fromJson(json['opcion_alternativa']),
      sugiereSalto: json['sugiere_salto'] ?? false,
      tiempoAhorrado: json['tiempo_ahorrado'] ?? 0,
    );
  }
}