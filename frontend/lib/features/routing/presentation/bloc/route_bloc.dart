import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:latlong2/latlong.dart';
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

    on<TraceRealRouteEvent>((event, emit) async {
      emit(RouteLoading());
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('El radar GPS está apagado. Enciende la ubicación.');
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Permisos de GPS denegados por el usuario.');
          }
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Permisos de GPS bloqueados permanentemente.');
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        
        final LatLng start = LatLng(position.latitude, position.longitude);

        final routePoints = await routeRepository.getRealRoute(start, event.end);
        emit(RouteTraced(routePoints: routePoints));
      } catch (e) {
        emit(RouteError(message: e.toString()));
      }
    });

    on<EvaluateRouteRiskEvent>((event, emit) async {
      emit(RouteLoading());
      try {
        final risk = await incidentRepository.evaluateRoute(event.routePoints);
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