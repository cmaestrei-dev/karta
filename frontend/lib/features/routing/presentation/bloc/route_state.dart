import 'package:equatable/equatable.dart';
import '../../domain/models/route_models.dart';
import '../../domain/models/route_risk.dart';

abstract class RouteState extends Equatable {
  const RouteState();
  
  @override
  List<Object> get props => [];
}

class RouteInitial extends RouteState {}

class RouteLoading extends RouteState {}

class RouteLoaded extends RouteState {
  final DecisionResponse decision;

  const RouteLoaded({required this.decision});

  @override
  List<Object> get props => [decision];
}

class RouteRiskEvaluated extends RouteState {
  final RouteRisk routeRisk;

  const RouteRiskEvaluated({required this.routeRisk});

  @override
  List<Object> get props => [routeRisk];
}

class RouteError extends RouteState {
  final String message;

  const RouteError({required this.message});

  @override
  List<Object> get props => [message];
}