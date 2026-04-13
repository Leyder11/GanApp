import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/di/app_scope.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/module_records_repository.dart';
import '../../domain/module_record.dart';
import 'cow_gps_page.dart';

class ModuleRecordsPage extends StatefulWidget {
  const ModuleRecordsPage({
    super.key,
    required this.authController,
    required this.repository,
    required this.pageTitle,
    required this.resourcePath,
  });

  final AuthController authController;
  final ModuleRecordsRepository repository;
  final String pageTitle;
  final String resourcePath;

  @override
  State<ModuleRecordsPage> createState() => _ModuleRecordsPageState();
}

class _ModuleRecordsPageState extends State<ModuleRecordsPage> {
  bool _isLoading = true;
  String? _error;
  List<ModuleRecord> _records = const [];
  bool _isOnline = false;
  int _pendingActions = 0;
  String _searchQuery = '';
  String _estadoFilter = 'todos';
  String _sexoFilter = 'todos';
  String _razaFilter = 'todos';
  String _reproVacaFilter = '';
  String _milkVacaFilter = '';
  String _milkFrom = '';
  String _milkTo = '';
  int _milkAverageDays = 7;
  String _sanitaryVacaFilter = '';
  List<_CowOption> _cowFilterOptions = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _refreshSyncStatus();
  }

  Future<void> _refreshSyncStatus() async {
    final syncService = AppScope.of(context).dashboardController.syncService;
    final online = await syncService.isServerReachable();
    final pending = await syncService.pendingActionsCount();

    if (!mounted) {
      return;
    }

    setState(() {
      _isOnline = online;
      _pendingActions = pending;
    });
  }

  Future<void> _load() async {
    final token = widget.authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Sesion no valida.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await widget.repository.loadRecords(
        resourcePath: widget.resourcePath,
        accessToken: token,
      );

      final cowFilterOptions = _needsCowSelection(widget.resourcePath)
          ? await _loadCowOptions(token)
          : const <_CowOption>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _cowFilterOptions = cowFilterOptions;

        if (_milkVacaFilter.isNotEmpty &&
            !_cowFilterOptions.any((cow) => cow.id == _milkVacaFilter)) {
          _milkVacaFilter = '';
        }
        if (_reproVacaFilter.isNotEmpty &&
            !_cowFilterOptions.any((cow) => cow.id == _reproVacaFilter)) {
          _reproVacaFilter = '';
        }
        if (_sanitaryVacaFilter.isNotEmpty &&
            !_cowFilterOptions.any((cow) => cow.id == _sanitaryVacaFilter)) {
          _sanitaryVacaFilter = '';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudieron cargar datos del modulo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createRecord() async {
    final token = widget.authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final cowOptions = _needsCowSelection(widget.resourcePath)
        ? await _loadCowOptions(token)
        : const <_CowOption>[];

    if (_needsCowSelection(widget.resourcePath) && cowOptions.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero debes registrar al menos una vaca en Inventario de ganado.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordDialog(
        resourcePath: widget.resourcePath,
        cowOptions: cowOptions,
      ),
    );

    if (payload == null) {
      return;
    }

    try {
      await widget.repository.createRecord(
        resourcePath: widget.resourcePath,
        accessToken: token,
        payload: payload,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear: $error')),
      );
      return;
    }
    await _refreshSyncStatus();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro creado (online u offline).')),
    );
    await _load();
  }

  Future<void> _editRecord(ModuleRecord record) async {
    final token = widget.authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final cowOptions = _needsCowSelection(widget.resourcePath)
        ? await _loadCowOptions(token)
        : const <_CowOption>[];

    if (_needsCowSelection(widget.resourcePath) && cowOptions.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay vacas registradas para asociar este modulo.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordDialog(
        resourcePath: widget.resourcePath,
        initialData: record.rawData,
        cowOptions: cowOptions,
      ),
    );

    if (payload == null) {
      return;
    }

    try {
      await widget.repository.updateRecord(
        resourcePath: widget.resourcePath,
        accessToken: token,
        id: record.id,
        payload: payload,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $error')),
      );
      return;
    }
    await _refreshSyncStatus();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro actualizado (online u offline).')),
    );
    await _load();
  }

  Future<void> _deleteRecord(ModuleRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('Seguro que deseas eliminar ${record.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final token = widget.authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    await widget.repository.deleteRecord(
      resourcePath: widget.resourcePath,
      accessToken: token,
      id: record.id,
    );
    await _refreshSyncStatus();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro eliminado (online u offline).')),
    );
    await _load();
  }

  Future<void> _showAnimalFullRecord(ModuleRecord record) async {
    final token = widget.authController.session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final full = await widget.repository.getAnimalFullRecord(
        accessToken: token,
        animalId: record.id,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (_) => _AnimalFullRecordDialog(data: full),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la ficha completa.')),
      );
    }
  }

  Future<void> _openCowGps(ModuleRecord record) async {
    final identificador =
        record.rawData['identificador']?.toString() ?? record.id;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CowGpsPage(
          cowId: record.id,
          cowLabel: identificador,
        ),
      ),
    );
  }

  bool _needsCowSelection(String resourcePath) {
    return resourcePath == 'prod-leche' ||
        resourcePath == 'eventos-reproductivos' ||
        resourcePath == 'eventos-veterinarios';
  }

  Future<List<_CowOption>> _loadCowOptions(String token) async {
    try {
      final cows = await widget.repository.loadRecords(
        resourcePath: 'vacas',
        accessToken: token,
      );

      return cows.map((record) {
        final raw = record.rawData;
        final sexoRaw = (raw['sexo']?.toString() ?? '').toLowerCase();
        final sexo = sexoRaw == 'f' ? 'hembra' : sexoRaw == 'm' ? 'macho' : sexoRaw;
        return _CowOption(
          id: record.id,
          identificador: raw['identificador']?.toString() ?? record.id,
          sexo: sexo,
        );
      }).toList()
        ..sort((a, b) => a.identificador.toLowerCase().compareTo(b.identificador.toLowerCase()));
    } catch (_) {
      return const <_CowOption>[];
    }
  }

  List<DropdownMenuItem<String>> _cowFilterDropdownItems() {
    final options = _cowFilterOptions
        .map(
          (cow) => DropdownMenuItem<String>(
            value: cow.id,
            child: Text('${cow.identificador} (${cow.sexo})'),
          ),
        )
        .toList(growable: false);

    return [
      const DropdownMenuItem<String>(value: '', child: Text('Todas las vacas')),
      ...options,
    ];
  }

  Widget _buildCowFilterDropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final items = _cowFilterDropdownItems();

    if (_cowFilterOptions.isEmpty) {
      return TextField(
        onChanged: (raw) {
          onChanged(raw.trim());
        },
        decoration: InputDecoration(
          labelText: '$label (ID)',
          prefixIcon: const Icon(Icons.search),
        ),
      );
    }

    final hasValue = items.any((item) => item.value == value);

    return DropdownButtonFormField<String>(
      initialValue: hasValue ? value : '',
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.pets_outlined),
      ),
      items: items,
      onChanged: (selected) {
        onChanged(selected ?? '');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecords = _filteredRecords();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? Colors.green.withValues(alpha: 0.18)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_isOnline ? 'Online' : 'Offline'} • Pend: $_pendingActions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.deep,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRecord,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.resourcePath == 'vacas') ...[
                    _InventorySearchAndFilters(
                      query: _searchQuery,
                      estado: _estadoFilter,
                      sexo: _sexoFilter,
                      raza: _razaFilter,
                      razas: _availableRazas(),
                      onQueryChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      onEstadoChanged: (value) {
                        setState(() {
                          _estadoFilter = value;
                        });
                      },
                      onSexoChanged: (value) {
                        setState(() {
                          _sexoFilter = value;
                        });
                      },
                      onRazaChanged: (value) {
                        setState(() {
                          _razaFilter = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.resourcePath == 'eventos-reproductivos') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildCowFilterDropdown(
                          label: 'Filtrar historial por vaca',
                          value: _reproVacaFilter,
                          onChanged: (selected) {
                            setState(() {
                              _reproVacaFilter = selected;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.resourcePath == 'prod-leche') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _buildCowFilterDropdown(
                              label: 'Filtrar por vaca',
                              value: _milkVacaFilter,
                              onChanged: (selected) {
                                setState(() {
                                  _milkVacaFilter = selected;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _milkFrom = value.trim();
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Desde (YYYY-MM-DD)',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _milkTo = value.trim();
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Hasta (YYYY-MM-DD)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              initialValue: _milkAverageDays,
                              decoration: const InputDecoration(
                                labelText: 'Periodo promedio por animal',
                              ),
                              items: const [7, 30, 90]
                                  .map(
                                    (d) => DropdownMenuItem<int>(
                                      value: d,
                                      child: Text('Ultimos $d dias'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _milkAverageDays = value;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MilkAveragePanel(
                      records: _records,
                      days: _milkAverageDays,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.resourcePath == 'eventos-veterinarios') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildCowFilterDropdown(
                          label: 'Filtrar historial sanitario por vaca',
                          value: _sanitaryVacaFilter,
                          onChanged: (selected) {
                            setState(() {
                              _sanitaryVacaFilter = selected;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (visibleRecords.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'No hay registros para los filtros actuales.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  for (final item in visibleRecords) ...[
                    Card(
                      child: ListTile(
                        onTap: () => _editRecord(item),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.resourcePath == 'vacas')
                              IconButton(
                                tooltip: 'Ver GPS',
                                icon: const Icon(Icons.map_outlined),
                                onPressed: () => _openCowGps(item),
                              ),
                            if (widget.resourcePath == 'vacas')
                              IconButton(
                                tooltip: 'Ficha completa',
                                icon: const Icon(Icons.receipt_long_outlined),
                                onPressed: () => _showAnimalFullRecord(item),
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteRecord(item),
                            ),
                          ],
                        ),
                        title: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.deep,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.subtitle),
                              const SizedBox(height: 4),
                              Text(item.footnote),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }

  List<ModuleRecord> _filteredRecords() {
    if (widget.resourcePath == 'prod-leche') {
      return _records.where((record) {
        final vacaId = record.rawData['vacaId']?.toString() ?? '';
        final fecha =
            record.rawData['fecha']?.toString().substring(0, 10) ?? '';

        if (_milkVacaFilter.isNotEmpty && vacaId != _milkVacaFilter) {
          return false;
        }
        if (_milkFrom.isNotEmpty && fecha.compareTo(_milkFrom) < 0) {
          return false;
        }
        if (_milkTo.isNotEmpty && fecha.compareTo(_milkTo) > 0) {
          return false;
        }

        return true;
      }).toList();
    }

    if (widget.resourcePath == 'eventos-veterinarios') {
      if (_sanitaryVacaFilter.isEmpty) {
        return _records;
      }
      return _records.where((record) {
        final vacaId = record.rawData['vacaId']?.toString() ?? '';
        return vacaId == _sanitaryVacaFilter;
      }).toList();
    }

    if (widget.resourcePath == 'eventos-reproductivos') {
      if (_reproVacaFilter.isEmpty) {
        return _records;
      }

      return _records.where((record) {
        final vacaId = record.rawData['vacaId']?.toString() ?? '';
        return vacaId == _reproVacaFilter;
      }).toList();
    }

    if (widget.resourcePath != 'vacas') {
      return _records;
    }

    final q = _searchQuery.trim().toLowerCase();

    return _records.where((record) {
      final raw = record.rawData;
      final identificador =
          raw['identificador']?.toString().toLowerCase() ?? '';
      final raza = raw['raza']?.toString().toLowerCase() ?? '';
      final sexoRaw = raw['sexo']?.toString().toLowerCase() ?? '';
      final sexo = sexoRaw == 'm'
          ? 'macho'
          : sexoRaw == 'f'
          ? 'hembra'
          : sexoRaw;
      final estado = raw['estado']?.toString().toLowerCase() ?? '';

      final searchOk =
          q.isEmpty || identificador.contains(q) || raza.contains(q);
      final estadoOk = _estadoFilter == 'todos' || estado == _estadoFilter;
      final sexoOk = _sexoFilter == 'todos' || sexo == _sexoFilter;
      final razaOk = _razaFilter == 'todos' || raza == _razaFilter;

      return searchOk && estadoOk && sexoOk && razaOk;
    }).toList();
  }

  List<String> _availableRazas() {
    final set = <String>{};
    for (final record in _records) {
      final raza = record.rawData['raza']?.toString().trim().toLowerCase();
      if (raza != null && raza.isNotEmpty) {
        set.add(raza);
      }
    }
    final list = set.toList()..sort();
    return list;
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({
    required this.resourcePath,
    required this.cowOptions,
    this.initialData,
  });

  final String resourcePath;
  final List<_CowOption> cowOptions;
  final Map<String, dynamic>? initialData;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _field1;
  late final TextEditingController _field2;
  late final TextEditingController _field3;
  late final TextEditingController _field4;
  late final TextEditingController _field5;
  bool _singleDailyMilk = false;
  String _vacaSexo = 'hembra';
  String _vacaEstado = 'activa';
  String _reproTipoEvento = 'celo';
  String _reproResultado = 'pendiente';
  String _vetCategoria = 'observacion';
  String? _selectedCowId;

  @override
  void initState() {
    super.initState();
    _field1 = TextEditingController(text: _initial('field1'));
    _field2 = TextEditingController(text: _initial('field2'));
    _field3 = TextEditingController(text: _initial('field3'));
    _field4 = TextEditingController(text: _initial('field4'));
    _field5 = TextEditingController(text: _initial('field5'));

    _hydrateFromInitial();
  }

  void _hydrateFromInitial() {
    final data = widget.initialData;
    if (data == null) {
      return;
    }

    switch (widget.resourcePath) {
      case 'vacas':
        _field1.text = data['identificador']?.toString() ?? '';
        _field2.text = data['raza']?.toString() ?? '';
        _vacaSexo = data['sexo']?.toString() ?? 'hembra';
        _vacaEstado = data['estado']?.toString() ?? 'activa';
        _field5.text = data['fechaNacimiento']?.toString() ?? '';
        break;
      case 'eventos-reproductivos':
        _field1.text = data['vacaId']?.toString() ?? '';
        _selectedCowId = _field1.text.trim().isEmpty ? null : _field1.text.trim();
        _reproTipoEvento = data['tipoEvento']?.toString() ?? 'celo';
        _field3.text = data['fecha']?.toString() ?? '';
        final tipoEvento = _reproTipoEvento;
        if (tipoEvento == 'diagnostico') {
          _reproResultado = data['resultadoDiagnostico']?.toString() ?? 'pendiente';
          _field4.clear();
        } else if (tipoEvento == 'parto') {
          _field4.text = data['criaId']?.toString() ?? '';
        } else {
          _field4.text = data['toroUtilizado']?.toString() ?? data['observaciones']?.toString() ?? '';
        }
        break;
      case 'prod-leche':
        _field1.text = data['vacaId']?.toString() ?? '';
        _selectedCowId = _field1.text.trim().isEmpty ? null : _field1.text.trim();
        _field2.text = data['fecha']?.toString() ?? '';
        _field3.text = data['litrosManana']?.toString() ?? '';
        _field4.text = data['litrosTarde']?.toString() ?? '';
        _singleDailyMilk = (double.tryParse(_field4.text) ?? 0) == 0;
        break;
      case 'eventos-veterinarios':
        _field1.text = data['vacaId']?.toString() ?? '';
        _selectedCowId = _field1.text.trim().isEmpty ? null : _field1.text.trim();
        _vetCategoria = data['categoria']?.toString() ?? 'observacion';
        _field2.text = data['producto']?.toString() ?? '';
        _field3.text = data['dosis']?.toString() ?? '';
        _field4.text = data['diasRetiro']?.toString() ?? '0';
        _field5.text = data['fecha']?.toString() ?? '';
        break;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(controller.text.trim());
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(2010),
      lastDate: DateTime(now.year + 2),
    );
    if (selected == null) {
      return;
    }
    controller.text = selected.toIso8601String().split('T').first;
  }

  String _initial(String key) {
    return widget.initialData?[key]?.toString() ?? '';
  }

  @override
  void dispose() {
    _field1.dispose();
    _field2.dispose();
    _field3.dispose();
    _field4.dispose();
    _field5.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    final today = DateTime.now().toIso8601String().split('T').first;

    switch (widget.resourcePath) {
      case 'vacas':
        return {
          'identificador': _field1.text.trim(),
          'raza': _field2.text.trim(),
          'sexo': _vacaSexo,
          'estado': _vacaEstado,
          'fechaNacimiento': _field5.text.trim().isEmpty
              ? today
              : _field5.text.trim(),
          'origen': 'finca',
        };
      case 'eventos-reproductivos':
        final tipoEvento = _reproTipoEvento;

        final payload = {
          'vacaId': _field1.text.trim(),
          'tipoEvento': tipoEvento,
          'fecha': _field3.text.trim().isEmpty ? today : _field3.text.trim(),
        };

        if (tipoEvento == 'diagnostico') {
          payload['resultadoDiagnostico'] = _reproResultado;
        } else if (tipoEvento == 'parto') {
          payload['criaId'] = _field4.text.trim();
        } else if (tipoEvento == 'servicio' || tipoEvento == 'inseminacion') {
          payload['toroUtilizado'] = _field4.text.trim();
          payload['tipoServicio'] = tipoEvento == 'inseminacion'
              ? 'ia'
              : 'natural';
        } else if (tipoEvento == 'aborto' && _field4.text.trim().isNotEmpty) {
          payload['observaciones'] = _field4.text.trim();
        }

        return payload;
      case 'prod-leche':
        final manana = double.tryParse(_field3.text.trim()) ?? 0;
        final tarde = _singleDailyMilk
            ? 0
            : (double.tryParse(_field4.text.trim()) ?? 0);
        return {
          'vacaId': _field1.text.trim(),
          'fecha': _field2.text.trim().isEmpty ? today : _field2.text.trim(),
          'litrosManana': manana,
          'litrosTarde': tarde,
          'total': manana + tarde,
        };
      case 'eventos-veterinarios':
        return {
          'vacaId': _field1.text.trim(),
          'categoria': _vetCategoria,
          'producto': _field2.text.trim(),
          'tipoVacuna': _field2.text.trim(),
          'responsable': '',
          'diagnostico': '',
          'medicamento': _field2.text.trim(),
          'duracionTratamientoDias': 0,
          'dosis': _field3.text.trim(),
          'diasRetiro': int.tryParse(_field4.text.trim()) ?? 0,
          'fecha': _field5.text.trim().isEmpty ? today : _field5.text.trim(),
          'tipoEventoId': _vetCategoria,
        };
      default:
        return {'nombre': _field1.text.trim()};
    }
  }

  bool get _requiresFemaleCow {
    return widget.resourcePath == 'prod-leche' ||
        widget.resourcePath == 'eventos-reproductivos';
  }

  List<_CowOption> get _eligibleCowOptions {
    if (!_requiresFemaleCow) {
      return widget.cowOptions;
    }
    return widget.cowOptions
        .where((cow) => cow.sexo == 'hembra')
        .toList(growable: false);
  }

  List<DropdownMenuItem<String>> _cowDropdownItems() {
    final eligible = _eligibleCowOptions;
    final items = eligible
        .map(
          (cow) => DropdownMenuItem<String>(
            value: cow.id,
            child: Text('${cow.identificador} (${cow.sexo})'),
          ),
        )
        .toList(growable: true);

    if (_selectedCowId != null &&
        _selectedCowId!.isNotEmpty &&
        !eligible.any((cow) => cow.id == _selectedCowId)) {
      items.insert(
        0,
        DropdownMenuItem<String>(
          value: _selectedCowId,
          child: Text('ID ${_selectedCowId!} (sin catalogar)'),
        ),
      );
    }

    return items;
  }

  Widget _cowSelectorField() {
    final items = _cowDropdownItems();

    final noRegisteredCows = widget.cowOptions.isEmpty;
    final noEligibleCows = !noRegisteredCows && items.isEmpty;

    final hasSelected = _selectedCowId != null && _selectedCowId!.isNotEmpty;
    final hasItem = hasSelected && items.any((item) => item.value == _selectedCowId);

    return DropdownButtonFormField<String>(
      initialValue: hasItem ? _selectedCowId : null,
      decoration: InputDecoration(
        labelText: _requiresFemaleCow
            ? 'Vaca (solo hembras)'
            : 'Vaca registrada',
        helperText: noRegisteredCows
            ? 'No hay vacas registradas. Crea una en Inventario.'
            : noEligibleCows
            ? 'No hay vacas hembras disponibles para este modulo.'
            : null,
      ),
      items: noRegisteredCows || noEligibleCows ? const [] : items,
      onChanged: noRegisteredCows || noEligibleCows
          ? null
          : (value) {
        setState(() {
          _selectedCowId = value;
          _field1.text = value ?? '';
        });
      },
      validator: (value) {
        if (noRegisteredCows) {
          return 'Registra una vaca primero';
        }
        if (noEligibleCows) {
          return 'No hay vacas validas para seleccionar';
        }
        if (value == null || value.trim().isEmpty) {
          return 'Selecciona una vaca';
        }
        return null;
      },
    );
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => _pickDate(controller),
        ),
      ),
      onTap: () => _pickDate(controller),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Selecciona una fecha';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialData == null ? 'Nuevo registro' : 'Editar registro',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.resourcePath == 'prod-leche') ...[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Registro unico diario'),
                  subtitle: const Text(
                    'Si se activa, Litros tarde se guarda en 0.',
                  ),
                  value: _singleDailyMilk,
                  onChanged: (value) {
                    setState(() {
                      _singleDailyMilk = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (widget.resourcePath == 'vacas') ...[
                TextFormField(
                  controller: _field1,
                  decoration: const InputDecoration(
                    labelText: 'Identificador',
                    hintText: 'BOV-001',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _field2.text.isEmpty ? null : _field2.text,
                  decoration: const InputDecoration(labelText: 'Raza'),
                  items: const [
                    'Holstein',
                    'Jersey',
                    'Normando',
                    'Gyr',
                    'Pardo',
                    'Brahman',
                    'Cruce',
                  ]
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _field2.text = value ?? '';
                    });
                  },
                  validator: (value) => (value == null || value.isEmpty) ? 'Selecciona una raza' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _vacaSexo,
                  decoration: const InputDecoration(labelText: 'Sexo'),
                  items: const [
                    DropdownMenuItem(value: 'hembra', child: Text('Hembra')),
                    DropdownMenuItem(value: 'macho', child: Text('Macho')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _vacaSexo = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _vacaEstado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'activa', child: Text('Activa')),
                    DropdownMenuItem(value: 'seca', child: Text('Seca')),
                    DropdownMenuItem(value: 'vendida', child: Text('Vendida')),
                    DropdownMenuItem(value: 'fallecida', child: Text('Fallecida')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _vacaEstado = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                _dateField(controller: _field5, label: 'Fecha nacimiento'),
              ] else if (widget.resourcePath == 'eventos-reproductivos') ...[
                _cowSelectorField(),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _reproTipoEvento,
                  decoration: const InputDecoration(labelText: 'Tipo evento'),
                  items: const [
                    DropdownMenuItem(value: 'celo', child: Text('Celo')),
                    DropdownMenuItem(value: 'servicio', child: Text('Servicio')),
                    DropdownMenuItem(value: 'inseminacion', child: Text('Inseminacion')),
                    DropdownMenuItem(value: 'diagnostico', child: Text('Diagnostico')),
                    DropdownMenuItem(value: 'parto', child: Text('Parto')),
                    DropdownMenuItem(value: 'aborto', child: Text('Aborto')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _reproTipoEvento = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                _dateField(controller: _field3, label: 'Fecha evento'),
                const SizedBox(height: 10),
                if (_reproTipoEvento == 'diagnostico')
                  DropdownButtonFormField<String>(
                    initialValue: _reproResultado,
                    decoration: const InputDecoration(labelText: 'Resultado diagnostico'),
                    items: const [
                      DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'positivo', child: Text('Positivo')),
                      DropdownMenuItem(value: 'negativo', child: Text('Negativo')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _reproResultado = value;
                        });
                      }
                    },
                  )
                else
                  TextFormField(
                    controller: _field4,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: _reproTipoEvento == 'parto'
                          ? 'ID cria'
                          : _reproTipoEvento == 'aborto'
                          ? 'Observacion breve'
                          : 'Toro o detalle',
                    ),
                  ),
              ] else if (widget.resourcePath == 'eventos-veterinarios') ...[
                _cowSelectorField(),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _vetCategoria,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: const [
                    DropdownMenuItem(value: 'vacunacion', child: Text('Vacunacion')),
                    DropdownMenuItem(value: 'desparasitacion', child: Text('Desparasitacion')),
                    DropdownMenuItem(value: 'tratamiento', child: Text('Tratamiento')),
                    DropdownMenuItem(value: 'observacion', child: Text('Observacion')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _vetCategoria = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _field2,
                  decoration: const InputDecoration(labelText: 'Producto / Medicamento'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _field3,
                  decoration: const InputDecoration(labelText: 'Dosis'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _field4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Dias retiro'),
                ),
                const SizedBox(height: 10),
                _dateField(controller: _field5, label: 'Fecha evento'),
              ] else if (widget.resourcePath == 'prod-leche') ...[
                _cowSelectorField(),
                const SizedBox(height: 10),
                _dateField(controller: _field2, label: 'Fecha'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _field3,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Litros manana o total unico'),
                ),
                const SizedBox(height: 10),
                if (!_singleDailyMilk)
                  TextFormField(
                    controller: _field4,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Litros tarde'),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(_buildPayload());
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CowOption {
  const _CowOption({
    required this.id,
    required this.identificador,
    required this.sexo,
  });

  final String id;
  final String identificador;
  final String sexo;
}

class _InventorySearchAndFilters extends StatelessWidget {
  const _InventorySearchAndFilters({
    required this.query,
    required this.estado,
    required this.sexo,
    required this.raza,
    required this.razas,
    required this.onQueryChanged,
    required this.onEstadoChanged,
    required this.onSexoChanged,
    required this.onRazaChanged,
  });

  final String query;
  final String estado;
  final String sexo;
  final String raza;
  final List<String> razas;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onEstadoChanged;
  final ValueChanged<String> onSexoChanged;
  final ValueChanged<String> onRazaChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'Buscar por identificador o raza',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterDropdown(
                  label: 'Estado',
                  value: estado,
                  options: const [
                    'todos',
                    'activa',
                    'vendida',
                    'fallecida',
                    'seca',
                  ],
                  onChanged: onEstadoChanged,
                ),
                _FilterDropdown(
                  label: 'Sexo',
                  value: sexo,
                  options: const ['todos', 'macho', 'hembra'],
                  onChanged: onSexoChanged,
                ),
                _FilterDropdown(
                  label: 'Raza',
                  value: raza,
                  options: ['todos', ...razas],
                  onChanged: onRazaChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: options
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item[0].toUpperCase() + item.substring(1)),
              ),
            )
            .toList(),
        onChanged: (selected) {
          if (selected != null) {
            onChanged(selected);
          }
        },
      ),
    );
  }
}

class _MilkAveragePanel extends StatelessWidget {
  const _MilkAveragePanel({required this.records, required this.days});

  final List<ModuleRecord> records;
  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));

    final byVaca = <String, double>{};
    for (final record in records) {
      final raw = record.rawData;
      final vacaId = raw['vacaId']?.toString() ?? '';
      if (vacaId.isEmpty) {
        continue;
      }

      final fechaRaw = raw['fecha']?.toString() ?? '';
      final fecha = DateTime.tryParse(fechaRaw);
      if (fecha == null) {
        continue;
      }

      if (fecha.isBefore(DateTime(start.year, start.month, start.day))) {
        continue;
      }

      byVaca[vacaId] =
          (byVaca[vacaId] ?? 0) +
          (double.tryParse(raw['total']?.toString() ?? '0') ?? 0);
    }

    final rows =
        byVaca.entries
            .map((e) => (vacaId: e.key, promedio: e.value / days))
            .toList()
          ..sort((a, b) => b.promedio.compareTo(a.promedio));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Promedio diario por animal ($days dias)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                'Sin datos para el periodo seleccionado.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            for (final row in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Vaca ${row.vacaId}'),
                trailing: Text('${row.promedio.toStringAsFixed(2)} L/dia'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimalFullRecordDialog extends StatefulWidget {
  const _AnimalFullRecordDialog({required this.data});

  final Map<String, dynamic> data;

  @override
  State<_AnimalFullRecordDialog> createState() => _AnimalFullRecordDialogState();
}

class _AnimalFullRecordDialogState extends State<_AnimalFullRecordDialog> {
  static const int _previewLimit = 8;

  bool _showAllRepro = false;
  bool _showAllLeche = false;
  bool _showAllSanitario = false;

  List<Map<String, dynamic>> _toList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  String _fmtDate(Object? raw) {
    final value = raw?.toString() ?? '';
    if (value.length >= 10) {
      return value.substring(0, 10);
    }
    return value.isEmpty ? '-' : value;
  }

  Widget _historySection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> rows,
    required bool showAll,
    required VoidCallback onToggle,
    required List<Widget> Function(Map<String, dynamic>) rowBuilder,
  }) {
    final visibleRows = showAll ? rows : rows.take(_previewLimit).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.deep),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${rows.length} reg.'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                'Sin registros.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...visibleRows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rowBuilder(row),
                    ),
                  ),
                );
              }),
            if (rows.length > _previewLimit)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    showAll ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text(showAll ? 'Ver menos' : 'Ver todo'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(String value) {
    final v = value.toLowerCase();
    if (v.contains('parto') || v.contains('servicio') || v.contains('insemi')) {
      return Colors.pink.shade100;
    }
    if (v.contains('diagnostico') || v.contains('observ')) {
      return Colors.amber.shade100;
    }
    if (v.contains('vacun') || v.contains('despar')) {
      return Colors.green.shade100;
    }
    if (v.contains('trat')) {
      return Colors.blue.shade100;
    }
    return Colors.grey.shade200;
  }

  String _summaryText() {
    final vaca = (widget.data['vaca'] as Map<String, dynamic>?) ?? {};
    final repro = _toList(widget.data['historialReproductivo']);
    final leche = _toList(widget.data['historialLeche']);
    final sanitario = _toList(widget.data['historialSanitario']);

    final buffer = StringBuffer();
    buffer.writeln('Ficha del animal');
    buffer.writeln('ID: ${vaca['identificador'] ?? '-'}');
    buffer.writeln('Raza: ${vaca['raza'] ?? '-'}');
    buffer.writeln('Sexo: ${vaca['sexo'] ?? '-'}');
    buffer.writeln('Estado: ${vaca['estado'] ?? '-'}');
    buffer.writeln('Nacimiento: ${_fmtDate(vaca['fechaNacimiento'])}');
    buffer.writeln('');
    buffer.writeln('Resumen');
    buffer.writeln('Reproductivo: ${repro.length} registros');
    buffer.writeln('Leche: ${leche.length} registros');
    buffer.writeln('Sanitario: ${sanitario.length} registros');
    return buffer.toString();
  }

  Future<void> _shareSummary(BuildContext context) async {
    final text = _summaryText();
    Share.share(text, subject: 'Ficha del animal');
  }

  Future<Uint8List> _buildPdfBytes() async {
    final vaca = (widget.data['vaca'] as Map<String, dynamic>?) ?? {};
    final repro = _toList(widget.data['historialReproductivo']);
    final leche = _toList(widget.data['historialLeche']);
    final sanitario = _toList(widget.data['historialSanitario']);
    final summary = _summaryText();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(
            'Ficha completa del animal',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('ID: ${vaca['identificador'] ?? '-'}'),
          pw.Text('Raza: ${vaca['raza'] ?? '-'}'),
          pw.Text('Sexo: ${vaca['sexo'] ?? '-'}'),
          pw.Text('Estado: ${vaca['estado'] ?? '-'}'),
          pw.Text('Nacimiento: ${_fmtDate(vaca['fechaNacimiento'])}'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Resumen rapido',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(summary),
          pw.SizedBox(height: 12),
          pw.Text(
            'Ultimos eventos reproductivos',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...repro.take(10).map(
                (e) => pw.Text(
                  '- ${_fmtDate(e['fecha'])} | ${e['tipoEvento'] ?? '-'} | ${e['resultadoDiagnostico'] ?? e['toroUtilizado'] ?? e['criaId'] ?? e['observaciones'] ?? '-'}',
                ),
              ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Ultimos registros de leche',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...leche.take(10).map(
                (e) => pw.Text(
                  '- ${_fmtDate(e['fecha'])} | M:${e['litrosManana'] ?? 0} | T:${e['litrosTarde'] ?? 0} | Total:${e['total'] ?? 0}',
                ),
              ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Ultimos eventos sanitarios',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          ...sanitario.take(10).map(
                (e) => pw.Text(
                  '- ${_fmtDate(e['fecha'])} | ${e['categoria'] ?? '-'} | ${e['producto'] ?? '-'} | Retiro:${e['diasRetiro'] ?? 0}',
                ),
              ),
        ],
      ),
    );

    return doc.save();
  }

  Future<File> _savePdfLocally(Uint8List bytes) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${docsDir.path}/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    final vaca = (widget.data['vaca'] as Map<String, dynamic>?) ?? {};
    final id =
        vaca['identificador']?.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_') ??
        'animal';
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${reportsDir.path}/ficha_${id}_$stamp.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _exportPdf(BuildContext context) async {
    final bytes = await _buildPdfBytes();
    final file = await _savePdfLocally(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Ficha completa del animal',
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF guardado localmente en: ${file.path}')),
    );
  }

  Future<void> _printPdf(BuildContext context) async {
    final bytes = await _buildPdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF enviado a impresion.')),
    );
  }

  Future<void> _copySummary(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _summaryText()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumen copiado al portapapeles.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaca = (widget.data['vaca'] as Map<String, dynamic>?) ?? {};
    final repro = _toList(widget.data['historialReproductivo']);
    final leche = _toList(widget.data['historialLeche']);
    final sanitario = _toList(widget.data['historialSanitario']);

    return AlertDialog(
      title: const Text('Ficha completa del animal'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppColors.primary.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vaca['identificador']?.toString() ?? '-',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.deep,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FactChip(
                            label: 'Raza',
                            value: vaca['raza']?.toString() ?? '-',
                          ),
                          _FactChip(
                            label: 'Sexo',
                            value: vaca['sexo']?.toString() ?? '-',
                          ),
                          _FactChip(
                            label: 'Estado',
                            value: vaca['estado']?.toString() ?? '-',
                          ),
                          _FactChip(
                            label: 'Nacimiento',
                            value: _fmtDate(vaca['fechaNacimiento']),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _historySection(
                context,
                title: 'Historial reproductivo',
                icon: Icons.favorite_border,
                rows: repro,
                showAll: _showAllRepro,
                onToggle: () {
                  setState(() {
                    _showAllRepro = !_showAllRepro;
                  });
                },
                rowBuilder: (e) => [
                  Text('Fecha: ${_fmtDate(e['fecha'])}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      const Text('Evento:'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeColor(e['tipoEvento']?.toString() ?? ''),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(e['tipoEvento']?.toString() ?? '-'),
                      ),
                    ],
                  ),
                  Text('Detalle: ${e['resultadoDiagnostico'] ?? e['toroUtilizado'] ?? e['criaId'] ?? e['observaciones'] ?? '-'}'),
                ],
              ),
              _historySection(
                context,
                title: 'Historial de leche',
                icon: Icons.water_drop_outlined,
                rows: leche,
                showAll: _showAllLeche,
                onToggle: () {
                  setState(() {
                    _showAllLeche = !_showAllLeche;
                  });
                },
                rowBuilder: (e) => [
                  Text('Fecha: ${_fmtDate(e['fecha'])}'),
                  Text('Manana: ${e['litrosManana'] ?? 0} L'),
                  Text('Tarde: ${e['litrosTarde'] ?? 0} L • Total: ${e['total'] ?? 0} L'),
                ],
              ),
              _historySection(
                context,
                title: 'Historial sanitario',
                icon: Icons.medical_services_outlined,
                rows: sanitario,
                showAll: _showAllSanitario,
                onToggle: () {
                  setState(() {
                    _showAllSanitario = !_showAllSanitario;
                  });
                },
                rowBuilder: (e) => [
                  Text('Fecha: ${_fmtDate(e['fecha'])}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      const Text('Categoria:'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeColor(e['categoria']?.toString() ?? ''),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(e['categoria']?.toString() ?? '-'),
                      ),
                    ],
                  ),
                  Text('Producto: ${e['producto'] ?? '-'} • Retiro: ${e['diasRetiro'] ?? 0} dias'),
                ],
              ),
              if (repro.length > _previewLimit ||
                  leche.length > _previewLimit ||
                  sanitario.length > _previewLimit)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Vista rapida activa. Usa Ver todo para desplegar cada seccion.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _shareSummary(context),
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Compartir'),
        ),
        TextButton.icon(
          onPressed: () => _exportPdf(context),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF'),
        ),
        TextButton.icon(
          onPressed: () => _printPdf(context),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Imprimir'),
        ),
        TextButton.icon(
          onPressed: () => _copySummary(context),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copiar resumen'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$label: $value'),
    );
  }
}
