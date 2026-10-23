import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/place_models.dart';
import '../cubit/saved_places_cubit.dart';
import '../widgets/saved_place_editor.dart';
import 'place_search_screen.dart';

/// Agrega un lugar guardado: buscarlo (o elegirlo en el mapa) y luego nombrarlo.
Future<void> addSavedPlaceFlow(BuildContext context, {SavedPlaceIcon icono = SavedPlaceIcon.favorito}) async {
  final cubit = context.read<SavedPlacesCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final punto = await PlaceSearchScreen.open(context, hint: 'Busca el lugar que quieres guardar');
  if (punto == null || !context.mounted) return;

  final borrador = await showSavedPlaceEditor(
    context,
    titulo: 'Guardar lugar',
    nombreInicial: icono == SavedPlaceIcon.favorito ? punto.nombre : icono.etiqueta,
    iconoInicial: icono,
  );
  if (borrador == null) return;
  final error = await cubit.add(nombre: borrador.nombre, icono: borrador.icono, punto: punto.punto);
  messenger.showSnackBar(SnackBar(content: Text(error ?? 'Guardaste «${borrador.nombre}».')));
}

class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

  Future<void> _editar(BuildContext context, SavedPlace lugar) async {
    final cubit = context.read<SavedPlacesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final borrador = await showSavedPlaceEditor(
      context,
      titulo: 'Editar lugar',
      nombreInicial: lugar.nombre,
      iconoInicial: lugar.icono,
    );
    if (borrador == null) return;
    final error = await cubit.update(lugar, nombre: borrador.nombre, icono: borrador.icono);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _eliminar(BuildContext context, SavedPlace lugar) async {
    final cubit = context.read<SavedPlacesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await cubit.delete(lugar);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Eliminaste «${lugar.nombre}».'),
      action: error != null
          ? null
          : SnackBarAction(
              label: 'Deshacer',
              onPressed: () => cubit.add(nombre: lugar.nombre, icono: lugar.icono, punto: lugar.punto),
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lugares guardados')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addSavedPlaceFlow(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Agregar lugar'),
      ),
      body: BlocBuilder<SavedPlacesCubit, SavedPlacesState>(
        builder: (context, state) {
          if (state.status == SavedPlacesStatus.cargando && state.lugares.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == SavedPlacesStatus.error && state.lugares.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No pudimos cargar tus lugares', style: texto.titleMedium),
                  const SizedBox(height: 8),
                  Text(state.mensaje ?? '', style: texto.bodyMedium),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => context.read<SavedPlacesCubit>().load(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state.lugares.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Todavía no guardas lugares', style: texto.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Guarda tu casa, tu trabajo o la universidad para ver cómo llegar con un solo toque.',
                    style: texto.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: state.lugares.length + 1,
            separatorBuilder: (_, _) => const Divider(indent: 72),
            itemBuilder: (context, i) {
              if (i == state.lugares.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Puedes guardar hasta 10 lugares.',
                      style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                );
              }
              final lugar = state.lugares[i];
              return ListTile(
                minVerticalPadding: 12,
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Icon(lugar.icono.icono),
                ),
                title: Text(lugar.nombre, style: texto.titleMedium),
                subtitle: Text(lugar.icono.etiqueta),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opciones de ${lugar.nombre}',
                  onSelected: (opcion) => opcion == 'editar' ? _editar(context, lugar) : _eliminar(context, lugar),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
                onTap: () => _editar(context, lugar),
              );
            },
          );
        },
      ),
    );
  }
}
