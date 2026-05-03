import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/core/storage/sync_checkpoint_store.dart';

void main() {
  late SyncCheckpointStore sut;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sut = SyncCheckpointStore();
  });

  // ─── readLastSync ─────────────────────────────────────────────────────────

  group('readLastSync', () {
    test('retorna null cuando no hay fecha guardada', () async {
      final result = await sut.readLastSync();
      expect(result, isNull);
    });

    test('retorna la fecha guardada cuando existe', () async {
      const isoDate = '2024-06-15T10:30:00.000Z';
      SharedPreferences.setMockInitialValues({'ganapp.sync.lastSync': isoDate});

      final result = await sut.readLastSync();

      expect(result, isoDate);
    });

    test('retorna el valor exacto sin transformaciones', () async {
      const isoDate = '2024-01-01T00:00:00.000Z';
      SharedPreferences.setMockInitialValues({'ganapp.sync.lastSync': isoDate});

      final result = await sut.readLastSync();

      expect(result, isoDate);
    });
  });

  // ─── saveLastSync ─────────────────────────────────────────────────────────

  group('saveLastSync', () {
    test('persiste la fecha en SharedPreferences', () async {
      const isoDate = '2024-06-15T10:30:00.000Z';

      await sut.saveLastSync(isoDate);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ganapp.sync.lastSync'), isoDate);
    });

    test('sobreescribe la fecha anterior cuando se guarda una nueva', () async {
      const firstDate = '2024-01-01T00:00:00.000Z';
      const secondDate = '2024-06-15T10:30:00.000Z';

      await sut.saveLastSync(firstDate);
      await sut.saveLastSync(secondDate);

      final result = await sut.readLastSync();
      expect(result, secondDate);
    });

    test('acepta fechas en formato ISO 8601 con zona horaria', () async {
      const isoDate = '2024-12-31T23:59:59.999+05:00';

      await sut.saveLastSync(isoDate);

      final result = await sut.readLastSync();
      expect(result, isoDate);
    });
  });

  // ─── flujo completo ───────────────────────────────────────────────────────

  group('flujo completo', () {
    test('saveLastSync → readLastSync retorna la misma fecha guardada',
        () async {
      const isoDate = '2024-06-15T10:30:00.000Z';

      await sut.saveLastSync(isoDate);
      final result = await sut.readLastSync();

      expect(result, isoDate);
    });

    test('múltiples saves conservan únicamente el último valor', () async {
      const dates = [
        '2024-01-01T00:00:00.000Z',
        '2024-03-15T12:00:00.000Z',
        '2024-06-30T23:59:59.000Z',
      ];

      for (final date in dates) {
        await sut.saveLastSync(date);
      }

      final result = await sut.readLastSync();
      expect(result, dates.last);
    });
  });
}
