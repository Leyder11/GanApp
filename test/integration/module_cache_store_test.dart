import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/core/storage/module_cache_store.dart';
import 'package:flutter_application_1/features/module_records/domain/module_record.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

ModuleRecord makeRecord({
  String id = 'record-1',
  String title = 'Título de prueba',
  String subtitle = 'Subtítulo',
  String footnote = 'Nota al pie',
  Map<String, dynamic>? rawData,
}) =>
    ModuleRecord(
      id: id,
      title: title,
      subtitle: subtitle,
      footnote: footnote,
      rawData: rawData ?? {'key': 'value'},
    );

void main() {
  // ─── Configuración FFI para tests en desktop/CI ──────────────────────────
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ModuleCacheStore sut;
  const testResourcePath = 'test/resource/path';

  setUp(() async {
    // BD en memoria: cada test obtiene una instancia aislada y limpia.
    // Evita "Bad state: This database has already been closed".
    sut = ModuleCacheStore(databasePath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await sut.close();
  });

  // ─── replaceAll ───────────────────────────────────────────────────────────

  group('replaceAll', () {
    test('inserta los registros cuando la tabla está vacía', () async {
      final records = [
        makeRecord(id: 'r1', title: 'Primero'),
        makeRecord(id: 'r2', title: 'Segundo'),
      ];

      await sut.replaceAll(testResourcePath, records);
      final result = await sut.list(testResourcePath);

      expect(result.length, 2);
      expect(result.map((r) => r.id), containsAll(['r1', 'r2']));
    });

    test('elimina los registros previos antes de insertar los nuevos', () async {
      final first = [makeRecord(id: 'old', title: 'Viejo')];
      final second = [makeRecord(id: 'new', title: 'Nuevo')];

      await sut.replaceAll(testResourcePath, first);
      await sut.replaceAll(testResourcePath, second);

      final result = await sut.list(testResourcePath);
      expect(result.length, 1);
      expect(result.first.id, 'new');
    });

    test('deja la lista vacía cuando se pasa una lista vacía', () async {
      await sut.replaceAll(testResourcePath, [makeRecord()]);
      await sut.replaceAll(testResourcePath, []);

      final result = await sut.list(testResourcePath);
      expect(result, isEmpty);
    });

    test('solo afecta al resourcePath indicado, no a otros paths', () async {
      const otherPath = 'other/resource/path';
      await sut.replaceAll(otherPath, [makeRecord(id: 'other-1')]);

      await sut.replaceAll(testResourcePath, [makeRecord(id: 'test-1')]);

      final otherResult = await sut.list(otherPath);
      expect(otherResult.length, 1);
      expect(otherResult.first.id, 'other-1');
    });

    test('persiste todos los campos del ModuleRecord correctamente', () async {
      final record = makeRecord(
        id: 'full-record',
        title: 'Título completo',
        subtitle: 'Subtítulo completo',
        footnote: 'Nota al pie completa',
        rawData: {'nested': true, 'count': 42},
      );

      await sut.replaceAll(testResourcePath, [record]);
      final result = await sut.list(testResourcePath);

      expect(result.first.id, record.id);
      expect(result.first.title, record.title);
      expect(result.first.subtitle, record.subtitle);
      expect(result.first.footnote, record.footnote);
      expect(result.first.rawData, record.rawData);
    });
  });

  // ─── list ─────────────────────────────────────────────────────────────────

  group('list', () {
    test('retorna lista vacía cuando no hay registros para el resourcePath',
        () async {
      final result = await sut.list(testResourcePath);
      expect(result, isEmpty);
    });

    test('retorna solo los registros del resourcePath indicado', () async {
      const otherPath = 'other/path';
      await sut.replaceAll(testResourcePath, [makeRecord(id: 'mine')]);
      await sut.replaceAll(otherPath, [makeRecord(id: 'theirs')]);

      final result = await sut.list(testResourcePath);

      expect(result.length, 1);
      expect(result.first.id, 'mine');
    });

    test('retorna instancias de ModuleRecord con todos los campos', () async {
      final record = makeRecord(rawData: {'complex': [1, 2, 3]});
      await sut.replaceAll(testResourcePath, [record]);

      final result = await sut.list(testResourcePath);

      expect(result.first, isA<ModuleRecord>());
      expect(result.first.rawData, {'complex': [1, 2, 3]});
    });
  });

  // ─── upsert ───────────────────────────────────────────────────────────────

  group('upsert', () {
    test('inserta un registro nuevo cuando no existe', () async {
      final record = makeRecord(id: 'new-record');

      await sut.upsert(testResourcePath, record);
      final result = await sut.list(testResourcePath);

      expect(result.length, 1);
      expect(result.first.id, 'new-record');
    });

    test('actualiza un registro existente cuando tiene el mismo id', () async {
      final original = makeRecord(id: 'update-me', title: 'Original');
      await sut.upsert(testResourcePath, original);

      final updated = makeRecord(id: 'update-me', title: 'Actualizado');
      await sut.upsert(testResourcePath, updated);

      final result = await sut.list(testResourcePath);
      expect(result.length, 1);
      expect(result.first.title, 'Actualizado');
    });

    test('no afecta otros registros al hacer upsert de uno', () async {
      await sut.replaceAll(testResourcePath, [
        makeRecord(id: 'r1'),
        makeRecord(id: 'r2'),
      ]);

      await sut.upsert(testResourcePath, makeRecord(id: 'r3', title: 'Nuevo'));

      final result = await sut.list(testResourcePath);
      expect(result.length, 3);
    });

    test('persiste rawData complejo correctamente al actualizar', () async {
      await sut.upsert(testResourcePath, makeRecord(id: 'data-test'));
      await sut.upsert(
        testResourcePath,
        makeRecord(id: 'data-test', rawData: {'updated': true, 'list': [1, 2]}),
      );

      final result = await sut.list(testResourcePath);
      expect(result.first.rawData['updated'], isTrue);
      expect(result.first.rawData['list'], [1, 2]);
    });
  });

  // ─── remove ───────────────────────────────────────────────────────────────

  group('remove', () {
    test('elimina el registro con el id indicado', () async {
      await sut.replaceAll(testResourcePath, [
        makeRecord(id: 'keep'),
        makeRecord(id: 'delete-me'),
      ]);

      await sut.remove(testResourcePath, 'delete-me');

      final result = await sut.list(testResourcePath);
      expect(result.length, 1);
      expect(result.first.id, 'keep');
    });

    test('no lanza excepción si el id no existe', () async {
      expect(
        () => sut.remove(testResourcePath, 'non-existent'),
        returnsNormally,
      );
    });

    test('no elimina registros del mismo id en otro resourcePath', () async {
      const otherPath = 'other/path';
      await sut.upsert(testResourcePath, makeRecord(id: 'shared-id'));
      await sut.upsert(otherPath, makeRecord(id: 'shared-id'));

      await sut.remove(testResourcePath, 'shared-id');

      final otherResult = await sut.list(otherPath);
      expect(otherResult.length, 1);
    });
  });

  // ─── flujo completo ───────────────────────────────────────────────────────

  group('flujo completo', () {
    test('replaceAll → upsert → remove funciona como se espera', () async {
      // 1. Carga inicial
      await sut.replaceAll(testResourcePath, [
        makeRecord(id: 'a', title: 'Alpha'),
        makeRecord(id: 'b', title: 'Beta'),
      ]);

      // 2. Actualiza uno
      await sut.upsert(testResourcePath, makeRecord(id: 'a', title: 'Alpha V2'));

      // 3. Agrega uno nuevo
      await sut.upsert(testResourcePath, makeRecord(id: 'c', title: 'Gamma'));

      // 4. Elimina uno
      await sut.remove(testResourcePath, 'b');

      final result = await sut.list(testResourcePath);
      expect(result.length, 2);
      expect(result.map((r) => r.id), containsAll(['a', 'c']));
      expect(result.firstWhere((r) => r.id == 'a').title, 'Alpha V2');
    });
  });
}