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
  alias: 'Ana',
  nivel: 1,
);

/// La cuenta invisible del teléfono: sin nombre ni correo.
const _invisible = Usuario(
  id: '665f1c2b9a1e4b0099999999',
  email: null,
  nombre: null,
  tipoViajero: null,
  reputacion: 112,
  alias: 'Viajero sin cuenta',
  nivel: 1,
  sinCuenta: true,
);

/// Repositorio en memoria: acepta solo la clave "correcta".
class FakeAuthRepository implements AuthRepository {
  Usuario? sesionGuardada;
  bool cerroSesion = false;

  /// La primera vez sin conexión no se puede crear la cuenta invisible.
  bool sinConexion = false;

  @override
  String? get token => sesionGuardada == null ? null : 'token';

  @override
  Future<Usuario> entrarSinCuenta() async {
    if (sinConexion) throw Exception('No se pudo conectar con el servidor de Karta.');
    return sesionGuardada = _invisible;
  }

  @override
  Future<bool> renovarSiEsInvisible() async => sesionGuardada?.sinCuenta == true;

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
    // El servidor le pone correo a la misma cuenta: conserva el id y la reputación.
    return sesionGuardada = Usuario(
      id: _invisible.id, email: email, nombre: nombre, tipoViajero: tipoViajero,
      reputacion: _invisible.reputacion, alias: nombre, nivel: 1,
    );
  }

  @override
  Future<Usuario?> restoreSession() async => sesionGuardada;

  /// Lo que devuelve el servidor al pedir el perfil de nuevo; null simula que no hubo señal.
  Usuario? perfilEnServidor;
  bool sesionVencida = false;

  @override
  Future<Usuario?> refresh() async {
    if (sesionVencida) throw const SesionVencida();
    return perfilEnServidor;
  }

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

  Future<void> entrar(Usuario usuario) async {
    repository.sesionGuardada = usuario;
    bloc.add(AuthStarted());
    await expectLater(bloc.stream, emits(AuthAuthenticated(usuario)));
  }

  test('sin sesión guardada entra con la cuenta invisible, sin pedir iniciar sesión', () async {
    bloc.add(AuthStarted());
    await expectLater(bloc.stream, emits(const AuthAuthenticated(_invisible)));
  });

  test('la primera vez sin conexión pide reintentar', () async {
    repository.sinConexion = true;
    bloc.add(AuthStarted());
    await expectLater(bloc.stream, emits(const AuthUnauthenticated(message: AuthBloc.sinConexion)));
  });

  test('con sesión guardada entra directo al mapa', () => entrar(_usuario));

  test('entrar con correo desde la cuenta invisible', () async {
    await entrar(_invisible);
    bloc.add(const LoginRequested(email: 'ana@karta.app', password: 'correcta'));
    await expectLater(bloc.stream, emitsInOrder([const AuthInProgress(_invisible), const AuthAuthenticated(_usuario)]));
    expect((bloc.state as AuthAuthenticated).conCuentaLista, isTrue);
  });

  test('si el correo o la clave fallan, lo dice sin "Exception" y sigue la cuenta invisible', () async {
    await entrar(_invisible);
    bloc.add(const LoginRequested(email: 'ana@karta.app', password: 'mala'));
    await expectLater(
      bloc.stream,
      emitsInOrder([const AuthInProgress(_invisible), const AuthFailure(_invisible, 'Correo o contraseña incorrectos.')]),
    );
    expect(bloc.state, isA<AuthAuthenticated>());
    expect((bloc.state as AuthAuthenticated).conCuentaLista, isFalse);
  });

  test('registrarse desde la cuenta invisible conserva la cuenta y la reputación', () async {
    await entrar(_invisible);
    bloc.add(const RegisterRequested(nombre: 'Ana', email: 'ana@karta.app', password: 'ClaveSegura123', tipoViajero: 'Residente'));
    await expectLater(bloc.stream, emitsThrough(isA<AuthAuthenticated>().having((s) => s.conCuentaLista, 'lista', isTrue)));
    final usuario = (bloc.state as AuthAuthenticated).usuario;
    expect((usuario.id, usuario.reputacion, usuario.sinCuenta), (_invisible.id, 112, false));
  });

  test('cerrar sesión vuelve a la cuenta invisible y avisa', () async {
    await entrar(_usuario);
    bloc.add(const LogoutRequested(message: 'Tu sesión expiró.'));
    await expectLater(bloc.stream, emits(const AuthAuthenticated(_invisible, aviso: 'Tu sesión expiró.')));
    expect(repository.cerroSesion, isTrue);
  });

  group('al pedir el perfil de nuevo', () {
    test('muestra la reputación y el nivel nuevos', () async {
      await entrar(_usuario);
      const subio = Usuario(
        id: '665f1c2b9a1e4b0012345678', email: 'ana@karta.app', nombre: 'Ana', tipoViajero: 'Residente',
        reputacion: 152, alias: 'Ana', nivel: 2,
      );
      repository.perfilEnServidor = subio;
      bloc.add(ProfileRefreshRequested());
      await expectLater(bloc.stream, emits(const AuthAuthenticated(subio)));
    });

    test('si la sesión con correo venció, vuelve a la cuenta invisible y lo explica', () async {
      await entrar(_usuario);
      repository.sesionVencida = true;
      bloc.add(ProfileRefreshRequested());
      await expectLater(
        bloc.stream,
        emits(const AuthAuthenticated(_invisible,
            aviso: 'Tu sesión expiró. Entra de nuevo con tu correo desde tu perfil.')),
      );
    });

    test('si la que venció era la invisible, la renueva sin avisar', () async {
      await entrar(_invisible);
      repository.sesionVencida = true;
      bloc.add(ProfileRefreshRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // La misma cuenta, sin aviso: el estado no cambia y el viajero no ve nada.
      expect(repository.cerroSesion, isTrue);
      expect(bloc.state, const AuthAuthenticated(_invisible));
    });
  });
}
