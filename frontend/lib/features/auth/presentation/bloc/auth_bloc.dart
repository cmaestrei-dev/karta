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

class AuthInProgress extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Usuario usuario;

  const AuthAuthenticated(this.usuario);

  @override
  List<Object?> get props => [usuario];
}

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

class LogoutRequested extends AuthEvent {
  final String? message;

  const LogoutRequested({this.message});

  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc({required this.repository}) : super(AuthUnknown()) {

    on<AuthStarted>((event, emit) async {
      try {
        final usuario = await repository.restoreSession();
        emit(usuario == null ? const AuthUnauthenticated() : AuthAuthenticated(usuario));
      } catch (e) {
        emit(AuthUnauthenticated(message: _clean(e)));
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthInProgress());
      try {
        final usuario = await repository.login(email: event.email, password: event.password);
        emit(AuthAuthenticated(usuario));
      } catch (e) {
        emit(AuthUnauthenticated(message: _clean(e)));
      }
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthInProgress());
      try {
        final usuario = await repository.register(
          nombre: event.nombre,
          email: event.email,
          password: event.password,
          tipoViajero: event.tipoViajero,
        );
        emit(AuthAuthenticated(usuario));
      } catch (e) {
        emit(AuthUnauthenticated(message: _clean(e)));
      }
    });

    on<ProfileRefreshRequested>((event, emit) async {
      if (state is! AuthAuthenticated) return;
      try {
        final usuario = await repository.refresh();
        if (usuario != null && state is AuthAuthenticated) emit(AuthAuthenticated(usuario));
      } on SesionVencida {
        await repository.logout();
        emit(const AuthUnauthenticated(message: 'Tu sesión expiró. Inicia sesión de nuevo.'));
      }
    });

    on<LogoutRequested>((event, emit) async {
      await repository.logout();
      emit(AuthUnauthenticated(message: event.message));
    });
  }

  static String _clean(Object error) => error.toString().replaceAll('Exception: ', '');
}
