import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/models/route_risk.dart';

abstract class RouteState extends Equatable {
  const RouteState();

  @override
  List<Object?> get props => [];
}

class RouteInitial extends RouteState {}

class RouteLoading extends RouteState {}

class RouteTraced extends RouteState {
  final List<LatLng> routePoints;

  const RouteTraced({required this.routePoints});

  @override
  List<Object> get props => [routePoints];
}

class RouteRiskEvaluated extends RouteState {
  final RouteRisk routeRisk;
  final List<LatLng> routePoints;

  const RouteRiskEvaluated({
    required this.routeRisk,
    required this.routePoints
  });

  @override
  List<Object> get props => [routeRisk, routePoints];
}

class RouteError extends RouteState {
  final String message;

  const RouteError({required this.message});

  @override
  List<Object> get props => [message];
}
