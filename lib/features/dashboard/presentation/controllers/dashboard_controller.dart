import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/sync/sync_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/dashboard_repository.dart';
import '../../domain/dashboard_summary.dart';
import '../../domain/module_item.dart';
import '../../../user_profile/data/user_profile_repository.dart';
import '../../../user_profile/domain/farm.dart';
import '../../../user_profile/domain/user_profile.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    required this.authController,
    required this.dashboardRepository,
    required this.syncService,
    required this.userProfileRepository,
  });

  final AuthController authController;
  final DashboardRepository dashboardRepository;
  final SyncService syncService;
  final UserProfileRepository userProfileRepository;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  DashboardSummary? _summary;
  String _farmName = 'Mi Finca';
  String _currentFarmId = '';
  List<Farm> _farms = const [];
  bool _isOnline = false;
  int _pendingActions = 0;
  String? _lastSyncAt;
  bool _autoSyncStarted = false;
  bool _wasReachable = false;
  Timer? _autoSyncTimer;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  DashboardSummary? get summary => _summary;
  String get farmName => _farmName;
  String get currentFarmId => _currentFarmId;
  List<Farm> get farms => _farms;
  bool get isOnline => _isOnline;
  int get pendingActions => _pendingActions;
  String? get lastSyncAt => _lastSyncAt;
  List<PartoAlert> get alertsProximoParto =>
      _summary?.alertsProximoParto ?? const [];
    List<PartoAlert> get partosProyectados30 =>
      _summary?.partosProyectados30 ?? const [];
    List<RetiroAlert> get alertsRetiroActivo =>
      _summary?.alertsRetiroActivo ?? const [];
    InventoryReport get inventoryReport =>
      _summary?.inventoryReport ??
      const InventoryReport(
      totalAnimales: 0,
      porEstado: {},
      porRaza: {},
      porSexo: {},
      );
    List<ProduccionAnimalMes> get produccionPorAnimalMes =>
      _summary?.produccionPorAnimalMes ?? const [];
  List<TrendPoint> get tendencia7Dias => _summary?.tendencia7Dias ?? const [];
  List<TrendPoint> get tendencia30Dias => _summary?.tendencia30Dias ?? const [];

  List<ModuleItem> get modules => const [
    ModuleItem(
      icon: Icons.pets_outlined,
      title: 'Ganado Bovino',
      description: 'Inventario, estado y trazabilidad.',
      resourcePath: 'vacas',
    ),
    ModuleItem(
      icon: Icons.favorite_border_rounded,
      title: 'Control Reproductivo',
      description: 'Ciclos, servicios y parto estimado.',
      resourcePath: 'eventos-reproductivos',
    ),
    ModuleItem(
      icon: Icons.water_drop_outlined,
      title: 'Produccion de Leche',
      description: 'Registro diario y resumen semanal.',
      resourcePath: 'prod-leche',
    ),
    ModuleItem(
      icon: Icons.health_and_safety_outlined,
      title: 'Control Sanitario',
      description: 'Vacunas, tratamientos y alertas.',
      resourcePath: 'eventos-veterinarios',
    ),
  ];

  List<KpiItem> get kpis {
    final data = _summary;
    if (data == null) {
      return const [
        KpiItem(label: 'Total cabezas', value: '-'),
        KpiItem(label: 'En produccion', value: '-'),
        KpiItem(label: 'Gestantes', value: '-'),
        KpiItem(label: 'En tratamiento', value: '-'),
        KpiItem(label: 'Leche hoy (L)', value: '-'),
        KpiItem(label: 'Leche semana (L)', value: '-'),
        KpiItem(label: 'Leche mes (L)', value: '-'),
      ];
    }

    return [
      KpiItem(label: 'Total cabezas', value: '${data.totalCabezas}'),
      KpiItem(label: 'En produccion', value: '${data.enProduccion}'),
      KpiItem(label: 'Gestantes', value: '${data.gestantes}'),
      KpiItem(label: 'En tratamiento', value: '${data.enTratamiento}'),
      KpiItem(
        label: 'Leche hoy (L)',
        value: data.totalLecheHoy.toStringAsFixed(1),
      ),
      KpiItem(
        label: 'Leche semana (L)',
        value: data.totalLecheSemana.toStringAsFixed(1),
      ),
      KpiItem(
        label: 'Leche mes (L)',
        value: data.totalLecheMes.toStringAsFixed(1),
      ),
    ];
  }

  Future<void> loadSummary() async {
    final token = authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      _errorMessage = 'No hay sesion activa.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        dashboardRepository.getSummary(accessToken: token),
        userProfileRepository.getMyProfile(accessToken: token),
        userProfileRepository.getMyFarms(accessToken: token),
        syncService.pendingActionsCount(),
        syncService.lastSyncAt(),
        syncService.isServerReachable(),
      ]);

      _summary = results[0] as DashboardSummary;
      final profile = results[1] as UserProfile;
      _farmName = profile.nombreFinca;
      _currentFarmId = profile.currentFarmId;
      _farms = results[2] as List<Farm>;
      _pendingActions = results[3] as int;
      _lastSyncAt = results[4] as String?;
      _isOnline = results[5] as bool;
      _wasReachable = _isOnline;
      _ensureAutoSyncLoop();
    } catch (_) {
      _errorMessage = 'No se pudo cargar el resumen.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> syncNow() async {
    final token = authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return 'No hay sesion activa para sincronizar.';
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final pushed = await syncService.pushPendingActions(accessToken: token);
      final pulled = await syncService.pullChanges(accessToken: token);
      _pendingActions = await syncService.pendingActionsCount();
      _lastSyncAt = await syncService.lastSyncAt();
      _isOnline = await syncService.isServerReachable();
      await loadSummary();

      return 'Sync completa. Subidos: ${pushed.pushed}, bajados: ${pulled.pulled}';
    } catch (_) {
      return 'No se pudo sincronizar.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _ensureAutoSyncLoop() {
    if (_autoSyncStarted) {
      return;
    }

    _autoSyncStarted = true;
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final token = authController.session?.accessToken;
      if (token == null || token.isEmpty || _isSyncing) {
        return;
      }

      final reachable = await syncService.isServerReachable();
      if (_isOnline != reachable) {
        _isOnline = reachable;
        notifyListeners();
      }

      if (reachable && !_wasReachable) {
        _pendingActions = await syncService.pendingActionsCount();
        if (_pendingActions > 0) {
          await syncNow();
        } else {
          notifyListeners();
        }
      }

      _wasReachable = reachable;
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> updateFarmName(String farmName) async {
    final token = authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final normalized = farmName.trim();
    if (normalized.isEmpty) {
      return;
    }

    final profile = await userProfileRepository.updateFarmName(
      accessToken: token,
      farmName: normalized,
    );

    _farmName = profile.nombreFinca;
    _currentFarmId = profile.currentFarmId;
    _farms = await userProfileRepository.getMyFarms(accessToken: token);
    notifyListeners();
  }

  Future<void> selectFarm(String farmId) async {
    final token = authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    if (farmId.isEmpty) {
      return;
    }

    final profile = await userProfileRepository.selectFarm(
      accessToken: token,
      farmId: farmId,
    );

    _farmName = profile.nombreFinca;
    _currentFarmId = profile.currentFarmId;
    notifyListeners();
  }

  Future<void> createFarm(String farmName) async {
    final token = authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final normalized = farmName.trim();
    if (normalized.isEmpty) {
      return;
    }

    await userProfileRepository.createFarm(
      accessToken: token,
      farmName: normalized,
    );

    _farms = await userProfileRepository.getMyFarms(accessToken: token);
    notifyListeners();
  }
}

class KpiItem {
  const KpiItem({required this.label, required this.value});

  final String label;
  final String value;
}
