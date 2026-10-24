import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/incident_repository.dart';
import '../../domain/models/incident_models.dart';

/// Los reportes vigentes que dibuja el mapa. Reportar y validar viven en sus propios cubits.
abstract class IncidentState extends Equatable {
  @override
  List<Object> get props => [];
}

class IncidentInitial extends IncidentState {}

class IncidentsLoading extends IncidentState {}

class IncidentsLoaded extends IncidentState {
  final List<Incident> incidents;

  IncidentsLoaded(this.incidents);

  @override
  List<Object> get props => [incidents];
}

/// No se pudo actualizar la lista: el mapa conserva lo último que tenía y lo avisa.
class IncidentsLoadFailed extends IncidentState {
  final String message;

  IncidentsLoadFailed(this.message);

  @override
  List<Object> get props => [message];
}

abstract class IncidentEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadIncidentsEvent extends IncidentEvent {}

/// Un reporte salió del mapa (la comunidad lo desmintió): se quita sin esperar a la próxima recarga.
class IncidentRetired extends IncidentEvent {
  final String id;

  IncidentRetired(this.id);

  @override
  List<Object> get props => [id];
}

class IncidentBloc extends Bloc<IncidentEvent, IncidentState> {
  final IncidentRepository repository;

  IncidentBloc({required this.repository}) : super(IncidentInitial()) {
    on<LoadIncidentsEvent>((event, emit) async {
      emit(IncidentsLoading());
      try {
        emit(IncidentsLoaded(await repository.getActiveIncidents()));
      } catch (e) {
        emit(IncidentsLoadFailed(e.toString()));
      }
    });

    on<IncidentRetired>((event, emit) {
      final actual = state;
      if (actual is IncidentsLoaded) {
        emit(IncidentsLoaded([for (final i in actual.incidents) if (i.id != event.id) i]));
      }
    });
  }
}
