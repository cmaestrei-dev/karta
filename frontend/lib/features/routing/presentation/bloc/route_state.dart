import 'package:equatable/equatable.dart';
import '../../domain/models/route_models.dart';

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

class RouteError extends RouteState {
  final String message;

  const RouteError({required this.message});

  @override
  List<Object> get props => [message];
}