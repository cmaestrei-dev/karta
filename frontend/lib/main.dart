import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/api_client.dart';
import 'core/theme/karta_theme.dart';

import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/login_screen.dart';

import 'features/home/presentation/screens/home_screen.dart';

import 'features/incidents/data/repositories/incident_repository.dart';
import 'features/incidents/presentation/bloc/incident_bloc.dart';

import 'features/places/data/places_repository.dart';
import 'features/places/presentation/cubit/saved_places_cubit.dart';

import 'features/trip/data/trip_repository.dart';

void main() {
  runApp(const KartaApp());
}

class KartaApp extends StatelessWidget {
  const KartaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => ApiClient(token: () => context.read<AuthRepository>().token)),
        RepositoryProvider(create: (context) => IncidentRepository(api: context.read<ApiClient>())),
        RepositoryProvider(create: (context) => PlacesRepository(api: context.read<ApiClient>())),
        RepositoryProvider(create: (context) => TripRepository(api: context.read<ApiClient>())),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(repository: context.read<AuthRepository>())
              ..add(AuthStarted())
          ),
          BlocProvider(
            create: (context) => IncidentBloc(repository: context.read<IncidentRepository>())
              ..add(LoadIncidentsEvent())
          ),
          BlocProvider(
            create: (context) => SavedPlacesCubit(
              repository: context.read<PlacesRepository>(),
              onSessionExpired: () => context
                  .read<AuthBloc>()
                  .add(const LogoutRequested(message: 'Tu sesión expiró. Inicia sesión de nuevo.')),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Karta',
          debugShowCheckedModeBanner: false,
          theme: KartaTheme.claro,
          darkTheme: KartaTheme.oscuro,
          themeMode: ThemeMode.system,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Muestra el inicio con sesión iniciada y el inicio de sesión en cualquier otro caso.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (_, actual) => actual is AuthAuthenticated,
      listener: (context, _) => context.read<SavedPlacesCubit>().load(),
      builder: (context, state) {
        if (state is AuthUnknown) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: 'Abriendo Karta')));
        }
        if (state is AuthAuthenticated) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
