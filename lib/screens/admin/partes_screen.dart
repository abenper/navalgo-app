import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/owner.dart';
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
      final user = session.user;
      if (user == null) {
        return;
      }

      await context.read<FleetViewModel>().loadFleet();
      await context.read<WorkersViewModel>().loadWorkers();
      await context.read<WorkOrdersViewModel>().loadWorkOrders(
        workerId: user.role == 'ADMIN' ? null : user.id,
      );
    });
  }

  Future<void> _openCreateDialog() async {
    final fleetVm = context.read<FleetViewModel>();
    final workersVm = context.read<WorkersViewModel>();
    final session = context.read<SessionViewModel>();
    final token = session.token;
    if (token == null) {
      return;
    }

    if (fleetVm.owners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea un propietario antes de crear partes')),
      );
      return;
    }

    final input = await showDialog<_CreatePartInput>(
      context: context,
      builder: (_) => _CreatePartDialog(
        owners: fleetVm.owners,
        workers: workersVm.workers,
      ),
    );

    if (input == null) {
      return;
    }

    try {
      await context.read<WorkOrderService>().createWorkOrder(
        token,
        title: input.title,
        description: input.description,
        ownerId: input.ownerId,
        vesselId: input.vesselId,
        workerIds: input.workerIds,
        priority: input.priority,
      );

      await context.read<WorkOrdersViewModel>().loadWorkOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte creado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear el parte: $e')),
        );
      }
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
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Parte'),
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
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
    required this.priority,
  });

  final String title;
  final String description;
  final int ownerId;
  final int? vesselId;
  final List<int> workerIds;
  final String priority;
}

class _CreatePartDialog extends StatefulWidget {
  const _CreatePartDialog({required this.owners, required this.workers});

  final List<Owner> owners;
  final List<WorkerProfile> workers;

  @override
  State<_CreatePartDialog> createState() => _CreatePartDialogState();
}

class _CreatePartDialogState extends State<_CreatePartDialog> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  late int _ownerId;
  String _priority = 'NORMAL';
  final Set<int> _selectedWorkers = <int>{};

  @override
  void initState() {
    super.initState();
    _ownerId = widget.owners.first.id;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nuevo Parte'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              onChanged: (v) => setState(() => _ownerId = v ?? _ownerId),
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
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Asignar trabajadores', style: TextStyle(fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _CreatePartInput(
                title: _titleCtrl.text.trim(),
                description: _descriptionCtrl.text.trim(),
                ownerId: _ownerId,
                vesselId: null,
                workerIds: _selectedWorkers.toList(),
                priority: _priority,
              ),
            );
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
