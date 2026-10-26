import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Lugar de Cartagena que devuelve el buscador o "elegir en el mapa".
class Place extends Equatable {
  final String? id;
  final String nombre;
  final String tipo;
  final LatLng punto;

  /// Para distinguir resultados con el mismo nombre: «Dirección aproximada · Bocagrande».
  final String? detalle;

  const Place({this.id, required this.nombre, required this.tipo, required this.punto, this.detalle});

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String?,
        nombre: json['nombre'] as String,
        tipo: json['tipo'] as String,
        punto: LatLng((json['latitud'] as num).toDouble(), (json['longitud'] as num).toDouble()),
        detalle: json['detalle'] as String?,
      );

  IconData get icono => iconoDeTipo(tipo);

  /// Lo que se muestra bajo el nombre.
  String get subtitulo => detalle ?? tipo;

  @override
  List<Object?> get props => [id, nombre, tipo, punto, detalle];
}

IconData iconoDeTipo(String tipo) => switch (tipo) {
      'Estación Transcaribe' => Icons.directions_bus,
      'Dirección' => Icons.signpost_outlined,
      'Barrio' => Icons.home_work_outlined,
      'Corregimiento' || 'Caserío' || 'Sector' => Icons.holiday_village_outlined,
      'Isla' => Icons.beach_access_outlined,
      'Hotel' => Icons.hotel_outlined,
      'Iglesia' => Icons.church_outlined,
      'Colegio' => Icons.school_outlined,
      'Clínica' => Icons.local_hospital_outlined,
      'Supermercado' => Icons.shopping_cart_outlined,
      'Zona comercial' => Icons.storefront_outlined,
      'Estación de servicio' => Icons.local_gas_station_outlined,
      'Policía' => Icons.local_police_outlined,
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

const _sinTildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};

/// Minúsculas y sin tildes, letra por letra: conserva las posiciones del texto original.
String normalizarParaBuscar(String texto) =>
    texto.toLowerCase().split('').map((c) => _sinTildes[c] ?? c).join();

/// Parte [nombre] en tramos y marca los que coinciden con el comienzo de una palabra de [consulta],
/// sin importar tildes ni mayúsculas, como busca el backend: «boca» resalta «Boca» en «Bocagrande».
List<(String, bool)> tramosResaltados(String nombre, String consulta) {
  final normal = normalizarParaBuscar(nombre);
  final marcadas = List<bool>.filled(nombre.length, false);
  for (final palabra in normalizarParaBuscar(consulta).split(RegExp(r'\s+')).where((p) => p.length >= 2)) {
    var desde = 0;
    while (true) {
      final i = normal.indexOf(palabra, desde);
      if (i < 0) break;
      final inicioDePalabra = i == 0 || !RegExp(r'[a-z0-9]').hasMatch(normal[i - 1]);
      if (inicioDePalabra) {
        for (var k = i; k < i + palabra.length; k++) {
          marcadas[k] = true;
        }
        break;
      }
      desde = i + 1;
    }
  }
  final tramos = <(String, bool)>[];
  var inicio = 0;
  for (var k = 1; k <= nombre.length; k++) {
    if (k == nombre.length || marcadas[k] != marcadas[inicio]) {
      tramos.add((nombre.substring(inicio, k), marcadas[inicio]));
      inicio = k;
    }
  }
  return tramos;
}
