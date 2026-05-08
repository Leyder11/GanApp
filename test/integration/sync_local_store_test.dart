import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/core/storage/sync_local_store.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

SyncAction makeAction({
  String table = 'products',
  String entityId = 'entity-1',
  String operation = 'create',
  Map<String, dynamic>? payload,
  DateTime? createdAt,
}) =>
    SyncAction(
      table: table,
      entityId: entityId,
      operation: operation,
      payload: payload ?? {'name': 'Test Product'},
      createdAt: createdAt ?? DateTime(2024, 6, 15, 10, 30),
    );

void main() {
  // ─── Configuración FFI para tests en desktop/CI ──────────────────────────
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SyncLocalStore sut;

  setUp(() async {
    // Usa base de datos en memoria: cada test obtiene una BD aislada y limpia.
    // Esto evita el error "database already been closed" que ocurre cuando
    // deleteDatabase() cierra la BD pero el store aún guarda la referencia.
    sut = SyncLocalStore(databasePath: inMemoryDatabasePath);
  });

  tearDown(() async {
    // Cierra la BD después de cada test para liberar la instancia cacheada.
    // Sin esto se produce: "Bad state: This database has already been closed"
    await sut.close();
  });

  // ─── enqueue ──────────────────────────────────────────────────────────────

  group('enqueue', () {
    test('encola una acción y la persiste en la base de datos', () async {
      final action = makeAction();

      await sut.enqueue(action);

      final count = await sut.pendingCount();
      expect(count, 1);
    });

    test('persiste todos los campos de la SyncAction correctamente', () async {
      final action = makeAction(
        table: 'orders',
        entityId: 'order-123',
        operation: 'update',
        payload: {'status': 'delivered', 'qty': 3},
        createdAt: DateTime(2024, 1, 15, 8, 0, 0),
      );

      await sut.enqueue(action);
      final result = await sut.getPendingActions();

      expect(result.first.table, 'orders');
      expect(result.first.entityId, 'order-123');
      expect(result.first.operation, 'update');
      expect(result.first.payload, {'status': 'delivered', 'qty': 3});
      expect(result.first.createdAt, DateTime(2024, 1, 15, 8, 0, 0));
    });

    test('permite encolar múltiples acciones', () async {
      await sut.enqueue(makeAction(entityId: 'e1'));
      await sut.enqueue(makeAction(entityId: 'e2'));
      await sut.enqueue(makeAction(entityId: 'e3'));

      final count = await sut.pendingCount();
      expect(count, 3);
    });

    test('permite encolar acciones para el mismo entityId (no hace upsert)',
        () async {
      await sut.enqueue(makeAction(entityId: 'same-id', operation: 'create'));
      await sut.enqueue(makeAction(entityId: 'same-id', operation: 'update'));

      final count = await sut.pendingCount();
      expect(count, 2);
    });

    test('serializa y deserializa correctamente payload con tipos anidados',
        () async {
      final complexPayload = {
        'nested': {'key': 'value'},
        'list': [1, 2, 3],
        'flag': true,
        'number': 42.5,
      };

      await sut.enqueue(makeAction(payload: complexPayload));
      final result = await sut.getPendingActions();

      expect(result.first.payload, complexPayload);
    });
  });

  // ─── getPendingActions ────────────────────────────────────────────────────

  group('getPendingActions', () {
    test('retorna lista vacía cuando no hay acciones pendientes', () async {
      final result = await sut.getPendingActions();
      expect(result, isEmpty);
    });

    test('retorna las acciones en orden de inserción (FIFO)', () async {
      await sut.enqueue(makeAction(entityId: 'first'));
      await sut.enqueue(makeAction(entityId: 'second'));
      await sut.enqueue(makeAction(entityId: 'third'));

      final result = await sut.getPendingActions();

      expect(result[0].entityId, 'first');
      expect(result[1].entityId, 'second');
      expect(result[2].entityId, 'third');
    });

    test('retorna instancias de SyncAction correctamente tipadas', () async {
      await sut.enqueue(makeAction());

      final result = await sut.getPendingActions();

      expect(result.first, isA<SyncAction>());
    });

    test('retorna todas las acciones sin modificar su contenido', () async {
      final actions = [
        makeAction(entityId: 'a', table: 'products', operation: 'create'),
        makeAction(entityId: 'b', table: 'orders', operation: 'update'),
        makeAction(entityId: 'c', table: 'customers', operation: 'delete'),
      ];

      for (final a in actions) {
        await sut.enqueue(a);
      }

      final result = await sut.getPendingActions();
      expect(result.length, 3);
      expect(result.map((r) => r.entityId), ['a', 'b', 'c']);
      expect(result.map((r) => r.table), ['products', 'orders', 'customers']);
      expect(result.map((r) => r.operation), ['create', 'update', 'delete']);
    });
  });

  // ─── clearPendingActions ──────────────────────────────────────────────────

  group('clearPendingActions', () {
    test('elimina todas las acciones pendientes', () async {
      await sut.enqueue(makeAction(entityId: 'e1'));
      await sut.enqueue(makeAction(entityId: 'e2'));

      await sut.clearPendingActions();

      final count = await sut.pendingCount();
      expect(count, 0);
    });

    test('no lanza excepción si no hay acciones al limpiar', () async {
      expect(() => sut.clearPendingActions(), returnsNormally);
    });

    test('la lista queda vacía después de clear', () async {
      await sut.enqueue(makeAction());
      await sut.clearPendingActions();

      final result = await sut.getPendingActions();
      expect(result, isEmpty);
    });

    test('permite encolar nuevas acciones después de limpiar', () async {
      await sut.enqueue(makeAction(entityId: 'antes'));
      await sut.clearPendingActions();

      await sut.enqueue(makeAction(entityId: 'despues'));

      final result = await sut.getPendingActions();
      expect(result.length, 1);
      expect(result.first.entityId, 'despues');
    });
  });

  // ─── pendingCount ─────────────────────────────────────────────────────────

  group('pendingCount', () {
    test('retorna 0 cuando no hay acciones pendientes', () async {
      final count = await sut.pendingCount();
      expect(count, 0);
    });

    test('retorna el número exacto de acciones en cola', () async {
      await sut.enqueue(makeAction(entityId: 'e1'));
      await sut.enqueue(makeAction(entityId: 'e2'));
      await sut.enqueue(makeAction(entityId: 'e3'));

      final count = await sut.pendingCount();
      expect(count, 3);
    });

    test('decrementa a 0 correctamente después de clear', () async {
      await sut.enqueue(makeAction());
      await sut.clearPendingActions();

      final count = await sut.pendingCount();
      expect(count, 0);
    });

    test('se incrementa correctamente con cada enqueue', () async {
      for (var i = 1; i <= 5; i++) {
        await sut.enqueue(makeAction(entityId: 'entity-$i'));
        final count = await sut.pendingCount();
        expect(count, i);
      }
    });
  });

  // ─── flujo completo ───────────────────────────────────────────────────────

  group('flujo completo', () {
    test('enqueue → getPendingActions → clearPendingActions → pendingCount = 0',
        () async {
      // 1. Encola acciones
      await sut.enqueue(makeAction(entityId: 'a', operation: 'create'));
      await sut.enqueue(makeAction(entityId: 'b', operation: 'update'));
      expect(await sut.pendingCount(), 2);

      // 2. Lee y verifica FIFO
      final pending = await sut.getPendingActions();
      expect(pending.length, 2);
      expect(pending[0].entityId, 'a');
      expect(pending[1].entityId, 'b');

      // 3. Simula push exitoso: limpia
      await sut.clearPendingActions();
      expect(await sut.pendingCount(), 0);
      expect(await sut.getPendingActions(), isEmpty);
    });

    test('simula ciclo de sync completo con re-enqueue tras fallo', () async {
      // Acción original
      final action = makeAction(entityId: 'product-1', operation: 'create');
      await sut.enqueue(action);

      // Primer intento de push "falla" → no se limpia
      expect(await sut.pendingCount(), 1);

      // Segunda acción llega mientras la primera está pendiente
      await sut.enqueue(makeAction(entityId: 'product-2', operation: 'update'));
      expect(await sut.pendingCount(), 2);

      // Segundo intento exitoso → se limpia todo
      await sut.clearPendingActions();
      expect(await sut.pendingCount(), 0);
    });
  });
}