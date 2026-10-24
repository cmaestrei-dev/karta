import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/plaque.dart';
import '../../../places/domain/place_models.dart';
import '../../../places/presentation/cubit/saved_places_cubit.dart';
import '../../../places/presentation/screens/saved_places_screen.dart';

/// Fichas de los lugares guardados (Casa, Trabajo…) para salir hacia ellos con un toque, y la de guardar uno.
/// Mantener presionada una ficha abre la lista para editarlos.
class AccesosGuardados extends StatelessWidget {
  final void Function(TripPoint destino) onIr;

  const AccesosGuardados({super.key, required this.onIr});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedPlacesCubit, SavedPlacesState>(
      builder: (context, state) {
        final lugares = state.lugares;
        void editar() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedPlacesScreen()));
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final lugar in lugares)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MiniPlaque(
                    icon: lugar.icono.icono,
                    label: lugar.nombre,
                    onTap: () => onIr(TripPoint.deGuardado(lugar)),
                    onLongPress: editar,
                  ),
                ),
              if (lugares.isEmpty)
                MiniPlaque(
                  icon: Icons.home_outlined,
                  label: 'Guardar tu casa',
                  onTap: () => addSavedPlaceFlow(context, icono: SavedPlaceIcon.casa),
                )
              else
                MiniPlaque(
                  icon: Icons.add,
                  tooltip: 'Guardar un lugar',
                  onTap: () => addSavedPlaceFlow(context),
                ),
            ],
          ),
        );
      },
    );
  }
}
