import '../../../core/network/api_client.dart';
import '../../../core/storage/module_cache_store.dart';
import '../../../core/storage/sync_local_store.dart';
import '../domain/module_record.dart';
import 'module_records_repository.dart';

class ModuleRecordsRepositoryImpl implements ModuleRecordsRepository {
  ModuleRecordsRepositoryImpl({
    required this.apiClient,
    required this.syncLocalStore,
    required this.cacheStore,
  });

  final ApiClient apiClient;
  final SyncLocalStore syncLocalStore;
  final ModuleCacheStore cacheStore;

  @override
  Future<List<ModuleRecord>> loadRecords({
    required String resourcePath,
    required String accessToken,
  }) async {
    try {
      final response = await apiClient.getJson(
        '/api/v1/$resourcePath',
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      final data = response['data'];
      if (data is! List) {
        return const [];
      }

      final cowLabelById = _requiresCowLabel(resourcePath)
          ? await _loadCowLabelMap(accessToken)
          : const <String, String>{};

      final normalizedItems = data.whereType<Map<String, dynamic>>().map((item) {
        if (!_requiresCowLabel(resourcePath)) {
          return item;
        }

        final vacaId = item['vacaId']?.toString();
        if (vacaId == null || vacaId.isEmpty) {
          return item;
        }

        final identificador = cowLabelById[vacaId];
        if (identificador == null || identificador.isEmpty) {
          return item;
        }

        return {...item, 'vacaIdentificador': identificador};
      }).toList();

      final mapped = normalizedItems
          .map((item) => _mapRecord(resourcePath, item))
          .toList();

      if (resourcePath == 'eventos-reproductivos') {
        mapped.sort(
          (a, b) => (b.rawData['fecha']?.toString() ?? '').compareTo(
            a.rawData['fecha']?.toString() ?? '',
          ),
        );
      }

      if (resourcePath == 'prod-leche' ||
          resourcePath == 'eventos-veterinarios') {
        mapped.sort(
          (a, b) => (b.rawData['fecha']?.toString() ?? '').compareTo(
            a.rawData['fecha']?.toString() ?? '',
          ),
        );
      }

      await cacheStore.replaceAll(resourcePath, mapped);
      return mapped;
    } catch (_) {
      // Sin internet o error → usar caché local como fallback
      final cached = await cacheStore.list(resourcePath);
      // Siempre retorna caché, aunque esté vacío (offline-first)
      return cached;
    }
  }

  @override
  Future<ModuleRecord> createRecord({
    required String resourcePath,
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await apiClient.postJson(
        '/api/v1/$resourcePath',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: payload,
      );

      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw ApiException(
          message: 'Respuesta invalida al crear registro',
          statusCode: 500,
        );
      }

      final record = _mapRecord(resourcePath, data);
      await cacheStore.upsert(resourcePath, record);
      return record;
    } on ApiException catch (error) {
      if (!_shouldQueueOffline(error)) {
        rethrow;
      }

      final localId = _buildLocalId();
      final offlinePayload = {...payload, 'id': localId};

      await syncLocalStore.enqueue(
        SyncAction(
          table: _resourceToSyncCollection(resourcePath),
          entityId: localId,
          operation: 'create',
          payload: offlinePayload,
          createdAt: DateTime.now(),
        ),
      );

      final record = _mapRecord(resourcePath, offlinePayload);
      await cacheStore.upsert(resourcePath, record);
      return record;
    } catch (_) {
      final localId = _buildLocalId();
      final offlinePayload = {...payload, 'id': localId};

      await syncLocalStore.enqueue(
        SyncAction(
          table: _resourceToSyncCollection(resourcePath),
          entityId: localId,
          operation: 'create',
          payload: offlinePayload,
          createdAt: DateTime.now(),
        ),
      );

      final record = _mapRecord(resourcePath, offlinePayload);
      await cacheStore.upsert(resourcePath, record);
      return record;
    }
  }

  @override
  Future<ModuleRecord> updateRecord({
    required String resourcePath,
    required String accessToken,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await apiClient.patchJson(
        '/api/v1/$resourcePath/$id',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: payload,
      );

      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw ApiException(
          message: 'Respuesta invalida al actualizar',
          statusCode: 500,
        );
      }

      final record = _mapRecord(resourcePath, data);
      await cacheStore.upsert(resourcePath, record);
      return record;
    } on ApiException catch (error) {
      if (!_shouldQueueOffline(error)) {
        rethrow;
      }

      await syncLocalStore.enqueue(
        SyncAction(
          table: _resourceToSyncCollection(resourcePath),
          entityId: id,
          operation: 'update',
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );

      final offlinePayload = {...payload, 'id': id};
      final record = _mapRecord(resourcePath, offlinePayload);
      await cacheStore.upsert(resourcePath, record);
      return record;
    } catch (_) {
      await syncLocalStore.enqueue(
        SyncAction(
          table: _resourceToSyncCollection(resourcePath),
          entityId: id,
          operation: 'update',
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );

      final offlinePayload = {...payload, 'id': id};
      final record = _mapRecord(resourcePath, offlinePayload);
      await cacheStore.upsert(resourcePath, record);
      return record;
    }
  }

  @override
  Future<void> deleteRecord({
    required String resourcePath,
    required String accessToken,
    required String id,
  }) async {
    try {
      await apiClient.deleteJson(
        '/api/v1/$resourcePath/$id',
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } on ApiException catch (error) {
      if (!_shouldQueueOffline(error)) {
        rethrow;
      }

      await syncLocalStore.enqueue(
        SyncAction(
          table: _resourceToSyncCollection(resourcePath),
          entityId: id,
          operation: 'delete',
          payload: const {},
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      await syncLocalStore.enqueue(
        SyncAction(
          table: _resourceToSyncCollection(resourcePath),
          entityId: id,
          operation: 'delete',
          payload: const {},
          createdAt: DateTime.now(),
        ),
      );
    }

    await cacheStore.remove(resourcePath, id);
  }

  @override
  Future<Map<String, dynamic>> getAnimalFullRecord({
    required String accessToken,
    required String animalId,
  }) async {
    final response = await apiClient.getJson(
      '/api/v1/vacas/$animalId/ficha-completa',
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Ficha completa invalida',
        statusCode: 500,
      );
    }

    return data;
  }

  ModuleRecord _mapRecord(String resourcePath, Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? _buildLocalId();

    switch (resourcePath) {
      case 'vacas':
        final sexoRaw = item['sexo']?.toString().toLowerCase() ?? '';
        final sexoLabel = sexoRaw == 'm' || sexoRaw == 'macho'
            ? 'macho'
            : sexoRaw == 'f' || sexoRaw == 'hembra'
            ? 'hembra'
            : '-';
        final edad = _computeApproxAge(item['fechaNacimiento']?.toString());
        return ModuleRecord(
          id: id,
          title: item['identificador']?.toString() ?? 'Sin identificador',
          subtitle:
              '${item['raza'] ?? '-'} • ${sexoLabel[0].toUpperCase()}${sexoLabel.substring(1)} • Estado: ${item['estado'] ?? '-'}',
          footnote:
              'Nacimiento: ${item['fechaNacimiento'] ?? '-'} • Edad aprox: $edad',
          rawData: item,
        );
      case 'eventos-reproductivos':
        final tipoEvento = item['tipoEvento']?.toString() ?? 'evento';
        final tipoEventoLabel = tipoEvento.isEmpty
            ? 'Evento'
            : tipoEvento[0].toUpperCase() + tipoEvento.substring(1);
        final vacaLabel = item['vacaIdentificador']?.toString() ?? item['vacaId']?.toString() ?? '-';
        String detalle = 'Detalle reproductivo';
        if (tipoEvento == 'diagnostico') {
          detalle =
              'Diagnostico: ${item['resultadoDiagnostico']?.toString() ?? 'pendiente'}';
        } else if (tipoEvento == 'parto') {
          detalle = 'Cria ID: ${item['criaId']?.toString() ?? '-'}';
        } else if (tipoEvento == 'aborto') {
          detalle = 'Aborto registrado';
        } else if (tipoEvento == 'servicio' || tipoEvento == 'inseminacion') {
          detalle = 'Toro: ${item['toroUtilizado']?.toString() ?? '-'}';
        }

        return ModuleRecord(
          id: id,
          title: tipoEventoLabel,
          subtitle: 'Vaca: $vacaLabel',
          footnote:
              'Fecha: ${item['fecha'] ?? '-'} • $detalle • FPP: ${item['fechaEstimadaParto'] ?? '-'}',
          rawData: item,
        );
      case 'prod-leche':
        final manana = (item['litrosManana'] ?? 0).toString();
        final tarde = (item['litrosTarde'] ?? 0).toString();
        final vacaLabel = item['vacaIdentificador']?.toString() ?? item['vacaId']?.toString() ?? '-';
        return ModuleRecord(
          id: id,
          title: 'Vaca $vacaLabel',
          subtitle: 'Total: ${item['total'] ?? 0} L • M: $manana • T: $tarde',
          footnote: 'Fecha: ${item['fecha'] ?? '-'}',
          rawData: item,
        );
      case 'eventos-veterinarios':
        final categoria = item['categoria']?.toString() ?? 'observacion';
        final vacaLabel = item['vacaIdentificador']?.toString() ?? item['vacaId']?.toString() ?? '-';
        return ModuleRecord(
          id: id,
          title: '${categoria[0].toUpperCase()}${categoria.substring(1)}',
          subtitle:
              'Vaca: $vacaLabel • Producto: ${item['producto'] ?? '-'} • Dosis: ${item['dosis'] ?? '-'}',
          footnote:
              'Fecha: ${item['fecha'] ?? '-'} • Responsable: ${item['responsable'] ?? item['veterinario'] ?? '-'}',
          rawData: item,
        );
      default:
        return ModuleRecord(
          id: id,
          title: 'Registro $id',
          subtitle: resourcePath,
          footnote: 'Detalle disponible en backend',
          rawData: item,
        );
    }
  }

  String _buildLocalId() {
    return 'local-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _shouldQueueOffline(ApiException error) {
    return error.statusCode == 0 ||
        error.statusCode == 408 ||
        error.statusCode >= 500;
  }

  bool _requiresCowLabel(String resourcePath) {
    return resourcePath == 'prod-leche' ||
        resourcePath == 'eventos-reproductivos' ||
        resourcePath == 'eventos-veterinarios';
  }

  Future<Map<String, String>> _loadCowLabelMap(String accessToken) async {
    final response = await apiClient.getJson(
      '/api/v1/vacas',
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = response['data'];
    if (data is! List) {
      return const <String, String>{};
    }

    final map = <String, String>{};
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final id = item['id']?.toString() ?? '';
      final identificador = item['identificador']?.toString() ?? id;
      if (id.isNotEmpty) {
        map[id] = identificador;
      }
    }
    return map;
  }

  String _resourceToSyncCollection(String resourcePath) {
    switch (resourcePath) {
      case 'vacas':
        return 'vacas';
      case 'prod-leche':
        return 'prod_leche';
      case 'eventos-reproductivos':
        return 'eventos_reproductivos';
      case 'eventos-veterinarios':
        return 'eventos_veterinarios';
      case 'historial-crecimiento':
        return 'historial_crecimiento';
      default:
        return resourcePath.replaceAll('-', '_');
    }
  }

  String _computeApproxAge(String? birthDateRaw) {
    if (birthDateRaw == null || birthDateRaw.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(birthDateRaw);
    if (parsed == null) {
      return '-';
    }

    final now = DateTime.now();
    int years = now.year - parsed.year;
    int months = now.month - parsed.month;
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    if (years <= 0) {
      return '$months meses';
    }

    return '$years anios';
  }
}
