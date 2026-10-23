import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../places/presentation/cubit/saved_places_cubit.dart';
import '../../../places/presentation/screens/saved_places_screen.dart';

/// Cuenta del viajero: lugares guardados y cerrar sesión (con confirmación).
void showProfileSheet(BuildContext context) {
  final auth = context.read<AuthBloc>();
  final usuario = auth.state is AuthAuthenticated ? (auth.state as AuthAuthenticated).usuario : null;

  showModalBottomSheet(
    context: context,
    builder: (hoja) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (usuario != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.nombre, style: Theme.of(hoja).textTheme.headlineSmall),
                    Text('${usuario.email} · ${usuario.tipoViajero}',
                        style: Theme.of(hoja).textTheme.bodyMedium?.copyWith(color: Theme.of(hoja).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: const Text('Lugares guardados'),
              onTap: () {
                Navigator.of(hoja).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedPlacesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                Navigator.of(hoja).pop();
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (dialogo) => AlertDialog(
                    title: const Text('¿Cerrar sesión?'),
                    content: const Text('Tendrás que volver a ingresar para reportar incidentes y ver tus lugares.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dialogo).pop(false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.of(dialogo).pop(true), child: const Text('Cerrar sesión')),
                    ],
                  ),
                );
                if (confirmar == true && context.mounted) {
                  context.read<SavedPlacesCubit>().clear();
                  auth.add(const LogoutRequested());
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
