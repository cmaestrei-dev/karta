import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Lugar de Cartagena que devuelve el buscador o "elegir en el mapa".
class Place extends Equatable {
  final String? id;
  final String nombre;
  final String tipo;
  final LatLng punto;

  const Place({this.id, required this.nombre, required this.tipo, required this.punto});

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String?,
        nombre: json['nombre'] as String,
        tipo: json['tipo'] as String,
        punto: LatLng((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
      );

  IconData get icono => iconoDeTipo(tipo);

  @override
  List<Object?> get props => [id, nombre, tipo, punto];
}

IconData iconoDeTipo(String tipo) => switch (tipo) {
      'Estación Transcaribe' => Icons.directions_bus,
      'Barrio' => Icons.home_work_outlined,
      'Sitio turístico' => Icons.castle_outlined,
      'Sitio histórico' || 'Entidad pública' => Icons.account_balance_outlined,
      'Universidad' || 'Institución educativa' => Icons.school_outlined,
      'Hospital' => Icons.local_hospital_outlined,
      'Centro comercial' => Icons.storefront_outlined,
      'Terminal / estación' => Icons.directions_bus_filled_outlined,
      'Aeropuerto' => Icons.flight,
      'Parque' => Icons.park_outlined,
      'Estadio' => Icons.stadium_outlined,
      'Museo' => Icons.museum_outlined,
      'Mercado' => Icons.shopping_basket_outlined,
      'Biblioteca' => Icons.local_library_outlined,
      'Mirador' => Icons.visibility_outlined,
      'Plaza' => Icons.location_city_outlined,
      _ => Icons.place_outlined,
    };

/// Íconos permitidos para un lugar guardado (coinciden con la API).
enum SavedPlaceIcon {
  casa('casa', 'Casa', Icons.home_outlined),
  trabajo('trabajo', 'Trabajo', Icons.work_outline),
  estudio('estudio', 'Estudio', Icons.school_outlined),
  favorito('favorito', 'Favorito', Icons.star_outline);

  final String api;
  final String etiqueta;
  final IconData icono;

  const SavedPlaceIcon(this.api, this.etiqueta, this.icono);

  static SavedPlaceIcon fromApi(String valor) =>
      values.firstWhere((i) => i.api == valor, orElse: () => SavedPlaceIcon.favorito);
}

/// Lugar frecuente del viajero ("Casa", "Trabajo").
class SavedPlace extends Equatable {
  final String id;
  final String nombre;
  final SavedPlaceIcon icono;
  final LatLng punto;

  const SavedPlace({required this.id, required this.nombre, required this.icono, required this.punto});

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        icono: SavedPlaceIcon.fromApi(json['icono'] as String),
        punto: LatLng((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
      );

  @override
  List<Object?> get props => [id, nombre, icono, punto];
}

/// Origen o destino elegido por el viajero.
class TripPoint extends Equatable {
  final String nombre;
  final LatLng punto;
  final bool esMiUbicacion;

  const TripPoint({required this.nombre, required this.punto, this.esMiUbicacion = false});

  factory TripPoint.miUbicacion(LatLng punto) => TripPoint(nombre: 'Tu ubicación', punto: punto, esMiUbicacion: true);

  factory TripPoint.deLugar(Place lugar) => TripPoint(nombre: lugar.nombre, punto: lugar.punto);

  factory TripPoint.deGuardado(SavedPlace lugar) => TripPoint(nombre: lugar.nombre, punto: lugar.punto);

  @override
  List<Object?> get props => [nombre, punto, esMiUbicacion];
}
