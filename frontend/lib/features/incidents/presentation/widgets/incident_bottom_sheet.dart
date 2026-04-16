import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/incident_bloc.dart';

class IncidentBottomSheet extends StatefulWidget {
  const IncidentBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const IncidentBottomSheet(),
    );
  }

  @override
  State<IncidentBottomSheet> createState() => _IncidentBottomSheetState();
}

class _IncidentBottomSheetState extends State<IncidentBottomSheet> {
  String _selectedCategory = 'Tráfico';
  int _intensity = 3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Reportar Incidente', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          
          Row(
            children: [
              _buildCategoryChip('Tráfico', Icons.directions_car),
              const SizedBox(width: 12),
              _buildCategoryChip('Seguridad', Icons.warning_amber_rounded),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Intensidad (1 a 5)', style: TextStyle(color: Colors.grey)),
          Slider(
            value: _intensity.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: Colors.amberAccent,
            label: _intensity.toString(),
            onChanged: (val) => setState(() => _intensity = val.toInt()),
          ),
          const SizedBox(height: 24),


          BlocConsumer<IncidentBloc, IncidentState>(
            listener: (context, state) {
              if (state is IncidentSuccess) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alerta enviada. Gracias por cuidar a la comunidad.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
                );
              } else if (state is IncidentError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message), backgroundColor: Colors.red),
                );
              }
            },
            builder: (context, state) {
              if (state is IncidentSubmitting) {
                return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
              }
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  context.read<IncidentBloc>().add(
                    SubmitIncidentEvent(categoria: _selectedCategory, intensidad: _intensity)
                  );
                },
                child: const Text('Difundir Alerta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    final isSelected = _selectedCategory == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.amberAccent.withOpacity(0.2) : Colors.transparent,
            border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.amberAccent : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.amberAccent : Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}