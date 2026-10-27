import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/usuario.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Verificando si hay una sesión guardada (al abrir la app).
class AuthUnknown extends AuthState {}

/// Hay sesión: la cuenta invisible del teléfono o una con correo. [aviso] se muestra una vez
/// («Tu sesión expiró…»).
class AuthAuthenticated extends AuthState {
  final Usuario usuario;
  final String? aviso;

  const AuthAuthenticated(this.usuario, {this.aviso});

  /// Terminó de entrar con correo o de registrarse (no está en curso ni falló).
  bool get conCuentaLista => runtimeType == AuthAuthenticated && !usuario.sinCuenta;

  @override
  List<Object?> get props => [usuario, aviso];
}

/// Entrando con correo o registrándose desde el perfil; mientras tanto sigue la sesión actual.
class AuthInProgress extends AuthAuthenticated {
  const AuthInProgress(super.usuario);
}

/// No se pudo entrar o registrarse; sigue la sesión actual.
class AuthFailure extends AuthAuthenticated {
  final String message;

  const AuthFailure(super.usuario, this.message);

  @override
  List<Object?> get props => [usuario, message];
}

/// Sin ninguna sesión: la primera vez que se abre Karta sin conexión (no hay cuenta invisible todavía).
class AuthUnauthenticated extends AuthState {
  final String? message;

  const AuthUnauthenticated({this.message});

  @override
  List<Object?> get props => [message];
}

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String nombre;
  final String email;
  final String password;
  final String tipoViajero;

  const RegisterRequested({
    required this.nombre,
    required this.email,
    required this.password,
    required this.tipoViajero,
  });

  @override
  List<Object?> get props => [nombre, email, password, tipoViajero];
}

/// Pide el perfil de nuevo para mostrar la reputación y el nivel al día.
class ProfileRefreshRequested extends AuthEvent {}

/// Cierra la sesión con correo y vuelve a la cuenta invisible del teléfono; [message] se le muestra al viajero.
class LogoutRequested extends AuthEvent {
  final String? message;

  const LogoutRequested({this.message});

  @override
  List<Object?> get props => [message];
}

/// Borra la cuenta y sus datos (Perfil › Privacidad); se sigue con una cuenta invisible nueva.
class AccountDeletionRequested extends AuthEvent {
  const AccountDeletionRequested();
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const cuentaBorrada = 'Borramos tu cuenta y tus datos.';

  static const sinConexion = 'Karta necesita internet la primera vez que se abre. Revisa tus datos o tu Wi-Fi.';

  final AuthRepository repository;

  AuthBloc({required this.repository}) : super(AuthUnknown()) {
    // Nunca se pide iniciar sesión para entrar: sin sesión guardada se usa la cuenta invisible.
    on<AuthStarted>((event, emit) async {
      try {
        final usuario = await repository.restoreSession() ?? await repository.entrarSinCuenta();
        emit(AuthAuthenticated(usuario));
      } catch (_) {
        emit(const AuthUnauthenticated(message: sinConexion));
      }
    });

    on<LoginRequested>((event, emit) async {
      final actual = _actual;
      if (actual == null) return;
      emit(AuthInProgress(actual));
      try {
        emit(AuthAuthenticated(await repository.login(email: event.email, password: event.password)));
      } catch (e) {
        emit(AuthFailure(actual, _clean(e)));
      }
    });

    // Desde la cuenta invisible, el servidor le pone correo a esa misma cuenta.
    on<RegisterRequested>((event, emit) async {
      final actual = _actual;
      if (actual == null) return;
      emit(AuthInProgress(actual));
      try {
        emit(AuthAuthenticated(await repository.register(
          nombre: event.nombre,
          email: event.email,
          password: event.password,
          tipoViajero: event.tipoViajero,
        )));
      } catch (e) {
        emit(AuthFailure(actual, _clean(e)));
      }
    });

    on<ProfileRefreshRequested>((event, emit) async {
      final actual = _actual;
      if (actual == null) return;
      try {
        final usuario = await repository.refresh();
        if (usuario != null && state is AuthAuthenticated) emit(AuthAuthenticated(usuario));
      } on SesionVencida {
        await _volverASinCuenta(
          emit,
          actual.sinCuenta ? null : 'Tu sesión expiró. Entra de nuevo con tu correo desde tu perfil.',
        );
      }
    });

    on<LogoutRequested>((event, emit) => _volverASinCuenta(emit, event.message));

    on<AccountDeletionRequested>((event, emit) async {
      final actual = _actual;
      if (actual == null) return;
      emit(AuthInProgress(actual));
      try {
        try {
          await repository.borrarCuenta();
        } on SesionVencida {
          // La sesión invisible se renueva sola; con correo hay que entrar de nuevo.
          if (!await repository.renovarSiEsInvisible()) rethrow;
          await repository.borrarCuenta();
        }
      } on SesionVencida {
        emit(AuthAuthenticated(actual, aviso: 'Tu sesión expiró: entra de nuevo con tu correo para borrar tu cuenta.'));
        return;
      } catch (e) {
        emit(AuthAuthenticated(actual, aviso: 'No pudimos borrar tu cuenta: ${_clean(e)}'));
        return;
      }
      try {
        emit(AuthAuthenticated(await repository.entrarSinCuenta(), aviso: cuentaBorrada));
      } catch (_) {
        emit(const AuthUnauthenticated(message: cuentaBorrada));
      }
    });
  }

  Usuario? get _actual => switch (state) {
        AuthAuthenticated(:final usuario) => usuario,
        _ => null,
      };

  Future<void> _volverASinCuenta(Emitter<AuthState> emit, String? aviso) async {
    await repository.logout();
    try {
      emit(AuthAuthenticated(await repository.entrarSinCuenta(), aviso: aviso));
    } catch (_) {
      emit(AuthUnauthenticated(message: aviso ?? sinConexion));
    }
  }

  static String _clean(Object error) => error.toString().replaceAll('Exception: ', '');
}
