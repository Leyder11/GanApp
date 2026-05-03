import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/core/storage/sync_checkpoint_store.dart';
import 'package:flutter_application_1/core/storage/sync_local_store.dart';
import 'package:flutter_application_1/core/sync/sync_service.dart';

// ─── Mocks ──────────────────────────────────────────────────────────────────

class MockApiClient extends Mock implements ApiClient {}

class MockSyncLocalStore extends Mock implements SyncLocalStore {}

class MockSyncCheckpointStore extends Mock implements SyncCheckpointStore {}

// ─── Helpers ────────────────────────────────────────────────────────────────

SyncAction makeSyncAction({
  String table = 'products',
  String entityId = 'entity-1',
  String operation = 'create',
  Map<String, dynamic>? payload,
}) =>
    SyncAction(
      table: table,
      entityId: entityId,
      operation: operation,
      payload: payload ?? {'name': 'Test'},
      createdAt: DateTime(2024, 6, 15, 10, 30),
    );

void main() {
  late MockApiClient mockApiClient;
  late MockSyncLocalStore mockSyncLocalStore;
  late MockSyncCheckpointStore mockSyncCheckpointStore;
  late SyncService sut;

  setUp(() {
    mockApiClient = MockApiClient();
    mockSyncLocalStore = MockSyncLocalStore();
    mockSyncCheckpointStore = MockSyncCheckpointStore();

    sut = SyncService(
      apiClient: mockApiClient,
      syncLocalStore: mockSyncLocalStore,
      syncCheckpointStore: mockSyncCheckpointStore,
    );
  });

  // ─── pendingActionsCount ──────────────────────────────────────────────────

  group('pendingActionsCount', () {
    test('delega al syncLocalStore y retorna el conteo', () async {
      when(() => mockSyncLocalStore.pendingCount()).thenAnswer((_) async => 5);

      final result = await sut.pendingActionsCount();

      expect(result, 5);
      verify(() => mockSyncLocalStore.pendingCount()).called(1);
    });

    test('retorna 0 cuando no hay acciones pendientes', () async {
      when(() => mockSyncLocalStore.pendingCount()).thenAnswer((_) async => 0);

      final result = await sut.pendingActionsCount();

      expect(result, 0);
    });
  });

  // ─── lastSyncAt ───────────────────────────────────────────────────────────

  group('lastSyncAt', () {
    test('delega al syncCheckpointStore y retorna la fecha', () async {
      const isoDate = '2024-06-15T10:30:00.000Z';
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => isoDate);

      final result = await sut.lastSyncAt();

      expect(result, isoDate);
      verify(() => mockSyncCheckpointStore.readLastSync()).called(1);
    });

    test('retorna null cuando nunca se ha sincronizado', () async {
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => null);

      final result = await sut.lastSyncAt();

      expect(result, isNull);
    });
  });

  // ─── isServerReachable ────────────────────────────────────────────────────

  group('isServerReachable', () {
    test('retorna true cuando /health responde sin excepción', () async {
      when(() => mockApiClient.getJson('/health', headers: any(named: 'headers')))
          .thenAnswer((_) async => {'status': 'ok'});

      final result = await sut.isServerReachable();

      expect(result, isTrue);
    });

    test('retorna false cuando /health lanza ApiException', () async {
      when(() => mockApiClient.getJson('/health', headers: any(named: 'headers')))
          .thenThrow(ApiException(message: 'Sin conexión', statusCode: 0));

      final result = await sut.isServerReachable();

      expect(result, isFalse);
    });

    test('retorna false ante cualquier excepción genérica', () async {
      when(() => mockApiClient.getJson('/health', headers: any(named: 'headers')))
          .thenThrow(Exception('Error de red'));

      final result = await sut.isServerReachable();

      expect(result, isFalse);
    });
  });

  // ─── pushPendingActions ───────────────────────────────────────────────────

  group('pushPendingActions', () {
    const token = 'bearer-test-token';

    test('retorna SyncResult(pushed:0, pulled:0) cuando no hay acciones pendientes',
        () async {
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => []);

      final result = await sut.pushPendingActions(accessToken: token);

      expect(result.pushed, 0);
      expect(result.pulled, 0);
      verifyNever(() => mockApiClient.postJson(any(), body: any(named: 'body')));
    });

    test('envía las acciones pendientes al endpoint /api/v1/sync/push', () async {
      final actions = [makeSyncAction()];
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => actions);
      when(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'appliedCount': 1, 'rejectedCount': 0},
          });
      when(() => mockSyncLocalStore.clearPendingActions())
          .thenAnswer((_) => Future.value());

      await sut.pushPendingActions(accessToken: token);

      final captured = verify(() => mockApiClient.postJson(
            captureAny(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).captured;
      expect(captured.first, '/api/v1/sync/push');
    });

    test('incluye el Authorization header con el accessToken', () async {
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => [makeSyncAction()]);
      when(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'appliedCount': 1, 'rejectedCount': 0},
          });
      when(() => mockSyncLocalStore.clearPendingActions())
          .thenAnswer((_) => Future.value());

      await sut.pushPendingActions(accessToken: token);

      final captured = verify(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: captureAny(named: 'headers'),
          )).captured;
      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], 'Bearer $token');
    });

    test('limpia las acciones pendientes cuando rejectedCount es 0', () async {
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => [makeSyncAction()]);
      when(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'appliedCount': 1, 'rejectedCount': 0},
          });
      when(() => mockSyncLocalStore.clearPendingActions())
          .thenAnswer((_) => Future.value());

      await sut.pushPendingActions(accessToken: token);

      verify(() => mockSyncLocalStore.clearPendingActions()).called(1);
    });

    test('NO limpia las acciones cuando rejectedCount > 0', () async {
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => [makeSyncAction()]);
      when(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'appliedCount': 0, 'rejectedCount': 1},
          });

      await sut.pushPendingActions(accessToken: token);

      verifyNever(() => mockSyncLocalStore.clearPendingActions());
    });

    test('retorna el appliedCount como pushed en SyncResult', () async {
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => [makeSyncAction(), makeSyncAction()]);
      when(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'appliedCount': 2, 'rejectedCount': 0},
          });
      when(() => mockSyncLocalStore.clearPendingActions())
          .thenAnswer((_) => Future.value());

      final result = await sut.pushPendingActions(accessToken: token);

      expect(result.pushed, 2);
      expect(result.pulled, 0);
    });

    test('lanza ApiException cuando la respuesta no contiene data como Map',
        () async {
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => [makeSyncAction()]);
      when(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {'data': 'invalid'});

      expect(
        () => sut.pushPendingActions(accessToken: token),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('maneja appliedCount como String numérico (ej: "3")', () async {
      when(() => mockSyncLocalStore.getPendingActions())
          .thenAnswer((_) async => [makeSyncAction()]);
      when(() => mockApiClient.postJson(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'appliedCount': '3', 'rejectedCount': '0'},
          });
      when(() => mockSyncLocalStore.clearPendingActions())
          .thenAnswer((_) => Future.value());

      final result = await sut.pushPendingActions(accessToken: token);

      expect(result.pushed, 3);
    });
  });

  // ─── pullChanges ──────────────────────────────────────────────────────────

  group('pullChanges', () {
    const token = 'bearer-test-token';
    const serverTime = '2024-06-15T10:30:00.000Z';

    test('consulta /api/v1/sync/pull sin parámetro ?since cuando no hay checkpoint',
        () async {
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => null);
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'changes': {}, 'serverTime': serverTime},
          });
      when(() => mockSyncCheckpointStore.saveLastSync(any()))
          .thenAnswer((_) => Future.value());

      await sut.pullChanges(accessToken: token);

      final captured = verify(() => mockApiClient.getJson(
            captureAny(),
            headers: any(named: 'headers'),
          )).captured;
      expect(captured.first, '/api/v1/sync/pull');
    });

    test('incluye ?since cuando hay checkpoint guardado', () async {
      const checkpoint = '2024-01-01T00:00:00.000Z';
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => checkpoint);
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'changes': {}, 'serverTime': serverTime},
          });
      // Future<void>: usar Future.value() en lugar de async {} para que
      // mocktail registre correctamente la llamada
      when(() => mockSyncCheckpointStore.saveLastSync(any()))
          .thenAnswer((_) => Future.value());

      await sut.pullChanges(accessToken: token);

      final captured = verify(() => mockApiClient.getJson(
            captureAny(),
            headers: any(named: 'headers'),
          )).captured;
      // El código de producción NO encodea la URL — usa interpolación directa
      expect(captured.first, '/api/v1/sync/pull?since=$checkpoint');
    });

    test('usa el parámetro since explícito en lugar del checkpoint', () async {
      const explicitSince = '2024-03-01T00:00:00.000Z';
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'changes': {}, 'serverTime': serverTime},
          });
      when(() => mockSyncCheckpointStore.saveLastSync(any()))
          .thenAnswer((_) => Future.value());

      await sut.pullChanges(accessToken: token, since: explicitSince);

      final captured = verify(() => mockApiClient.getJson(
            captureAny(),
            headers: any(named: 'headers'),
          )).captured;
      expect(captured.first, contains(explicitSince));
      verifyNever(() => mockSyncCheckpointStore.readLastSync());
    });

    test('guarda el serverTime devuelto por el servidor', () async {
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => null);
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'changes': {}, 'serverTime': serverTime},
          });
      when(() => mockSyncCheckpointStore.saveLastSync(any()))
          .thenAnswer((_) => Future.value());

      await sut.pullChanges(accessToken: token);

      verify(() => mockSyncCheckpointStore.saveLastSync(serverTime)).called(1);
    });

    test('cuenta correctamente los registros en changes', () async {
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => null);
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {
              'changes': {
                'products': [1, 2, 3],
                'orders': [4, 5],
              },
              'serverTime': serverTime,
            },
          });
      when(() => mockSyncCheckpointStore.saveLastSync(any()))
          .thenAnswer((_) => Future.value());

      final result = await sut.pullChanges(accessToken: token);

      expect(result.pulled, 5); // 3 + 2
      expect(result.pushed, 0);
    });

    test('retorna pulled:0 cuando changes está vacío', () async {
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => null);
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'changes': {}, 'serverTime': serverTime},
          });
      when(() => mockSyncCheckpointStore.saveLastSync(any()))
          .thenAnswer((_) => Future.value());

      final result = await sut.pullChanges(accessToken: token);

      expect(result.pulled, 0);
    });

    test('retorna pulled:0 cuando changes no es un Map', () async {
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => null);
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {'serverTime': serverTime},
          });
      when(() => mockSyncCheckpointStore.saveLastSync(any()))
          .thenAnswer((_) => Future.value());

      final result = await sut.pullChanges(accessToken: token);

      expect(result.pulled, 0);
    });

    test('lanza ApiException cuando data no es un Map', () async {
      when(() => mockSyncCheckpointStore.readLastSync())
          .thenAnswer((_) async => null);
      when(() => mockApiClient.getJson(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {'data': 'invalid'});

      expect(
        () => sut.pullChanges(accessToken: token),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}