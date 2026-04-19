import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

abstract class RouteEvent extends Equatable {
  const RouteEvent();

  @override
  List<Object> get props => [];
}

class EvaluateTacticalJumpEvent extends RouteEvent {
  final double distanceKm;

  const EvaluateTacticalJumpEvent({required this.distanceKm});

  @override
  List<Object> get props => [distanceKm];
}

class EvaluateRouteRiskEvent extends RouteEvent {
  final List<LatLng> routePoints;

  const EvaluateRouteRiskEvent({required this.routePoints});

  @override
  List<Object> get props => [routePoints];
}

class ResetRouteEvent extends RouteEvent {
  @override
  List<Object> get props => [];
}

class TraceRealRouteEvent extends RouteEvent {
  final LatLng start;
  final LatLng end;

  const TraceRealRouteEvent({required this.start, required this.end});

  @override
  List<Object> get props => [start, end];
}