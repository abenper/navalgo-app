import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/worker_profile.dart';
import '../../services/network/api_exception.dart';
import '../../services/worker_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/workers_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key});

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkersViewModel>().loadWorkers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.serverMessage ?? error.message;
    }
    return error.toString();
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
        contractStartDate: result.contractStartDate,
      );

      await workersViewModel.loadWorkers();

      if (!mounted) {
        return;
      }
      final tempPwd = response.temporaryPassword;
      messenger.showSnackBar(
        const SnackBar(content: Text('Trabajador creado')),
      );
      if (tempPwd != null && tempPwd.isNotEmpty) {
        await _showTemporaryPasswordDialog(
          workerName: result.fullName,
          workerEmail: result.email,
          temporaryPassword: tempPwd,
          title: 'Contraseña temporal generada',
          subtitle:
              'Entrégala al trabajador y recuérdale que deberá cambiarla al iniciar sesión.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo crear el trabajador: ${_describeError(e)}'),
        ),
      );
    }
  }

  Future<void> _openEditWorkerDialog(WorkerProfile worker) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final workerService = context.read<WorkerService>();
    final workersViewModel = context.read<WorkersViewModel>();

    final result = await showDialog<_EditWorkerInput>(
      context: context,
      builder: (_) => _EditWorkerDialog(worker: worker),
    );
    if (!mounted || result == null) {
      return;
    }

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      await workerService.updateWorker(
        token,
        workerId: worker.id,
        fullName: result.fullName,
        email: result.email,
        speciality: result.speciality,
        role: result.role,
        canEditWorkOrders: result.canEditWorkOrders,
        contractStartDate: result.contractStartDate,
      );
      await workersViewModel.loadWorkers();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Trabajador actualizado')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  Future<void> _deleteWorker(WorkerProfile worker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => NavalgoConfirmDialog(
        title: 'Eliminar trabajador',
        message:
            'Se eliminará a ${worker.fullName}. Esta acción no se puede deshacer.',
        confirmLabel: 'Eliminar',
        destructive: true,
        icon: Icons.person_remove_outlined,
      ),
    );

    if (!mounted || confirm != true) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    final workerService = context.read<WorkerService>();
    final workersViewModel = context.read<WorkersViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    if (token == null) {
      return;
    }

    try {
      await workerService.deleteWorker(token, workerId: worker.id);
      await workersViewModel.loadWorkers();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Trabajador eliminado')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
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
      await workersViewModel.loadWorkers();
      if (!mounted) {
        return;
      }
      await _showTemporaryPasswordDialog(
        workerName: worker.fullName,
        workerEmail: worker.email,
        temporaryPassword: temporaryPassword,
        title: 'Nueva contraseña temporal',
        subtitle:
            'Compártela de forma segura. El trabajador podrá sustituirla después desde su perfil.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo restablecer la contraseña: $e')),
      );
    }
  }

  Future<void> _showTemporaryPasswordDialog({
    required String workerName,
    required String workerEmail,
    required String temporaryPassword,
    required String title,
    required String subtitle,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TemporaryPasswordDialog(
        workerName: workerName,
        workerEmail: workerEmail,
        temporaryPassword: temporaryPassword,
        title: title,
        subtitle: subtitle,
      ),
    );
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  NavalgoSearchField(
                    controller: _searchCtrl,
                    label: 'Buscar trabajador',
                    hint: 'Nombre, correo o especialidad',
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (context, value, _) {
                      final query = value.text.trim().toLowerCase();
                      final filteredWorkers = vm.workers.where((worker) {
                        if (query.isEmpty) {
                          return true;
                        }
                        return worker.fullName.toLowerCase().contains(query) ||
                            worker.email.toLowerCase().contains(query) ||
                            (worker.speciality ?? '').toLowerCase().contains(
                              query,
                            );
                      }).toList();

                      if (filteredWorkers.isEmpty) {
                        return const NavalgoPanel(
                          child: Text('No se encontraron trabajadores.'),
                        );
                      }

                      return Column(
                        children: filteredWorkers.map((worker) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _WorkerCard(
                              worker: worker,
                              formattedDate: _fmtDate(worker.contractStartDate),
                              onEdit: () => _openEditWorkerDialog(worker),
                              onToggleActive: () =>
                                  _toggleActive(worker, !worker.active),
                              onResetPassword: () => _resetPassword(worker),
                              onDelete: () => _deleteWorker(worker),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: NavalgoPanel(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _openCreateWorkerDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Crear trabajador'),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd/$mm/$yy';
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.worker,
    required this.formattedDate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onResetPassword,
    required this.onDelete,
  });

  final WorkerProfile worker;
  final String formattedDate;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = worker.active
        ? NavalgoColors.kelp
        : NavalgoColors.coral;
    return NavalgoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: NavalgoColors.mist,
                child: Icon(
                  worker.role == 'ADMIN'
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                  color: NavalgoColors.tide,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: NavalgoColors.deepSea,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        NavalgoStatusChip(
                          label: worker.active ? 'Activo' : 'Inactivo',
                          color: statusColor,
                        ),
                        NavalgoStatusChip(
                          label: worker.role == 'ADMIN'
                              ? 'Administrador'
                              : 'Trabajador',
                          color: NavalgoColors.tide,
                        ),
                        NavalgoStatusChip(
                          label: worker.canEditWorkOrders
                              ? 'Puede editar partes'
                              : 'Sin edición de partes',
                          color: worker.canEditWorkOrders
                              ? NavalgoColors.harbor
                              : NavalgoColors.storm,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NavalgoColors.foam,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NavalgoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.speciality?.trim().isNotEmpty == true
                      ? worker.speciality!
                      : 'Sin especialidad',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NavalgoColors.deepSea,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fecha de contratación: $formattedDate',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: onToggleActive,
                icon: Icon(
                  worker.active
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                label: Text(worker.active ? 'Desactivar' : 'Activar'),
              ),
              FilledButton.tonalIcon(
                onPressed: onResetPassword,
                icon: const Icon(Icons.password_outlined),
                label: const Text('Contraseña temporal'),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NavalgoColors.coral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemporaryPasswordDialog extends StatelessWidget {
  const _TemporaryPasswordDialog({
    required this.workerName,
    required this.workerEmail,
    required this.temporaryPassword,
    required this.title,
    required this.subtitle,
  });

  final String workerName;
  final String workerEmail;
  final String temporaryPassword;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'SEGURIDAD',
      title: title,
      subtitle: subtitle,
      actions: [
        NavalgoGhostButton(
          label: 'Cerrar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Copiar contraseña',
          icon: Icons.content_copy_outlined,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: temporaryPassword));
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contraseña copiada al portapapeles'),
              ),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NavalgoPanel(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: NavalgoColors.sand.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.key_outlined,
                    color: NavalgoColors.deepSea,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workerName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: NavalgoColors.deepSea,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(workerEmail),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          NavalgoFormFieldBlock(
            label: 'Contraseña temporal',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NavalgoColors.border),
              ),
              child: SelectableText(
                temporaryPassword,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: NavalgoColors.deepSea,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
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
    required this.contractStartDate,
  });

  final String fullName;
  final String email;
  final String speciality;
  final String role;
  final bool canEditWorkOrders;
  final DateTime contractStartDate;
}

class _EditWorkerInput {
  const _EditWorkerInput({
    required this.fullName,
    required this.email,
    required this.speciality,
    required this.role,
    required this.canEditWorkOrders,
    required this.contractStartDate,
  });

  final String fullName;
  final String email;
  final String speciality;
  final String role;
  final bool canEditWorkOrders;
  final DateTime contractStartDate;
}

class _CreateWorkerDialog extends StatefulWidget {
  const _CreateWorkerDialog();

  @override
  State<_CreateWorkerDialog> createState() => _CreateWorkerDialogState();
}

class _CreateWorkerDialogState extends State<_CreateWorkerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _specialityCtrl = TextEditingController();
  String _role = 'WORKER';
  bool _canEditWorkOrders = false;
  DateTime _contractStartDate = DateTime.now();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _specialityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'EQUIPO',
      title: 'Crear trabajador',
      subtitle:
          'Alta operativa del mecánico con rol, permisos y fecha de contratación.',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Crear trabajador',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavalgoFormFieldBlock(
              label: 'Nombre completo',
              child: TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nombre completo',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Indica el nombre del trabajador.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Correo electrónico',
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.alternate_email_outlined),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Indica el correo del trabajador.';
                  }
                  if (!trimmed.contains('@') || !trimmed.contains('.')) {
                    return 'Introduce un correo válido.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Especialidad',
              caption:
                  'Puedes dejarla vacía si todavía no quieres fijar la especialidad principal.',
              child: TextFormField(
                controller: _specialityCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Especialidad',
                  prefixIcon: const Icon(Icons.handyman_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Rol',
              child: DropdownButtonFormField<String>(
                initialValue: _role,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Rol',
                  prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'WORKER', child: Text('Trabajador')),
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _role = value ?? 'WORKER';
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Permisos',
              child: NavalgoCheckboxCard(
                value: _canEditWorkOrders,
                title: 'Permitir editar partes',
                subtitle:
                    'Activa este permiso si podrá completar o modificar partes.',
                onChanged: (value) {
                  setState(() {
                    _canEditWorkOrders = value ?? false;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fecha de contratación',
              child: NavalgoPickerField(
                label: 'Fecha de contratación',
                prefixIcon: const Icon(Icons.calendar_month_outlined),
                value: _formatDate(_contractStartDate),
                onTap: _pickDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _CreateWorkerInput(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        speciality: _specialityCtrl.text.trim(),
        role: _role,
        canEditWorkOrders: _canEditWorkOrders,
        contractStartDate: _contractStartDate,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _contractStartDate,
    );

    if (picked != null) {
      setState(() {
        _contractStartDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd/$mm/$yy';
  }
}

class _EditWorkerDialog extends StatefulWidget {
  const _EditWorkerDialog({required this.worker});

  final WorkerProfile worker;

  @override
  State<_EditWorkerDialog> createState() => _EditWorkerDialogState();
}

class _EditWorkerDialogState extends State<_EditWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _specialityCtrl;
  late String _role;
  late bool _canEditWorkOrders;
  late DateTime _contractStartDate;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.worker.fullName);
    _emailCtrl = TextEditingController(text: widget.worker.email);
    _specialityCtrl = TextEditingController(
      text: widget.worker.speciality ?? '',
    );
    _role = widget.worker.role;
    _canEditWorkOrders = widget.worker.canEditWorkOrders;
    _contractStartDate = widget.worker.contractStartDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _specialityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'EQUIPO',
      title: 'Editar trabajador',
      subtitle:
          'Ajusta los datos visibles del perfil sin salir del panel de administración.',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Guardar cambios',
          icon: Icons.save_outlined,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavalgoFormFieldBlock(
              label: 'Nombre completo',
              caption:
                  'Usa el nombre visible con el que el trabajador aparecerá en partes, fichajes y ausencias.',
              child: TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nombre completo',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Indica el nombre del trabajador.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Correo electrónico',
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.alternate_email_outlined),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Indica el correo del trabajador.';
                  }
                  if (!trimmed.contains('@') || !trimmed.contains('.')) {
                    return 'Introduce un correo válido.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Especialidad',
              caption:
                  'Puedes dejarla vacía si todavía no quieres fijar la especialidad principal.',
              child: TextFormField(
                controller: _specialityCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Especialidad',
                  prefixIcon: const Icon(Icons.handyman_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Rol',
              child: DropdownButtonFormField<String>(
                initialValue: _role,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Rol',
                  prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'WORKER', child: Text('Trabajador')),
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _role = value ?? 'WORKER';
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Permisos',
              child: NavalgoCheckboxCard(
                value: _canEditWorkOrders,
                title: 'Permitir editar partes',
                subtitle:
                    'Activa este permiso si podrá completar o modificar partes.',
                onChanged: (value) {
                  setState(() {
                    _canEditWorkOrders = value ?? false;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fecha de contratación',
              child: NavalgoPickerField(
                label: 'Fecha de contratación',
                prefixIcon: const Icon(Icons.calendar_month_outlined),
                value: _formatDate(_contractStartDate),
                onTap: _pickDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _EditWorkerInput(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        speciality: _specialityCtrl.text.trim(),
        role: _role,
        canEditWorkOrders: _canEditWorkOrders,
        contractStartDate: _contractStartDate,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _contractStartDate,
    );

    if (picked != null) {
      setState(() {
        _contractStartDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd/$mm/$yy';
  }
}
