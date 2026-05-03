import 'package:flutter/material.dart';

import '../../../../app/di/app_scope.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../module_records/presentation/pages/module_records_page.dart';
import '../../../user_profile/domain/farm.dart';
import '../../domain/dashboard_summary.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/kpi_tile.dart';
import '../widgets/module_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.authController,
    required this.controller,
  });

  final AuthController authController;
  final DashboardController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _DashboardBackdrop(),
          SafeArea(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                            children: [
                              _HeroHeader(
                                userName:
                                    widget.authController.session?.displayName ??
                                    'Ganadero',
                                farmName: widget.controller.farmName,
                                isOnline: widget.controller.isOnline,
                                pendingActions: widget.controller.pendingActions,
                                isSyncing: widget.controller.isSyncing,
                                onSync: () async {
                                  final message = await widget.controller
                                      .syncNow();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              if (widget.controller.isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              if (widget.controller.errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    widget.controller.errorMessage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: Colors.red.shade300),
                                  ),
                                ),
                              ..._buildCurrentTab(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _DashboardBottomNav(
                      currentIndex: _currentTabIndex,
                      onChanged: (index) {
                        setState(() {
                          _currentTabIndex = index;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCurrentTab() {
    if (_currentTabIndex == 0) {
      return _buildGestionTab();
    }
    if (_currentTabIndex == 1) {
      return _buildEventosTab();
    }
    return _buildCuentaTab();
  }

  List<Widget> _buildGestionTab() {
    final modules = widget.controller.modules;
    final inventory = widget.controller.inventoryReport;

    return [
      Text(
        'Gestion del Hato',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
      ),
      const SizedBox(height: 8),
      Text(
        'Accesos rapidos para inventario, reproduccion, leche y control sanitario.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 14),
      for (final module in modules)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModuleCard(
            module: module,
            onTap: () {
              final repository = AppScope.of(context).moduleRecordsRepository;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ModuleRecordsPage(
                    authController: widget.authController,
                    repository: repository,
                    pageTitle: module.title,
                    resourcePath: module.resourcePath,
                  ),
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventario del hato',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Total animales: ${inventory.totalAnimales}'),
              const SizedBox(height: 8),
              Text('Por estado: ${_mapToInline(inventory.porEstado)}'),
              Text('Por raza: ${_mapToInline(inventory.porRaza)}'),
              Text('Por sexo: ${_mapToInline(inventory.porSexo)}'),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildEventosTab() {
    final kpis = widget.controller.kpis;
    final hasSummaryData = widget.controller.summary != null;
    final partoAlerts = widget.controller.alertsProximoParto;
    final retiroAlerts = widget.controller.alertsRetiroActivo;
    final partos30 = widget.controller.partosProyectados30;
    final produccionAnimal = widget.controller.produccionPorAnimalMes;

    return [
      Text(
        'Eventos y Alertas',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
      ),
      const SizedBox(height: 8),
      Text(
        'Seguimiento de partos, retiros farmacos y tendencias de produccion.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 14),
      if (hasSummaryData)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen rapido', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in kpis)
                      KpiTile(label: item.label, value: item.value),
                  ],
                ),
              ],
            ),
          ),
        )
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resumen rapido', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Aun no hay datos de resumen. Verifica backend/sincronizacion y vuelve a intentar.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      if (partoAlerts.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Animales proximos a parir (15 dias)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final alert in partoAlerts)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.notification_important_outlined,
                      color: Colors.orange,
                    ),
                    title: Text('Vaca ${alert.identificador}'),
                    subtitle: Text(
                      'Parto estimado: ${alert.fechaEstimadaParto} • Faltan ${alert.diasRestantes} dias',
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (retiroAlerts.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Retiro farmacologico activo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final alert in retiroAlerts)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.deepOrange,
                    ),
                    title: Text('Vaca ${alert.identificador} • ${alert.producto}'),
                    subtitle: Text(
                      'Fin retiro: ${alert.fechaFinRetiro} • Faltan ${alert.diasRestantes} dias',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      if (partos30.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partos proyectados (30 dias)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final alert in partos30)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_available_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text('Vaca ${alert.identificador}'),
                    subtitle: Text(
                      'Parto estimado: ${alert.fechaEstimadaParto} • ${alert.diasRestantes} dias',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      if (widget.controller.tendencia7Dias.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tendencia de produccion (7 dias)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                _TrendBars(points: widget.controller.tendencia7Dias),
              ],
            ),
          ),
        ),
      ],
      if (widget.controller.tendencia30Dias.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tendencia de produccion (30 dias)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                _TrendBars(points: widget.controller.tendencia30Dias),
              ],
            ),
          ),
        ),
      ],
      if (produccionAnimal.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Produccion por animal (mes)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final row in produccionAnimal)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Vaca ${row.identificador}'),
                    subtitle: Text(
                      'Total: ${row.totalLitros.toStringAsFixed(1)} L • Promedio diario: ${row.promedioDiarioMes.toStringAsFixed(2)}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      if (partoAlerts.isEmpty &&
          retiroAlerts.isEmpty &&
          partos30.isEmpty &&
          widget.controller.tendencia7Dias.isEmpty &&
          widget.controller.tendencia30Dias.isEmpty &&
          produccionAnimal.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No hay eventos para mostrar todavia. Registra actividad en modulos para ver alertas y tendencias.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildCuentaTab() {
    return [
      Text(
        'Cuenta',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
      ),
      const SizedBox(height: 8),
      Text(
        'Gestiona finca activa, sincronizacion y sesion del usuario.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountRow(
                icon: Icons.person_outline,
                label: 'Usuario',
                value: widget.authController.session?.displayName ?? 'Ganadero',
              ),
              const SizedBox(height: 12),
              _AccountRow(
                icon: Icons.cottage_outlined,
                label: 'Finca activa',
                value: widget.controller.farmName,
              ),
              const SizedBox(height: 12),
              _AccountRow(
                icon: Icons.cloud_sync_outlined,
                label: 'Estado red',
                value: widget.controller.isOnline ? 'Online' : 'Offline',
              ),
              const SizedBox(height: 12),
              _AccountRow(
                icon: Icons.pending_actions_outlined,
                label: 'Acciones pendientes',
                value: '${widget.controller.pendingActions}',
              ),
              if (widget.controller.lastSyncAt != null) ...[
                const SizedBox(height: 12),
                _AccountRow(
                  icon: Icons.schedule,
                  label: 'Ultima sincronizacion',
                  value: _shortDate(widget.controller.lastSyncAt!),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.controller.isSyncing
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final message = await widget.controller.syncNow();
                          if (!mounted) {
                            return;
                          }
                          messenger.showSnackBar(SnackBar(content: Text(message)));
                        },
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Sincronizar ahora'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final action = await _showFarmSelectorDialog(
                      context,
                      farms: widget.controller.farms,
                      currentFarmId: widget.controller.currentFarmId,
                    );
                    if (action == null) {
                      return;
                    }

                    try {
                      if (action.type == _FarmDialogActionType.select) {
                        await widget.controller.selectFarm(action.value);
                      } else {
                        await widget.controller.createFarm(action.value);
                        await widget.controller.updateFarmName(action.value);
                      }

                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Finca actualizada.')),
                      );
                    } catch (_) {
                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo actualizar la finca.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Gestionar fincas'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await widget.authController.signOut();
                    if (!mounted) {
                      return;
                    }
                    navigator.pushReplacementNamed(AppRoutes.login);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesion'),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  String _mapToInline(Map<String, int> map) {
    if (map.isEmpty) {
      return '-';
    }
    return map.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
  }

  String _shortDate(String rawDate) {
    if (rawDate.length >= 16) {
      return rawDate.substring(0, 16).replaceFirst('T', ' ');
    }
    return rawDate;
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.userName,
    required this.farmName,
    required this.isOnline,
    required this.pendingActions,
    required this.isSyncing,
    required this.onSync,
  });

  final String userName;
  final String farmName;
  final bool isOnline;
  final int pendingActions;
  final bool isSyncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bienvenido a tu panel',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              IconButton(
                onPressed: isSyncing ? null : onSync,
                color: Colors.white,
                icon: isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
              ),
            ],
          ),
          Text(
            userName,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            farmName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: isOnline ? 'Online' : 'Offline',
                backgroundColor: isOnline
                    ? Colors.green.withValues(alpha: 0.22)
                    : Colors.orange.withValues(alpha: 0.22),
              ),
              _StatusChip(
                label: 'Pendientes: $pendingActions',
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textMain,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (icon: Icons.apps_rounded, label: 'Gestion'),
      (icon: Icons.event_note_rounded, label: 'Evento'),
      (icon: Icons.person_rounded, label: 'Cuenta'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    gradient: currentIndex == i ? AppColors.heroGradient : null,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            items[i].icon,
                            color: currentIndex == i
                                ? Colors.white
                                : AppColors.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items[i].label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: currentIndex == i
                                      ? Colors.white
                                      : AppColors.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.appGradient),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -50,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            top: 180,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (max, p) => p.litros > max ? p.litros : max,
    );
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    final limited = points.length <= 12
        ? points
        : points.sublist(points.length - 12, points.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final point in limited)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 60 * (point.litros / safeMax),
                    constraints: const BoxConstraints(minHeight: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.fecha.length >= 10
                        ? point.fecha.substring(5, 10)
                        : point.fecha,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

enum _FarmDialogActionType { select, create }

class _FarmDialogAction {
  const _FarmDialogAction({required this.type, required this.value});

  final _FarmDialogActionType type;
  final String value;
}

Future<_FarmDialogAction?> _showFarmSelectorDialog(
  BuildContext context, {
  required List<Farm> farms,
  required String currentFarmId,
}) {
  String selectedFarmId = currentFarmId;
  final createController = TextEditingController();

  return showDialog<_FarmDialogAction>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Gestionar fincas'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedFarmId.isEmpty ? null : selectedFarmId,
                  isExpanded: true,
                  items: farms
                      .map(
                        (farm) => DropdownMenuItem(
                          value: farm.id,
                          child: Text(farm.nombre),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Finca actual'),
                  onChanged: (value) {
                    setState(() {
                      selectedFarmId = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: createController,
                  decoration: const InputDecoration(
                    labelText: 'Nueva finca',
                    hintText: 'Ej: La Esperanza',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: selectedFarmId.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      _FarmDialogAction(
                        type: _FarmDialogActionType.select,
                        value: selectedFarmId,
                      ),
                    ),
              child: const Text('Seleccionar'),
            ),
            FilledButton(
              onPressed: () {
                final name = createController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  _FarmDialogAction(
                    type: _FarmDialogActionType.create,
                    value: name,
                  ),
                );
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    ),
  );
}
