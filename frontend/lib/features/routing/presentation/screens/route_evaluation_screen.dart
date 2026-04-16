import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      appBar: AppBar(        
        title: const Text('Ruta Estratégica', style: TextStyle(fontWeight: FontWeight.w300)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_rounded, color: Colors.amberAccent),
            onPressed: () => IncidentBottomSheet.show(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simular Trayecto',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Terminal de Transportes -> Bocagrande (8.5 km)',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                context.read<RouteBloc>().add(const EvaluateTacticalJumpEvent(distanceKm: 8.5));
              },
              child: const Text('Analizar Eficiencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 48),

            Expanded(
              child: BlocBuilder<RouteBloc, RouteState>(
                builder: (context, state) {
                  if (state is RouteInitial) {
                    return const Center(
                      child: Text('Esperando datos del trayecto...', style: TextStyle(color: Colors.grey)),
                    );
                  } else if (state is RouteLoading) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  } else if (state is RouteLoaded) {
                    return _buildDecisionCard(state.decision);
                  } else if (state is RouteError) {
                    return Center(
                      child: Text('Error: ${state.message}', style: const TextStyle(color: Colors.redAccent)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionCard(DecisionResponse decision) {
    if (!decision.sugiereSalto) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(12)
        ),
        child: const Text(
          'Transcaribe es la opción más eficiente para este trayecto.', 
          style: TextStyle(color: Colors.green)
        ),
      );
    }

    final costoExtra = decision.opcionAlternativa.costoCop - decision.opcionActual.costoCop;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
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
            'Optimizando: Ahorrarás ${decision.tiempoAhorrado} min por \$${costoExtra} COP adicionales.',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {

              },
              child: Text(
                'Abriendo ${decision.opcionAlternativa.modalidad}...', 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
            ),
          )
        ],
      ),
    );
  }
}