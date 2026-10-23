import 'package:flutter_test/flutter_test.dart';
import 'package:karta/features/auth/data/repositories/auth_repository.dart';
import 'package:karta/features/auth/domain/models/usuario.dart';
import 'package:karta/features/auth/presentation/bloc/auth_bloc.dart';

const _usuario = Usuario(
  id: '665f1c2b9a1e4b0012345678',
  email: 'ana@karta.app',
  nombre: 'Ana',
  tipoViajero: 'Residente',
  reputacion: 100,
);

/// Repositorio en memoria: acepta solo la clave "correcta".
class FakeAuthRepository implements AuthRepository {
  Usuario? sesionGuardada;
  bool cerroSesion = false;

  @override
  String? get token => sesionGuardada == null ? null : 'token';

  @override
  Future<Usuario> login({required String email, required String password}) async {
    if (password != 'correcta') throw Exception('Correo o contraseña incorrectos.');
    return sesionGuardada = _usuario;
  }

  @override
  Future<Usuario> register({
    required String nombre,
    required String email,
    required String password,
    required String tipoViajero,
  }) async {
    return sesionGuardada = _usuario;
  }

  @override
  Future<Usuario?> restoreSession() async => sesionGuardada;

  @override
  Future<void> logout() async {
    cerroSesion = true;
    sesionGuardada = null;
  }
}

void main() {
  late FakeAuthRepository repository;
  late AuthBloc bloc;

  setUp(() {
    repository = FakeAuthRepository();
    bloc = AuthBloc(repository: repository);
  });

  tearDown(() => bloc.close());

  test('sin sesión guardada pide iniciar sesión', () async {
    bloc.add(AuthStarted());
    await expectLater(bloc.stream, emits(const AuthUnauthenticated()));
  });

  test('con sesión guardada entra directo al mapa', () async {
    repository.sesionGuardada = _usuario;
    bloc.add(AuthStarted());
    await expectLater(bloc.stream, emits(const AuthAuthenticated(_usuario)));
  });

  test('login correcto autentica', () async {
    bloc.add(const LoginRequested(email: 'ana@karta.app', password: 'correcta'));
    await expectLater(bloc.stream, emitsInOrder([AuthInProgress(), const AuthAuthenticated(_usuario)]));
  });

  test('login incorrecto muestra el mensaje de la API sin el prefijo "Exception"', () async {
    bloc.add(const LoginRequested(email: 'ana@karta.app', password: 'mala'));
    await expectLater(
      bloc.stream,
      emitsInOrder([AuthInProgress(), const AuthUnauthenticated(message: 'Correo o contraseña incorrectos.')]),
    );
  });

  test('cerrar sesión por expiración borra el token y avisa al usuario', () async {
    repository.sesionGuardada = _usuario;
    bloc.add(const LogoutRequested(message: 'Tu sesión expiró. Inicia sesión de nuevo.'));
    await expectLater(
      bloc.stream,
      emits(const AuthUnauthenticated(message: 'Tu sesión expiró. Inicia sesión de nuevo.')),
    );
    expect(repository.cerroSesion, isTrue);
  });
}
