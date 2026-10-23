import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/location_service.dart';
import 'route_event.dart';
import 'route_state.dart';
import '../../data/repositories/route_repository.dart';

class RouteBloc extends Bloc<RouteEvent, RouteState> {
  final RouteRepository routeRepository;

  RouteBloc({required this.routeRepository}) : super(RouteInitial()) {

    on<TraceRealRouteEvent>((event, emit) async {
      emit(RouteLoading());
      try {
        final location = await LocationService.getCurrentLocation();
        final routePoints = await routeRepository.getRealRoute(location.point, event.end);
        emit(RouteTraced(routePoints: routePoints));
      } catch (e) {
        emit(RouteError(message: e.toString()));
      }
    });

    on<EvaluateRouteRiskEvent>((event, emit) async {
      emit(RouteLoading());
      try {
        final risk = await routeRepository.evaluateRisk(event.routePoints);
        emit(RouteRiskEvaluated(routeRisk: risk, routePoints: event.routePoints));
      } catch (e) {
        emit(RouteError(message: e.toString()));
      }
    });

    on<ResetRouteEvent>((event, emit) {
      emit(RouteInitial());
    });
  }
}
