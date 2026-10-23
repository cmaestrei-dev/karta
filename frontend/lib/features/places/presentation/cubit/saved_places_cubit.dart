import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/api_errors.dart';
import '../../data/places_repository.dart';
import '../../domain/place_models.dart';

enum SavedPlacesStatus { inicial, cargando, listo, error }

class SavedPlacesState extends Equatable {
  final SavedPlacesStatus status;
  final List<SavedPlace> lugares;
  final String? mensaje;

  const SavedPlacesState({this.status = SavedPlacesStatus.inicial, this.lugares = const [], this.mensaje});

  SavedPlacesState copyWith({SavedPlacesStatus? status, List<SavedPlace>? lugares, String? mensaje}) =>
      SavedPlacesState(status: status ?? this.status, lugares: lugares ?? this.lugares, mensaje: mensaje);

  @override
  List<Object?> get props => [status, lugares, mensaje];
}

/// Lugares guardados del viajero (CRUD contra /users/me/places).
/// Las operaciones devuelven null si salieron bien o el mensaje de error para mostrar.
class SavedPlacesCubit extends Cubit<SavedPlacesState> {
  final PlacesRepository repository;

  /// Se llama cuando la API responde 401: la sesión ya no es válida.
  final void Function() onSessionExpired;

  SavedPlacesCubit({required this.repository, required this.onSessionExpired}) : super(const SavedPlacesState());

  Future<void> load() async {
    emit(state.copyWith(status: SavedPlacesStatus.cargando));
    try {
      emit(state.copyWith(status: SavedPlacesStatus.listo, lugares: await repository.listSaved()));
    } on SessionExpiredException {
      onSessionExpired();
    } catch (e) {
      emit(state.copyWith(status: SavedPlacesStatus.error, mensaje: e.toString()));
    }
  }

  Future<String?> add({required String nombre, required SavedPlaceIcon icono, required LatLng punto}) =>
      _intentar(() async {
        final nuevo = await repository.addSaved(nombre: nombre, icono: icono, punto: punto);
        emit(state.copyWith(status: SavedPlacesStatus.listo, lugares: [...state.lugares, nuevo]));
      });

  Future<String?> update(SavedPlace lugar, {String? nombre, SavedPlaceIcon? icono}) => _intentar(() async {
        final actualizado = await repository.updateSaved(lugar.id, nombre: nombre, icono: icono);
        emit(state.copyWith(lugares: [for (final l in state.lugares) l.id == lugar.id ? actualizado : l]));
      });

  Future<String?> delete(SavedPlace lugar) => _intentar(() async {
        await repository.deleteSaved(lugar.id);
        emit(state.copyWith(lugares: state.lugares.where((l) => l.id != lugar.id).toList()));
      });

  Future<String?> _intentar(Future<void> Function() operacion) async {
    try {
      await operacion();
      return null;
    } on SessionExpiredException catch (e) {
      onSessionExpired();
      return e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  void clear() => emit(const SavedPlacesState());
}
