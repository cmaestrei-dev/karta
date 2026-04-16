import 'package:equatable/equatable.dart';

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