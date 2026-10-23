import 'package:equatable/equatable.dart';

class Usuario extends Equatable {
  final String id;
  final String email;
  final String nombre;
  final String tipoViajero;
  final int reputacion;

  const Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.tipoViajero,
    required this.reputacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      email: json['email'] as String,
      nombre: json['nombre'] as String,
      tipoViajero: json['tipo_viajero'] as String,
      reputacion: json['reputacion'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': nombre,
        'tipo_viajero': tipoViajero,
        'reputacion': reputacion,
      };

  @override
  List<Object> get props => [id, email, nombre, tipoViajero, reputacion];
}
