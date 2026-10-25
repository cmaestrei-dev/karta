import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karta/core/api_client.dart';
import 'package:karta/core/api_errors.dart';

void main() {
  test('si la sesión invisible venció, la renueva y reintenta una vez sin que el viajero lo note', () async {
    var token = 'viejo';
    final usados = <String?>[];
    final api = ApiClient(
      token: () => token,
      renovarSesion: () async {
        token = 'nuevo';
        return true;
      },
      client: MockClient((pedido) async {
        usados.add(pedido.headers['Authorization']);
        return pedido.headers['Authorization'] == 'Bearer nuevo'
            ? http.Response('{"ok": true}', 201)
            : http.Response('{"detail": "Sesión inválida o expirada."}', 401);
      }),
    );
    expect(await api.post('/sightings', {'ruta': 'T103'}, auth: true), {'ok': true});
    expect(usados, ['Bearer viejo', 'Bearer nuevo']);
  });

  test('una sesión con correo que venció no se renueva sola: hay que volver a entrar', () async {
    var intentos = 0;
    final api = ApiClient(
      token: () => 'viejo',
      renovarSesion: () async => false,
      client: MockClient((_) async {
        intentos++;
        return http.Response('{"detail": "Sesión inválida o expirada."}', 401);
      }),
    );
    await expectLater(api.post('/sightings', {'ruta': 'T103'}, auth: true), throwsA(isA<SessionExpiredException>()));
    expect(intentos, 1);
  });
}
