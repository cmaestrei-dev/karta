import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';
import '../bloc/route_state.dart';
import '../../domain/models/route_models.dart';
import '../../../incidents/presentation/widgets/incident_bottom_sheet.dart';

class RouteEvaluationScreen extends StatelessWidget {
  const RouteEvaluationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(10.4233, -75.5496),
              initialZoom: 13.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.karta.app',
              ),
            ],
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AppBar(
                title: const Text('Karta', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.warning_rounded, color: Colors.amberAccent),
                      onPressed: () => IncidentBottomSheet.show(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: BlocBuilder<RouteBloc, RouteState>(
              builder: (context, state) {
                if (state is RouteInitial) {
                  return _buildInitialCard(context);
                } else if (state is RouteLoading) {
                  return _buildLoadingCard();
                } else if (state is RouteLoaded) {
                  return _buildDecisionCard(state.decision);
                } else if (state is RouteError) {
                  return _buildErrorCard(state.message);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInitialCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Destino Frecuente', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Bocagrande', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Desde Terminal de Transportes (8.5 km)', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                context.read<RouteBloc>().add(const EvaluateTacticalJumpEvent(distanceKm: 8.5));
              },
              child: const Text('Simular Ruta y Tráfico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('Error: $message', style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildDecisionCard(DecisionResponse decision) {
    if (!decision.sugiereSalto) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9), 
          borderRadius: BorderRadius.circular(20)
        ),
        child: const Text(
          'Transcaribe es la opción más eficiente en este momento. Ruta despejada.', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
        ),
      );
    }

    final costoExtra = decision.opcionAlternativa.costoCop - decision.opcionActual.costoCop;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.amberAccent.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Salto Táctico Sugerido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tráfico detectado. Ahorrarás ${decision.tiempoAhorrado} min por \$${costoExtra} COP adicionales.',
            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {},
              child: Text(
                'Pedir ${decision.opcionAlternativa.modalidad}', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
          )
        ],
      ),
    );
  }
}