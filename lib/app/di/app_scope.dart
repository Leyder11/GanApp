import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_local_store.dart';
import '../../core/storage/module_cache_store.dart';
import '../../core/storage/sync_checkpoint_store.dart';
import '../../core/storage/sync_local_store.dart';
import '../../core/sync/sync_service.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/dashboard/data/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/dashboard_repository.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/module_records/data/module_records_repository.dart';
import '../../features/module_records/data/module_records_repository_impl.dart';
import '../../features/user_profile/data/user_profile_repository.dart';
import '../../features/user_profile/data/user_profile_repository_impl.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required super.child,
    required this.authController,
    required this.dashboardController,
    required this.moduleRecordsRepository,
    required this.syncLocalStore,
  });

  final AuthController authController;
  final DashboardController dashboardController;
  final ModuleRecordsRepository moduleRecordsRepository;
  final SyncLocalStore syncLocalStore;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope no encontrado en el arbol de widgets.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) {
    return authController != oldWidget.authController ||
        dashboardController != oldWidget.dashboardController ||
        moduleRecordsRepository != oldWidget.moduleRecordsRepository ||
        syncLocalStore != oldWidget.syncLocalStore;
  }
}

class AppDependencies {
  AppDependencies._({
    required this.authController,
    required this.dashboardController,
    required this.moduleRecordsRepository,
    required this.syncLocalStore,
  });

  final AuthController authController;
  final DashboardController dashboardController;
  final ModuleRecordsRepository moduleRecordsRepository;
  final SyncLocalStore syncLocalStore;

  static AppDependencies create() {
    const configuredBaseUrl = String.fromEnvironment(
      'GANAPP_API_BASE_URL',
      defaultValue: '',
    );
    final baseUrl = configuredBaseUrl.isNotEmpty
        ? configuredBaseUrl
        : _defaultBaseUrl();

    final apiClient = ApiClient(baseUrl: baseUrl);
    final localStore = SessionLocalStore();
    final syncCheckpointStore = SyncCheckpointStore();
    final syncLocalStore = SyncLocalStore();
    final moduleCacheStore = ModuleCacheStore();

    final AuthRepository authRepository = AuthRepositoryImpl(
      apiClient: apiClient,
      localStore: localStore,
    );

    final DashboardRepository dashboardRepository = DashboardRepositoryImpl(
      apiClient: apiClient,
    );

    final ModuleRecordsRepository moduleRecordsRepository =
        ModuleRecordsRepositoryImpl(
          apiClient: apiClient,
          syncLocalStore: syncLocalStore,
          cacheStore: moduleCacheStore,
        );

    final UserProfileRepository userProfileRepository =
        UserProfileRepositoryImpl(apiClient: apiClient);

    final syncService = SyncService(
      apiClient: apiClient,
      syncCheckpointStore: syncCheckpointStore,
      syncLocalStore: syncLocalStore,
    );

    final authController = AuthController(authRepository);
    final dashboardController = DashboardController(
      authController: authController,
      dashboardRepository: dashboardRepository,
      syncService: syncService,
      userProfileRepository: userProfileRepository,
    );

    return AppDependencies._(
      authController: authController,
      dashboardController: dashboardController,
      moduleRecordsRepository: moduleRecordsRepository,
      syncLocalStore: syncLocalStore,
    );
  }

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:5001/ganapp-d451b/us-central1/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5001/ganapp-d451b/us-central1/api';
    }

    return 'http://127.0.0.1:5001/ganapp-d451b/us-central1/api';
  }
}
