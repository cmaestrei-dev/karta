import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_client.dart';
import 'core/design/apariencia.dart';
import 'core/design/tema.dart';

import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

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
        RepositoryProvider(create: (context) {
          final auth = context.read<AuthRepository>();
          return ApiClient(token: () => auth.token, renovarSesion: auth.renovarSiEsInvisible);
        }),
        RepositoryProvider(create: (context) => IncidentRepository(api: context.read<ApiClient>())),
        RepositoryProvider(create: (context) => PlacesRepository(api: context.read<ApiClient>())),
        RepositoryProvider(create: (context) => TripRepository(api: context.read<ApiClient>())),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AparienciaCubit()..cargar()),
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
                  .add(const LogoutRequested(message: 'Tu sesión expiró. Entra de nuevo con tu correo desde tu perfil.')),
            ),
          ),
        ],
        child: BlocBuilder<AparienciaCubit, ThemeMode>(
          builder: (context, apariencia) => MaterialApp(
            title: 'Karta',
            debugShowCheckedModeBanner: false,
            theme: TemaBahia.claro,
            darkTheme: TemaBahia.oscuro,
            themeMode: apariencia,
            // Español de Colombia también en lo que dibuja Flutter: «Cerrar» en vez de «Dismiss» para el lector
            // de pantalla, los nombres de los botones de atrás y los formatos de fecha.
            locale: const Locale('es', 'CO'),
            supportedLocales: const [Locale('es', 'CO'), Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const _AuthGate(),
          ),
        ),
      ),
    );
  }
}

/// Siempre el inicio: sin registrarse se entra con la cuenta invisible. Solo si la primera vez no hay conexión
/// (aún no hay cuenta invisible) se pide reintentar.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Los lugares guardados son de la cuenta: se cargan al entrar y cada vez que cambia.
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (antes, actual) =>
              actual is AuthAuthenticated && (antes is! AuthAuthenticated || antes.usuario.id != actual.usuario.id),
          listener: (context, _) => context.read<SavedPlacesCubit>().load(),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (_, actual) => actual is AuthAuthenticated && actual.aviso != null,
          listener: (context, state) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text((state as AuthAuthenticated).aviso!))),
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) => switch (state) {
          AuthAuthenticated() => const HomeScreen(),
          AuthUnauthenticated(:final message) => _SinConexion(mensaje: message ?? AuthBloc.sinConexion),
          _ => const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: 'Abriendo Karta'))),
        },
      ),
    );
  }
}

class _SinConexion extends StatelessWidget {
  final String mensaje;

  const _SinConexion({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                Text(mensaje, textAlign: TextAlign.center, style: texto.bodyLarge),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.read<AuthBloc>().add(AuthStarted()),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
