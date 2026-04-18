import 'package:flutter_bloc/flutter_bloc.dart';
import 'route_event.dart';
import 'route_state.dart';
import '../../data/repositories/route_repository.dart';
import '../../../incidents/data/repositories/incident_repository.dart'; 

class RouteBloc extends Bloc<RouteEvent, RouteState> {
  final RouteRepository routeRepository;
  final IncidentRepository incidentRepository;

  RouteBloc({
    required this.routeRepository,
    required this.incidentRepository, 
  }) : super(RouteInitial()) {
    
    on<EvaluateTacticalJumpEvent>((event, emit) async {
      emit(RouteLoading());
      try {
        final decision = await routeRepository.evaluateRoute(event.distanceKm);
        emit(RouteLoaded(decision: decision));
      } catch (e) {
        emit(RouteError(message: e.toString()));
      }
    });

    on<EvaluateRouteRiskEvent>((event, emit) async {
      emit(RouteLoading());
      
      try {
        final risk = await incidentRepository.evaluateRoute(event.routePoints);
        emit(RouteRiskEvaluated(routeRisk: risk));
      } catch (e) {
        emit(RouteError(message: e.toString()));
      }
    });

    on<ResetRouteEvent>((event, emit) {
      emit(RouteInitial()); // Volvemos a la pantalla principal
    });
  }
}