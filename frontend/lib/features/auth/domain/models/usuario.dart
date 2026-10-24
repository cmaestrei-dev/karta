import 'package:equatable/equatable.dart';

class Usuario extends Equatable {
  final String id;
  final String email;
  final String nombre;
  final String tipoViajero;
  final int reputacion;

  /// Nombre corto que ven los demás viajeros en los reportes («Ana P.»).
  final String alias;

  /// Nivel de 1 a 5 según la reputación: sube cuando la comunidad confirma tus reportes.
  final int nivel;

  const Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.tipoViajero,
    required this.reputacion,
    required this.alias,
    required this.nivel,
  });

  /// Las iniciales del avatar: «Camilo Maestre» → «CM».
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// Reputación que falta para el siguiente nivel, o null en el nivel máximo.
  int? get faltaParaSubir {
    final siguiente = umbralesDeNivel.where((u) => u > reputacion).firstOrNull;
    return siguiente == null ? null : siguiente - reputacion;
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final nombre = json['nombre'] as String;
    final reputacion = json['reputacion'] as int;
    return Usuario(
      id: json['id'] as String,
      email: json['email'] as String,
      nombre: nombre,
      tipoViajero: json['tipo_viajero'] as String,
      reputacion: reputacion,
      // Un perfil guardado antes de los reportes v2 no trae alias ni nivel: se calculan igual que el backend.
      alias: json['alias'] as String? ?? aliasPublico(nombre),
      nivel: json['nivel'] as int? ?? nivelPorReputacion(reputacion),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': nombre,
        'tipo_viajero': tipoViajero,
        'reputacion': reputacion,
        'alias': alias,
        'nivel': nivel,
      };

  @override
  List<Object> get props => [id, email, nombre, tipoViajero, reputacion, alias, nivel];
}

/// Reputación con la que empieza cada nivel, del 2 al 5 (todos arrancan en 100, nivel 1).
const umbralesDeNivel = [150, 200, 300, 450];

int nivelPorReputacion(int reputacion) => 1 + umbralesDeNivel.where((u) => reputacion >= u).length;

/// «Ana María Pérez» → «Ana M.»: el primer nombre y la inicial del siguiente.
String aliasPublico(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return 'Viajero';
  return partes.length > 1 ? '${partes[0]} ${partes[1][0].toUpperCase()}.' : partes[0];
}
