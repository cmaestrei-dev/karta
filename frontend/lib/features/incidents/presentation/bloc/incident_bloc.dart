import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/incident_repository.dart';
import '../../domain/models/incident_models.dart';

abstract class IncidentState extends Equatable {
  @override
  List<Object> get props => [];
}

class IncidentInitial extends IncidentState {}

class IncidentSubmitting extends IncidentState {}
class IncidentSuccess extends IncidentState {}

class IncidentsLoading extends IncidentState {}
class IncidentsLoaded extends IncidentState {
  final List<Incident> incidents;
  
  IncidentsLoaded(this.incidents);
  
  @override
  List<Object> get props => [incidents];
}

class IncidentError extends IncidentState {
  final String message;
  
  IncidentError(this.message);
  
  @override
  List<Object> get props => [message];
}

abstract class IncidentEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class SubmitIncidentEvent extends IncidentEvent {
  final String categoria;
  final int intensidad;
  final double latitud;
  final double longitud;

  SubmitIncidentEvent({
    required this.categoria, 
    required this.intensidad,
    required this.latitud,
    required this.longitud,
  });
  
  @override
  List<Object> get props => [categoria, intensidad, latitud, longitud];
}

class LoadIncidentsEvent extends IncidentEvent {}

class IncidentBloc extends Bloc<IncidentEvent, IncidentState> {
  final IncidentRepository repository;

  IncidentBloc({required this.repository}) : super(IncidentInitial()) {
    
    on<SubmitIncidentEvent>((event, emit) async {
      emit(IncidentSubmitting());
      try {
        final newIncident = IncidentCreate(
          idUsuario: 1,
          categoria: event.categoria,
          intensidad: event.intensidad,
          latitud: event.latitud,
          longitud: event.longitud,
        );
        await repository.reportIncident(newIncident);
        emit(IncidentSuccess());
        
        add(LoadIncidentsEvent()); 
        
      } catch (e) {
        emit(IncidentError(e.toString()));
      }
    });

    on<LoadIncidentsEvent>((event, emit) async {
      emit(IncidentsLoading());
      try {
        final incidents = await repository.getActiveIncidents();
        emit(IncidentsLoaded(incidents));
      } catch (e) {
        emit(IncidentError(e.toString()));
      }
    });
    
  }
}