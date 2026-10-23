import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/places_repository.dart';
import '../../domain/place_models.dart';

enum PlaceSearchStatus { vacio, buscando, resultados, sinResultados, error }

class PlaceSearchState extends Equatable {
  final PlaceSearchStatus status;
  final String consulta;
  final List<Place> resultados;
  final String? mensaje;

  const PlaceSearchState({
    this.status = PlaceSearchStatus.vacio,
    this.consulta = '',
    this.resultados = const [],
    this.mensaje,
  });

  @override
  List<Object?> get props => [status, consulta, resultados, mensaje];
}

/// Búsqueda mientras se escribe: espera una pausa al teclear y descarta respuestas viejas.
class PlaceSearchCubit extends Cubit<PlaceSearchState> {
  static const espera = Duration(milliseconds: 350);

  final PlacesRepository repository;
  Timer? _temporizador;
  int _ultimaPeticion = 0;

  PlaceSearchCubit({required this.repository}) : super(const PlaceSearchState());

  void onQueryChanged(String texto) {
    _temporizador?.cancel();
    final consulta = texto.trim();
    if (consulta.length < 2) {
      _ultimaPeticion++;
      emit(PlaceSearchState(consulta: consulta));
      return;
    }
    emit(PlaceSearchState(status: PlaceSearchStatus.buscando, consulta: consulta, resultados: state.resultados));
    _temporizador = Timer(espera, () => _buscar(consulta));
  }

  void retry() => _buscar(state.consulta);

  Future<void> _buscar(String consulta) async {
    final peticion = ++_ultimaPeticion;
    emit(PlaceSearchState(status: PlaceSearchStatus.buscando, consulta: consulta, resultados: state.resultados));
    try {
      final resultados = await repository.search(consulta);
      if (peticion != _ultimaPeticion || isClosed) return;
      emit(PlaceSearchState(
        status: resultados.isEmpty ? PlaceSearchStatus.sinResultados : PlaceSearchStatus.resultados,
        consulta: consulta,
        resultados: resultados,
      ));
    } catch (e) {
      if (peticion != _ultimaPeticion || isClosed) return;
      emit(PlaceSearchState(status: PlaceSearchStatus.error, consulta: consulta, mensaje: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _temporizador?.cancel();
    return super.close();
  }
}
