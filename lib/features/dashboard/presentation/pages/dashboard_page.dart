import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/di/app_scope.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../module_records/presentation/pages/module_records_page.dart';
import '../../domain/dashboard_summary.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/kpi_tile.dart';
import '../widgets/module_card.dart';
import '../../../user_profile/domain/farm.dart';

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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final modules = widget.controller.modules;
            final kpis = widget.controller.kpis;
            final partoAlerts = widget.controller.alertsProximoParto;
            final retiroAlerts = widget.controller.alertsRetiroActivo;
            final partos30 = widget.controller.partosProyectados30;
            final inventory = widget.controller.inventoryReport;
            final produccionAnimal = widget.controller.produccionPorAnimalMes;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    _Header(
                      isSyncing: widget.controller.isSyncing,
                      userName:
                          widget.authController.session?.displayName ??
                          'Ganadero',
                      farmName: widget.controller.farmName,
                      isOnline: widget.controller.isOnline,
                      pendingActions: widget.controller.pendingActions,
                      lastSyncAt: widget.controller.lastSyncAt,
                      onEditFarm: () async {
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
                            await widget.controller.updateFarmName(
                              action.value,
                            );
                          }

                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Finca actualizada.')),
                          );
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo actualizar la finca.'),
                            ),
                          );
                        }
                      },
                      onSync: () async {
                        final message = await widget.controller.syncNow();
                        if (!context.mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      },
                      onLogout: () async {
                        await widget.authController.signOut();
                        if (!context.mounted) {
                          return;
                        }

                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.login);
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Modulos de Gestion',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu trabajo diario en campo.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.deep.withValues(alpha: 0.75),
                      ),
                    ),
                    if (widget.controller.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (widget.controller.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          widget.controller.errorMessage!,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.red.shade700),
                        ),
                      ),
                    const SizedBox(height: 12),
                    for (final module in modules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ModuleCard(
                          module: module,
                          onTap: () {
                            final repository = AppScope.of(
                              context,
                            ).moduleRecordsRepository;
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
                    if (partoAlerts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
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
                    ],
                    if (retiroAlerts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
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
                                  title: Text(
                                    'Vaca ${alert.identificador} • ${alert.producto}',
                                  ),
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
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reporte de partos proyectados (30 dias)',
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
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen Rapido',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
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
                    ),
                    if (widget.controller.tendencia7Dias.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
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
                              _TrendBars(
                                points: widget.controller.tendencia7Dias,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (widget.controller.tendencia30Dias.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
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
                              _TrendBars(
                                points: widget.controller.tendencia30Dias,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reporte inventario del hato',
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
                    if (produccionAnimal.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _mapToInline(Map<String, int> map) {
    if (map.isEmpty) {
      return '-';
    }
    return map.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
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

class _Header extends StatelessWidget {
  const _Header({
    required this.onLogout,
    required this.onSync,
    required this.onEditFarm,
    required this.userName,
    required this.farmName,
    required this.isSyncing,
    required this.isOnline,
    required this.pendingActions,
    required this.lastSyncAt,
  });

  final VoidCallback onLogout;
  final VoidCallback onSync;
  final VoidCallback onEditFarm;
  final String userName;
  final String farmName;
  final bool isSyncing;
  final bool isOnline;
  final int pendingActions;
  final String? lastSyncAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bienvenido',
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
              IconButton(
                onPressed: onLogout,
                color: Colors.white,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          Text(
            userName,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: isOnline ? 'Online' : 'Offline',
                backgroundColor: isOnline
                    ? Colors.green.withValues(alpha: 0.18)
                    : Colors.orange.withValues(alpha: 0.18),
              ),
              _StatusChip(
                label: 'Pendientes: $pendingActions',
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
              if (lastSyncAt != null)
                _StatusChip(
                  label: 'Ult. sync: ${_shortDate(lastSyncAt!)}',
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.cottage_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    farmName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEditFarm,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String rawDate) {
    if (rawDate.length >= 16) {
      return rawDate.substring(0, 16).replaceFirst('T', ' ');
    }
    return rawDate;
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
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
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
