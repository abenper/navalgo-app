import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/worker_profile.dart';
import '../../services/worker_service.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/workers_view_model.dart';

class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key});

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkersViewModel>().loadWorkers();
    });
  }

  Future<void> _openCreateWorkerDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final workerService = context.read<WorkerService>();
    final workersViewModel = context.read<WorkersViewModel>();

    final result = await showDialog<_CreateWorkerInput>(
      context: context,
      builder: (_) => const _CreateWorkerDialog(),
    );
    if (!mounted || result == null) {
      return;
    }

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      final response = await workerService.createWorker(
        token,
        fullName: result.fullName,
        email: result.email,
        speciality: result.speciality,
        role: result.role,
        canEditWorkOrders: result.canEditWorkOrders,
      );

      await workersViewModel.loadWorkers();

      if (!mounted) {
        return;
      }
      final tempPwd = response.temporaryPassword;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tempPwd == null || tempPwd.isEmpty
                ? 'Trabajador creado'
                : 'Trabajador creado. Password temporal: $tempPwd',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo crear el trabajador: $e')),
      );
    }
  }

  Future<void> _toggleActive(WorkerProfile worker, bool active) async {
    final token = context.read<SessionViewModel>().token;
    final workerService = context.read<WorkerService>();
    final workersViewModel = context.read<WorkersViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      await workerService.updateActive(
        token,
        workerId: worker.id,
        active: active,
      );
      await workersViewModel.loadWorkers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar estado: $e')),
      );
    }
  }

  Future<void> _toggleEditPermission(WorkerProfile worker, bool enabled) async {
    final token = context.read<SessionViewModel>().token;
    final workerService = context.read<WorkerService>();
    final workersViewModel = context.read<WorkersViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      await workerService.updateWorkOrderPermission(
        token,
        workerId: worker.id,
        canEditWorkOrders: enabled,
      );
      await workersViewModel.loadWorkers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar permiso: $e')),
      );
    }
  }

  Future<void> _resetPassword(WorkerProfile worker) async {
    final token = context.read<SessionViewModel>().token;
    final workerService = context.read<WorkerService>();
    final workersViewModel = context.read<WorkersViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      final temporaryPassword = await workerService.resetPassword(
        token,
        workerId: worker.id,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Nueva password temporal para ${worker.email}: $temporaryPassword'),
          duration: const Duration(seconds: 10),
        ),
      );
      await workersViewModel.loadWorkers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo resetear la password: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkersViewModel>();

    return Scaffold(
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(child: Text(vm.error!))
              : RefreshIndicator(
                  onRefresh: vm.loadWorkers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vm.workers.length,
                    itemBuilder: (context, index) {
                      final worker = vm.workers[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(Icons.person, color: Colors.blue.shade900),
                          ),
                          title: Text(
                            worker.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${worker.email}\n'
                            '${worker.role} • ${worker.speciality ?? 'Sin especialidad'}\n'
                            'Cambio password: ${worker.mustChangePassword ? 'SI' : 'NO'} • '
                            'Editar partes: ${worker.canEditWorkOrders ? 'SI' : 'NO'}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'reset') {
                                _resetPassword(worker);
                              }
                              if (value == 'toggle_active') {
                                _toggleActive(worker, !worker.active);
                              }
                              if (value == 'toggle_edit') {
                                _toggleEditPermission(worker, !worker.canEditWorkOrders);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'toggle_active',
                                child: Text(worker.active ? 'Desactivar' : 'Activar'),
                              ),
                              PopupMenuItem<String>(
                                value: 'toggle_edit',
                                child: Text(worker.canEditWorkOrders
                                    ? 'Quitar permiso editar partes'
                                    : 'Dar permiso editar partes'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'reset',
                                child: Text('Resetear password'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _openCreateWorkerDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('Crear Trabajador'),
          ),
        ),
      ),
    );
  }
}

class _CreateWorkerInput {
  const _CreateWorkerInput({
    required this.fullName,
    required this.email,
    required this.speciality,
    required this.role,
    required this.canEditWorkOrders,
  });

  final String fullName;
  final String email;
  final String speciality;
  final String role;
  final bool canEditWorkOrders;
}

class _CreateWorkerDialog extends StatefulWidget {
  const _CreateWorkerDialog();

  @override
  State<_CreateWorkerDialog> createState() => _CreateWorkerDialogState();
}

class _CreateWorkerDialogState extends State<_CreateWorkerDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _specialityCtrl = TextEditingController();
  String _role = 'WORKER';
  bool _canEditWorkOrders = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _specialityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Crear Trabajador'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _specialityCtrl,
              decoration: const InputDecoration(
                labelText: 'Especialidad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'WORKER', child: Text('WORKER')),
                DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'WORKER'),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _canEditWorkOrders,
              onChanged: (v) => setState(() => _canEditWorkOrders = v ?? false),
              contentPadding: EdgeInsets.zero,
              title: const Text('Puede editar partes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _CreateWorkerInput(
                fullName: _nameCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
                speciality: _specialityCtrl.text.trim(),
                role: _role,
                canEditWorkOrders: _canEditWorkOrders,
              ),
            );
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
