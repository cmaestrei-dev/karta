import 'package:flutter_bloc/flutter_bloc.dart';
import 'route_event.dart';
import 'route_state.dart';
import '../../data/repositories/route_repository.dart';

class RouteBloc extends Bloc<RouteEvent, RouteState> {
  final RouteRepository routeRepository;

  RouteBloc({required this.routeRepository}) : super(RouteInitial()) {
    
    on<EvaluateTacticalJumpEvent>((event, emit) async {
      emit(RouteLoading());
      
      try {
        final decision = await routeRepository.evaluateRoute(event.distanceKm);
        
        emit(RouteLoaded(decision: decision));
      } catch (e) {
        emit(RouteError(message: e.toString()));
      }
    });
  }
}