import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/owner.dart';
import '../../models/vessel.dart';
import '../../models/worker_profile.dart';
import '../../models/work_order.dart';
import '../../services/work_order_service.dart';
import '../../viewmodels/fleet_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../viewmodels/workers_view_model.dart';

class PartesScreen extends StatefulWidget {
  const PartesScreen({super.key});

  @override
  State<PartesScreen> createState() => _PartesScreenState();
}

class _PartesScreenState extends State<PartesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<SessionViewModel>();
      final fleetViewModel = context.read<FleetViewModel>();
      final workersViewModel = context.read<WorkersViewModel>();
      final workOrdersViewModel = context.read<WorkOrdersViewModel>();
      final user = session.user;
      if (user == null) {
        return;
      }

      await fleetViewModel.loadFleet();
      if (user.role == 'ADMIN') {
        await workersViewModel.loadWorkers();
      }
      await workOrdersViewModel.loadWorkOrders(
        workerId: user.role == 'ADMIN' ? null : user.id,
      );
    });
  }

  Future<void> _openCreateDialog() async {
    final fleetVm = context.read<FleetViewModel>();
    final workersVm = context.read<WorkersViewModel>();
    final session = context.read<SessionViewModel>();
    final workOrderService = context.read<WorkOrderService>();
    final workOrdersViewModel = context.read<WorkOrdersViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final token = session.token;
    if (token == null) {
      return;
    }

    if (fleetVm.owners.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Crea un propietario antes de crear partes')),
      );
      return;
    }

    final input = await showModalBottomSheet<_CreatePartInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreatePartDialog(
        owners: fleetVm.owners,
        vessels: fleetVm.vessels,
        workers: workersVm.workers,
      ),
    );

    if (!mounted || input == null) {
      return;
    }

    try {
      await workOrderService.createWorkOrder(
        token,
        title: input.title,
        description: input.description,
        ownerId: input.ownerId,
        vesselId: input.vesselId,
        workerIds: input.workerIds,
        engineHours: input.engineHours
            .map((item) => <String, dynamic>{
                  'engineLabel': item.engineLabel,
                  'hours': item.hours,
                })
            .toList(),
        priority: input.priority,
      );

      await workOrdersViewModel.loadWorkOrders(
        workerId: session.user?.role == 'ADMIN' ? null : session.user?.id,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Parte creado correctamente')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo crear el parte: $e')),
      );
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    await context.read<WorkOrdersViewModel>().updateWorkOrderStatus(
      workOrderId: id,
      status: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkOrdersViewModel>();
    final isAdmin = context.watch<SessionViewModel>().user?.role == 'ADMIN';

    return Scaffold(
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(child: Text(vm.error!))
              : RefreshIndicator(
                  onRefresh: () async {
                    final session = context.read<SessionViewModel>();
                    await vm.loadWorkOrders(
                      workerId: session.user?.role == 'ADMIN' ? null : session.user?.id,
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vm.workOrders.length,
                    itemBuilder: (context, index) {
                      final WorkOrder parte = vm.workOrders[index];
                      final bool isUrgent = parte.priority == 'URGENT' || parte.priority == 'HIGH';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isUrgent ? Colors.red.shade100 : Colors.blue.shade100,
                            child: Icon(
                              Icons.build,
                              color: isUrgent ? Colors.red.shade900 : Colors.blue.shade900,
                            ),
                          ),
                          title: Text(
                            parte.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Cliente: ${parte.ownerName}\n'
                            'Asignado: ${parte.workerNames.isEmpty ? 'Sin asignar' : parte.workerNames.join(', ')}\n'
                            'Estado: ${parte.status}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => _updateStatus(parte.id, value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'NEW', child: Text('Pendiente')),
                              PopupMenuItem(value: 'IN_PROGRESS', child: Text('En curso')),
                              PopupMenuItem(value: 'DONE', child: Text('Finalizado')),
                              PopupMenuItem(value: 'CANCELLED', child: Text('Cancelado')),
                            ],
                            child: Chip(
                              label: Text(parte.status),
                              backgroundColor: _statusColor(parte.status).withValues(alpha: 0.12),
                              side: BorderSide.none,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: isAdmin
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Nuevo Parte'),
                ),
              ),
            )
          : null,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DONE':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

class _CreatePartInput {
  const _CreatePartInput({
    required this.title,
    required this.description,
    required this.ownerId,
    required this.vesselId,
    required this.workerIds,
    required this.engineHours,
    required this.priority,
  });

  final String title;
  final String description;
  final int ownerId;
  final int? vesselId;
  final List<int> workerIds;
  final List<EngineHourLog> engineHours;
  final String priority;
}

class _CreatePartDialog extends StatefulWidget {
  const _CreatePartDialog({
    required this.owners,
    required this.vessels,
    required this.workers,
  });

  final List<Owner> owners;
  final List<Vessel> vessels;
  final List<WorkerProfile> workers;

  @override
  State<_CreatePartDialog> createState() => _CreatePartDialogState();
}

class _CreatePartDialogState extends State<_CreatePartDialog> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  late int _ownerId;
  int? _vesselId;
  String _priority = 'NORMAL';
  final Set<int> _selectedWorkers = <int>{};
  final Map<String, TextEditingController> _engineHoursControllers =
      <String, TextEditingController>{};
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.owners.first.id;
    _syncVesselSelectionForOwner();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    for (final controller in _engineHoursControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableVessels = widget.vessels
        .where((vessel) => vessel.ownerId == _ownerId)
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nuevo Parte',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titulo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _ownerId,
                  decoration: const InputDecoration(
                    labelText: 'Propietario',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.owners
                      .map((o) => DropdownMenuItem(value: o.id, child: Text(o.displayName)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _ownerId = v ?? _ownerId;
                    });
                    _syncVesselSelectionForOwner();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: _vesselId,
                  decoration: const InputDecoration(
                    labelText: 'Embarcacion',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sin embarcacion'),
                    ),
                    ...availableVessels.map(
                      (vessel) => DropdownMenuItem<int?>(
                        value: vessel.id,
                        child: Text(vessel.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _vesselId = value;
                    });
                    _syncEngineHoursForSelectedVessel();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridad',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text('LOW')),
                    DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                    DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
                    DropdownMenuItem(value: 'URGENT', child: Text('URGENT')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'NORMAL'),
                ),
                if (_engineHoursControllers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Horas de motor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ..._engineHoursControllers.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: entry.key,
                          hintText: 'Horas',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Asignar trabajadores',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 180,
                  child: ListView(
                    children: widget.workers.map((worker) {
                      final selected = _selectedWorkers.contains(worker.id);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(worker.fullName),
                        subtitle: Text(worker.role),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedWorkers.add(worker.id);
                            } else {
                              _selectedWorkers.remove(worker.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                if (_validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Crear'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() {
        _validationError = 'El titulo es obligatorio.';
      });
      return;
    }

    final engineHours = <EngineHourLog>[];
    for (final entry in _engineHoursControllers.entries) {
      final hours = int.tryParse(entry.value.text.trim());
      if (hours == null) {
        setState(() {
          _validationError = 'Rellena las horas de todos los motores con numeros enteros.';
        });
        return;
      }
      engineHours.add(EngineHourLog(engineLabel: entry.key, hours: hours));
    }

    Navigator.pop(
      context,
      _CreatePartInput(
        title: title,
        description: _descriptionCtrl.text.trim(),
        ownerId: _ownerId,
        vesselId: _vesselId,
        workerIds: _selectedWorkers.toList(),
        engineHours: engineHours,
        priority: _priority,
      ),
    );
  }

  void _syncVesselSelectionForOwner() {
    final vessels = widget.vessels.where((vessel) => vessel.ownerId == _ownerId).toList();
    if (vessels.isEmpty) {
      _vesselId = null;
    } else if (_vesselId == null || !vessels.any((vessel) => vessel.id == _vesselId)) {
      _vesselId = vessels.first.id;
    }
    _syncEngineHoursForSelectedVessel();
  }

  void _syncEngineHoursForSelectedVessel() {
    final vessel = widget.vessels.where((item) => item.id == _vesselId).cast<Vessel?>().firstOrNull;
    final labels = vessel == null ? <String>[] : _resolveEngineLabels(vessel);

    final existingValues = <String, String>{
      for (final entry in _engineHoursControllers.entries) entry.key: entry.value.text,
    };

    for (final controller in _engineHoursControllers.values) {
      controller.dispose();
    }
    _engineHoursControllers
      ..clear()
      ..addEntries(
        labels.map(
          (label) => MapEntry(
            label,
            TextEditingController(text: existingValues[label] ?? ''),
          ),
        ),
      );

    if (mounted) {
      setState(() {
        _validationError = null;
      });
    }
  }

  List<String> _resolveEngineLabels(Vessel vessel) {
    if (vessel.engineLabels.isNotEmpty) {
      return vessel.engineLabels;
    }

    final count = vessel.engineCount ?? 0;
    return List<String>.generate(count, (index) => 'Motor ${index + 1}');
  }
}
