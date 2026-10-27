import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import 'features/legal/data/politica_repository.dart';
import 'features/legal/presentation/aviso_de_privacidad.dart';
import 'features/mapeo/data/mapeo_repository.dart';
import 'features/trip/data/trip_repository.dart';

void main() {
  // La letra va empaquetada: su licencia (OFL) aparece junto a las de los paquetes en «Acerca de Karta».
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Manrope'], await rootBundle.loadString('assets/fonts/OFL-Manrope.txt'));
  });
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
        RepositoryProvider(create: (context) => MapeoRepository(api: context.read<ApiClient>())),
        RepositoryProvider(create: (context) => PoliticaRepository(api: context.read<ApiClient>())),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AparienciaCubit()..cargar()),
          BlocProvider(create: (_) => ModoLigeroCubit()..cargar()),
          // La sesión arranca en la puerta, después del aviso de privacidad: antes no se crea la cuenta.
          BlocProvider(create: (context) => AuthBloc(repository: context.read<AuthRepository>())),
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
          builder: (context, apariencia) => BlocBuilder<ModoLigeroCubit, bool>(
            builder: (context, ligero) => MaterialApp(
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
              // Con el modo ligero, la app se porta como si el sistema pidiera quitar las animaciones.
              builder: (context, child) => ModoLigero(
                activo: ligero,
                child: ligero
                    ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!)
                    : child!,
              ),
              home: const _AuthGate(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Siempre el inicio: sin registrarse se entra con la cuenta invisible. Solo si la primera vez no hay conexión
/// (aún no hay cuenta invisible) se pide reintentar.
///
/// Antes de todo va el aviso de privacidad (Ley 1581): la primera vez, la cuenta se crea solo después de aceptarlo.
/// Si la cuenta no tiene aceptada la versión vigente, se guarda la que se aceptó en el teléfono o, si la política
/// cambió, se vuelve a mostrar el aviso.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  /// null mientras se revisa el teléfono; true si hay que mostrar el aviso.
  bool? _aviso;
  bool _porCambio = false;

  PoliticaRepository get _politica => context.read<PoliticaRepository>();

  @override
  void initState() {
    super.initState();
    _politica.aceptadaEnEsteTelefono().then((version) {
      if (!mounted) return;
      setState(() => _aviso = version == null);
      if (version != null) context.read<AuthBloc>().add(AuthStarted());
    });
  }

  Future<void> _aceptar(String version) async {
    await _politica.aceptarEnEsteTelefono(version);
    if (!mounted) return;
    final auth = context.read<AuthBloc>();
    setState(() => _aviso = false);
    if (auth.state is AuthAuthenticated) {
      await _registrar(version);
    } else {
      auth.add(AuthStarted()); // la autorización se registra cuando la cuenta exista (abajo)
    }
  }

  Future<void> _registrar(String version) async {
    try {
      await _politica.registrar(version);
      if (mounted) context.read<AuthBloc>().add(ProfileRefreshRequested());
    } catch (_) {
      // Sin señal: se vuelve a intentar la próxima vez que se abra la app.
    }
  }

  /// La cuenta no tiene aceptada la versión vigente: si este teléfono ya la aceptó, se guarda la prueba; si no, la
  /// política cambió y se muestra el aviso otra vez.
  Future<void> _revisarAutorizacion(AuthAuthenticated state) async {
    final vigente = state.usuario.politicaVigente!;
    if (await _politica.aceptadaEnEsteTelefono() == vigente) {
      await _registrar(vigente);
    } else if (mounted) {
      setState(() {
        _aviso = true;
        _porCambio = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_aviso == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: 'Abriendo Karta')));
    }
    if (_aviso!) return AvisoDePrivacidad(onAceptar: _aceptar, porCambio: _porCambio);
    return MultiBlocListener(
      listeners: [
        // Una sesión guardada por una versión anterior de la app no sabe qué política está vigente: se pide el perfil.
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (antes, actual) =>
              antes is! AuthAuthenticated && actual is AuthAuthenticated && actual.usuario.politicaVigente == null,
          listener: (context, _) => context.read<AuthBloc>().add(ProfileRefreshRequested()),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (antes, actual) =>
              actual is AuthAuthenticated &&
              actual.usuario.debeAceptarPolitica &&
              (antes is! AuthAuthenticated || antes.usuario != actual.usuario),
          listener: (context, state) => _revisarAutorizacion(state as AuthAuthenticated),
        ),
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
