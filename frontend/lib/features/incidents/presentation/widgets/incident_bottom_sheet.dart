import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
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
  bool _isFetchingLocation = false;

  Future<void> _submitWithLocation(BuildContext context) async {
    setState(() => _isFetchingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('El GPS está apagado. Enciéndelo para reportar.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Los permisos de GPS están bloqueados permanentemente.');
      }

      // PLAN DE CONTINGENCIA: Intentamos buscar el GPS con un límite de 5 segundos
      double finalLat;
      double finalLng;

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 5)); // ¡Si tarda más de 5s, salta al catch!
        
        finalLat = position.latitude;
        finalLng = position.longitude;
      } catch (e) {
        // Fallback temporal para Linux (Coordenada alternativa en Cartagena)
        finalLat = 10.4225; 
        finalLng = -75.5410;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS no detectado. Usando coordenadas de respaldo (Modo Dev).', style: TextStyle(color: Colors.black)), 
              backgroundColor: Colors.amberAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      if (!mounted) return;

      context.read<IncidentBloc>().add(
        SubmitIncidentEvent(
          categoria: _selectedCategory,
          intensidad: _intensity,
          latitud: finalLat,
          longitud: finalLng,
        )
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

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
              if (state is IncidentSubmitting || _isFetchingLocation) {
                return Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.amberAccent),
                    const SizedBox(height: 8),
                    Text(
                      _isFetchingLocation ? 'Buscando satélites GPS...' : 'Conectando con el Cerebro Digital...', 
                      style: const TextStyle(color: Colors.grey, fontSize: 12)
                    )
                  ],
                );
              }
              
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _submitWithLocation(context),
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