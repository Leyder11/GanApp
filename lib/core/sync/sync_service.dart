import '../network/api_client.dart';
import '../storage/sync_checkpoint_store.dart';
import '../storage/sync_local_store.dart';

class SyncService {
  SyncService({
    required this.apiClient,
    required this.syncLocalStore,
    required this.syncCheckpointStore,
  });

  final ApiClient apiClient;
  final SyncLocalStore syncLocalStore;
  final SyncCheckpointStore syncCheckpointStore;

  Future<int> pendingActionsCount() {
    return syncLocalStore.pendingCount();
  }

  Future<String?> lastSyncAt() {
    return syncCheckpointStore.readLastSync();
  }

  Future<bool> isServerReachable() async {
    try {
      await apiClient.getJson('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SyncResult> pushPendingActions({required String accessToken}) async {
    final pendingActions = await syncLocalStore.getPendingActions();
    if (pendingActions.isEmpty) {
      return const SyncResult(pushed: 0, pulled: 0);
    }

    final response = await apiClient.postJson(
      '/api/v1/sync/push',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'actions': pendingActions
            .map(
              (action) => {
                'collection': action.table,
                'operation': action.operation,
                'id': action.entityId,
                'payload': action.payload,
              },
            )
            .toList(),
      },
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Respuesta invalida durante push',
        statusCode: 500,
      );
    }

    final rejectedCount = _toInt(data['rejectedCount']);
    final appliedCount = _toInt(data['appliedCount']);

    if (rejectedCount == 0) {
      await syncLocalStore.clearPendingActions();
    }

    return SyncResult(pushed: appliedCount, pulled: 0);
  }

  Future<SyncResult> pullChanges({
    required String accessToken,
    String? since,
  }) async {
    final effectiveSince = since ?? await syncCheckpointStore.readLastSync();
    final query = effectiveSince == null || effectiveSince.isEmpty
        ? ''
        : '?since=$effectiveSince';

    final response = await apiClient.getJson(
      '/api/v1/sync/pull$query',
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Respuesta invalida durante pull',
        statusCode: 500,
      );
    }

    final changes = data['changes'];
    if (changes is! Map<String, dynamic>) {
      return const SyncResult(pushed: 0, pulled: 0);
    }

    final pulled = changes.values.fold<int>(0, (sum, value) {
      if (value is List) {
        return sum + value.length;
      }
      return sum;
    });

    final serverTime = data['serverTime']?.toString();
    if (serverTime != null && serverTime.isNotEmpty) {
      await syncCheckpointStore.saveLastSync(serverTime);
    }

    return SyncResult(pushed: 0, pulled: pulled);
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class SyncResult {
  const SyncResult({required this.pushed, required this.pulled});

  final int pushed;
  final int pulled;
}
