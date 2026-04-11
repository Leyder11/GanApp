import 'package:shared_preferences/shared_preferences.dart';

class SyncCheckpointStore {
  static const _lastSyncKey = 'ganapp.sync.lastSync';

  Future<String?> readLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  Future<void> saveLastSync(String isoDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, isoDate);
  }
}
