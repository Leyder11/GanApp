import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_1/core/network/api_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late ApiClient sut;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    sut = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockClient);
  });

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void givenGetReturns(String body, int status) {
    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(body, status));
  }

  void givenGetThrows(Object error) {
    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenThrow(error);
  }

  void givenPostReturns(String body, int status) {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(body, status));
  }

  void givenPostThrows(Object error) {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenThrow(error);
  }

  void givenPatchReturns(String body, int status) {
    when(() => mockClient.patch(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(body, status));
  }

  void givenDeleteReturns(String body, int status) {
    when(() => mockClient.delete(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(body, status));
  }

  // ─── Constructor ─────────────────────────────────────────────────────────────

  group('Constructor', () {
    test('acepta http://localhost sin lanzar excepción', () {
      expect(
        () => ApiClient(baseUrl: 'http://localhost:3000', httpClient: mockClient),
        returnsNormally,
      );
    });

    test('acepta http://127.0.0.1 sin lanzar excepción', () {
      expect(
        () => ApiClient(baseUrl: 'http://127.0.0.1:3000', httpClient: mockClient),
        returnsNormally,
      );
    });

    test('acepta http://10.0.2.2 (emulador Android) sin lanzar excepción', () {
      expect(
        () => ApiClient(baseUrl: 'http://10.0.2.2:3000', httpClient: mockClient),
        returnsNormally,
      );
    });

    test('acepta URLs HTTPS en cualquier dominio sin lanzar excepción', () {
      expect(
        () => ApiClient(
            baseUrl: 'https://api.example.com', httpClient: mockClient),
        returnsNormally,
      );
    });
  });

  // ─── getJson ─────────────────────────────────────────────────────────────────

  group('getJson', () {
    test('retorna el mapa decodificado en respuesta 200', () async {
      givenGetReturns('{"ok": true, "value": 42}', 200);

      final result = await sut.getJson('/health');

      expect(result, {'ok': true, 'value': 42});
    });

    test('retorna mapa vacío cuando el body está vacío y el status es 200',
        () async {
      givenGetReturns('', 200);

      final result = await sut.getJson('/health');

      expect(result, isEmpty);
    });

    test('retorna mapa vacío cuando el body es un array JSON y el status es 200',
        () async {
      givenGetReturns('[1, 2, 3]', 200);

      final result = await sut.getJson('/list');

      expect(result, isEmpty);
    });

    test('lanza ApiException con el mensaje del payload en respuesta 4xx',
        () async {
      givenGetReturns('{"message": "No encontrado"}', 404);

      expect(
        () => sut.getJson('/missing'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'No encontrado'),
        ),
      );
    });

    test('extrae mensaje desde error.message cuando viene anidado', () async {
      givenGetReturns('{"error": {"message": "Token inválido"}}', 401);

      expect(
        () => sut.getJson('/protected'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Token inválido'),
        ),
      );
    });

    test('usa mensaje de fallback cuando el payload no tiene message', () async {
      givenGetReturns('{}', 500);

      expect(
        () => sut.getJson('/crash'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'Error de comunicacion'),
        ),
      );
    });

    test('lanza ApiException con statusCode 408 ante TimeoutException', () {
      givenGetThrows(TimeoutException('timeout'));

      expect(
        () => sut.getJson('/slow'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 408),
        ),
      );
    });

    test('lanza ApiException con statusCode 0 ante error de red genérico', () {
      givenGetThrows(Exception('Connection refused'));

      expect(
        () => sut.getJson('/any'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0),
        ),
      );
    });

    test('re-lanza ApiException sin envolverla', () {
      givenGetThrows(ApiException(message: 'ya procesado', statusCode: 422));

      expect(
        () => sut.getJson('/any'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.message, 'message', 'ya procesado'),
        ),
      );
    });

    test('envía Content-Type application/json por defecto', () async {
      givenGetReturns('{}', 200);

      await sut.getJson('/endpoint');

      final captured = verify(
        () => mockClient.get(any(), headers: captureAny(named: 'headers')),
      ).captured;

      final headers = captured.first as Map<String, String>;
      expect(headers['Content-Type'], 'application/json');
    });

    test('combina headers personalizados con los por defecto', () async {
      givenGetReturns('{}', 200);

      await sut.getJson('/endpoint',
          headers: {'Authorization': 'Bearer token123'});

      final captured = verify(
        () => mockClient.get(any(), headers: captureAny(named: 'headers')),
      ).captured;

      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], 'Bearer token123');
      expect(headers['Content-Type'], 'application/json');
    });
  });

  // ─── postJson ────────────────────────────────────────────────────────────────

  group('postJson', () {
    test('retorna el mapa decodificado en respuesta 201', () async {
      givenPostReturns('{"id": "abc-123"}', 201);

      final result = await sut.postJson('/items', body: {'name': 'test'});

      expect(result, {'id': 'abc-123'});
    });

    test('lanza ApiException con statusCode 400 en respuesta de error', () {
      givenPostReturns('{"message": "Datos inválidos"}', 400);

      expect(
        () => sut.postJson('/items', body: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Datos inválidos'),
        ),
      );
    });

    test('lanza ApiException con statusCode 408 ante TimeoutException', () {
      givenPostThrows(TimeoutException('timeout'));

      expect(
        () => sut.postJson('/items', body: {}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 408),
        ),
      );
    });

    test('lanza ApiException con statusCode 0 ante error de red', () {
      givenPostThrows(Exception('No network'));

      expect(
        () => sut.postJson('/items', body: {}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0),
        ),
      );
    });
  });

  // ─── patchJson ───────────────────────────────────────────────────────────────

  group('patchJson', () {
    test('retorna el mapa decodificado en respuesta 200', () async {
      givenPatchReturns('{"updated": true}', 200);

      final result =
          await sut.patchJson('/items/1', body: {'name': 'actualizado'});

      expect(result, {'updated': true});
    });

    test('lanza ApiException con statusCode 404 si el recurso no existe', () {
      givenPatchReturns('{"message": "No existe"}', 404);

      expect(
        () => sut.patchJson('/items/999', body: {}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  // ─── deleteJson ──────────────────────────────────────────────────────────────

  group('deleteJson', () {
    test('retorna mapa vacío cuando el servidor responde 200 con body vacío',
        () async {
      givenDeleteReturns('', 200);

      final result = await sut.deleteJson('/items/1');

      expect(result, isEmpty);
    });

    test('retorna el mapa del payload cuando el servidor lo incluye', () async {
      givenDeleteReturns('{"deleted": true}', 200);

      final result = await sut.deleteJson('/items/1');

      expect(result, {'deleted': true});
    });

    test('lanza ApiException con statusCode 403 si no tiene permisos', () {
      givenDeleteReturns('{"message": "Sin permisos"}', 403);

      expect(
        () => sut.deleteJson('/items/1'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });

  // ─── ApiException ────────────────────────────────────────────────────────────

  group('ApiException', () {
    test('toString incluye el statusCode', () {
      final ex = ApiException(message: 'Error de prueba', statusCode: 500);
      expect(ex.toString(), contains('500'));
    });

    test('toString incluye el mensaje', () {
      final ex = ApiException(message: 'Error de prueba', statusCode: 500);
      expect(ex.toString(), contains('Error de prueba'));
    });
  });
}
