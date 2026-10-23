import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/login_screen.dart';

import 'features/routing/data/repositories/route_repository.dart';
import 'features/routing/presentation/bloc/route_bloc.dart';
import 'features/routing/presentation/screens/route_evaluation_screen.dart';

import 'features/incidents/data/repositories/incident_repository.dart';
import 'features/incidents/presentation/bloc/incident_bloc.dart';

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
        RepositoryProvider(create: (context) => RouteRepository()),
        RepositoryProvider(
          create: (context) => IncidentRepository(authRepository: context.read<AuthRepository>()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(repository: context.read<AuthRepository>())
              ..add(AuthStarted())
          ),
          BlocProvider(
            create: (context) => RouteBloc(
              routeRepository: context.read<RouteRepository>(),
            )
          ),
          BlocProvider(
            create: (context) => IncidentBloc(repository: context.read<IncidentRepository>())
              ..add(LoadIncidentsEvent())
          ),
        ],
        child: MaterialApp(
          title: 'Karta',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: Colors.white,
            useMaterial3: true,
          ),
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Muestra el mapa con sesión iniciada y el inicio de sesión en cualquier otro caso.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthUnknown) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        if (state is AuthAuthenticated) {
          return const RouteEvaluationScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
