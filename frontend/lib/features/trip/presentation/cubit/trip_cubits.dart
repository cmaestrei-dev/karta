import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../places/domain/place_models.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_models.dart';

sealed class TripPlanState extends Equatable {
  const TripPlanState();

  @override
  List<Object?> get props => [];
}

class TripPlanLoading extends TripPlanState {
  const TripPlanLoading();
}

class TripPlanLoaded extends TripPlanState {
  final RouteSuggestions sugerencias;

  const TripPlanLoaded(this.sugerencias);

  @override
  List<Object?> get props => [sugerencias];
}

class TripPlanFailed extends TripPlanState {
  final String mensaje;

  const TripPlanFailed(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}

/// Rutas sugeridas entre dos puntos, según el criterio y la hora de salida elegidos.
class TripPlanCubit extends Cubit<TripPlanState> {
  final TripRepository repository;
  int _ultimaPeticion = 0;

  TripPlanCubit({required this.repository}) : super(const TripPlanLoading());

  Future<void> plan(TripPoint origen, TripPoint destino,
      {CriterioDeRuta criterio = CriterioDeRuta.rapida, DateTime? salida, int? caminataMaximaM}) async {
    final peticion = ++_ultimaPeticion;
    emit(const TripPlanLoading());
    try {
      final sugerencias = await repository.suggest(origen, destino,
          criterio: criterio, salida: salida, caminataMaximaM: caminataMaximaM);
      if (peticion == _ultimaPeticion && !isClosed) emit(TripPlanLoaded(sugerencias));
    } catch (e) {
      if (peticion == _ultimaPeticion && !isClosed) emit(TripPlanFailed(e.toString()));
    }
  }
}

sealed class NearbyStopsState extends Equatable {
  const NearbyStopsState();

  @override
  List<Object?> get props => [];
}

class NearbyStopsLoading extends NearbyStopsState {
  const NearbyStopsLoading();
}

class NearbyStopsLoaded extends NearbyStopsState {
  final List<Stop> estaciones;

  /// Las rutas que pasan cerca, fuera de las estaciones (D16). Vacía si no hay o si no se pudieron consultar.
  final List<RutaCercana> rutas;

  const NearbyStopsLoaded(this.estaciones, {this.rutas = const []});

  @override
  List<Object?> get props => [estaciones, rutas];
}

class NearbyStopsFailed extends NearbyStopsState {
  final String mensaje;

  const NearbyStopsFailed(this.mensaje);

  @override
  List<Object?> get props => [mensaje];
}

/// Estaciones de Transcaribe cerca de un punto.
class NearbyStopsCubit extends Cubit<NearbyStopsState> {
  final TripRepository repository;
  LatLng? _ultimoPunto;

  NearbyStopsCubit({required this.repository}) : super(const NearbyStopsLoading());

  Future<void> load(LatLng punto) async {
    _ultimoPunto = punto;
    emit(const NearbyStopsLoading());
    try {
      // Las rutas son un extra: si fallan, igual se muestran las estaciones.
      final (estaciones, rutas) = await (
        repository.nearbyStops(punto),
        repository.nearbyRoutes(punto).catchError((Object _) => const <RutaCercana>[]),
      ).wait;
      if (!isClosed) emit(NearbyStopsLoaded(estaciones, rutas: rutas));
    } catch (e) {
      if (!isClosed) emit(NearbyStopsFailed(e.toString()));
    }
  }

  void showError(String mensaje) => emit(NearbyStopsFailed(mensaje));

  Future<void> retry() async {
    if (_ultimoPunto != null) await load(_ultimoPunto!);
  }
}
