import '../domain/module_record.dart';

abstract class ModuleRecordsRepository {
  Future<List<ModuleRecord>> loadRecords({
    required String resourcePath,
    required String accessToken,
  });

  Future<ModuleRecord> createRecord({
    required String resourcePath,
    required String accessToken,
    required Map<String, dynamic> payload,
  });

  Future<ModuleRecord> updateRecord({
    required String resourcePath,
    required String accessToken,
    required String id,
    required Map<String, dynamic> payload,
  });

  Future<void> deleteRecord({
    required String resourcePath,
    required String accessToken,
    required String id,
  });

  Future<Map<String, dynamic>> getAnimalFullRecord({
    required String accessToken,
    required String animalId,
  });
}
