import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'mapeo_models.dart';

/// «El bus paró aquí», en ese paradero de la lista oficial.
class ParadaDelViaje extends Equatable {
  final String paradero;
  final LatLng punto;

  const ParadaDelViaje({required this.paradero, required this.punto});

  Map<String, dynamic> toJson() => {'paradero': paradero, 'latitud': punto.latitude, 'longitud': punto.longitude};

  @override
  List<Object?> get props => [paradero, punto];
}

/// Un viaje de mapeo: la lista oficial de un sentido, en orden, y el paradero que sigue. En cada parada del bus el
/// viajero dice «paró aquí» (o «no paró»); los que ya están en el mapa se pasan solos cuando el bus llega a ellos.
class ViajeDeMapeo extends Equatable {
  /// A esta distancia de un paradero ya ubicado, el bus llegó a él.
  static const llegoM = 40.0;

  final List<ParaderoDeRuta> paraderos;
  final int actual;
  final List<ParadaDelViaje> paradas;
  final List<int> anteriores; // para deshacer: dónde iba antes de cada paso

  const ViajeDeMapeo._(this.paraderos, this.actual, this.paradas, this.anteriores);

  /// Empieza en el paradero siguiente a donde se subió el viajero.
  factory ViajeDeMapeo.desde(List<ParaderoDeRuta> paraderos, int subio) =>
      ViajeDeMapeo._(paraderos, (subio + 1).clamp(0, paraderos.length), const [], const []);

  /// Dónde se subió, probablemente: el paradero ya ubicado más cercano (a menos de 300 m), o el primero.
  static int dondeSubio(List<ParaderoDeRuta> paraderos, LatLng? posicion) {
    if (posicion == null) return 0;
    const distancia = Distance();
    var mejor = 0;
    var metros = 300.0;
    for (final (k, p) in paraderos.indexed) {
      if (p.punto == null) continue;
      final d = distancia.as(LengthUnit.Meter, p.punto!, posicion);
      if (d < metros) (mejor, metros) = (k, d);
    }
    return mejor;
  }

  ParaderoDeRuta? get proximo => actual < paraderos.length ? paraderos[actual] : null;

  bool get termino => proximo == null;

  /// Los que faltan por ubicar de aquí al final.
  int get faltan => paraderos.skip(actual).where((p) => !p.estado.ubicado).length;

  ViajeDeMapeo _avanza({ParadaDelViaje? parada}) => ViajeDeMapeo._(
      paraderos, actual + 1, parada == null ? paradas : [...paradas, parada], [...anteriores, actual]);

  /// El bus paró en el próximo paradero: si no está en el mapa, se anota dónde.
  ViajeDeMapeo paroAqui(LatLng punto) {
    final p = proximo;
    if (p == null) return this;
    return _avanza(parada: p.estado.ubicado ? null : ParadaDelViaje(paradero: p.id, punto: punto));
  }

  /// No paró ahí, o el viajero no lo vio: se pasa al siguiente sin anotar nada.
  ViajeDeMapeo noParo() => termino ? this : _avanza();

  /// Si el próximo ya está en el mapa y el bus llegó a él, se pasa solo: así la lista sigue al bus.
  ViajeDeMapeo pasoPor(LatLng posicion) {
    final p = proximo;
    if (p == null || p.punto == null || !p.estado.ubicado) return this;
    return const Distance().as(LengthUnit.Meter, p.punto!, posicion) <= llegoM ? _avanza() : this;
  }

  ViajeDeMapeo deshacer() {
    if (anteriores.isEmpty) return this;
    final volver = anteriores.last;
    final quitar = paradas.isNotEmpty && paradas.last.paradero == paraderos[volver].id;
    return ViajeDeMapeo._(paraderos, volver, quitar ? paradas.sublist(0, paradas.length - 1) : paradas,
        anteriores.sublist(0, anteriores.length - 1));
  }

  @override
  List<Object?> get props => [paraderos, actual, paradas, anteriores];
}

/// El bus está detenido si en los últimos [segundos] se movió menos de [metros].
bool estaDetenido(List<(DateTime, LatLng)> recientes, DateTime ahora, {int segundos = 6, double metros = 10}) {
  final desde = ahora.subtract(Duration(seconds: segundos));
  final ventana = [for (final (t, p) in recientes) if (!t.isBefore(desde)) p];
  if (ventana.length < 2 || recientes.first.$1.isAfter(desde)) return false;
  const distancia = Distance();
  return ventana.every((p) => distancia.as(LengthUnit.Meter, p, ventana.first) < metros);
}

/// Lo que respondió el servidor al terminar el viaje.
class ResultadoDelViaje extends Equatable {
  final int marcados;
  final int confirmados;
  final int contradichos;

  const ResultadoDelViaje({required this.marcados, required this.confirmados, required this.contradichos});

  factory ResultadoDelViaje.fromJson(Map<String, dynamic> json) => ResultadoDelViaje(
        marcados: json['marcados'] as int,
        confirmados: json['confirmados'] as int,
        contradichos: json['contradichos'] as int,
      );

  @override
  List<Object?> get props => [marcados, confirmados, contradichos];
}
