import 'package:flutter/material.dart';
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
        SnackBar(
          content: Text(
            tempPwd == null || tempPwd.isEmpty
                ? 'Trabajador creado'
                : 'Trabajador creado. Contraseña temporal: $tempPwd',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
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
      builder: (_) => AlertDialog(
        title: const Text('Eliminar trabajador'),
        content: Text(
          'Se eliminará a ${worker.fullName}. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
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
          content: Text(
            'Nueva contraseña temporal para ${worker.email}: $temporaryPassword',
          ),
          duration: const Duration(seconds: 10),
        ),
      );
      await workersViewModel.loadWorkers();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo restablecer la contraseña: $e')),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const NavalgoPageIntro(
                    eyebrow: 'EQUIPO TÉCNICO',
                    title:
                        'Administra trabajadores, permisos y datos de acceso del equipo.',
                    subtitle:
                        'Consulta la plantilla, actualiza perfiles y revisa permisos, especialidades y estado contractual.',
                  ),
                  const SizedBox(height: 18),
                  const NavalgoSectionHeader(
                    title: 'Plantilla activa',
                    subtitle:
                        'Busca perfiles, revisa permisos y actúa sobre cada trabajador.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Buscar trabajador',
                    ),
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: NavalgoColors.mist,
                                child: const Icon(
                                  Icons.person,
                                  color: NavalgoColors.tide,
                                ),
                              ),
                              title: Text(
                                worker.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${worker.email}\n'
                                '${worker.role} • ${worker.speciality ?? 'Sin especialidad'}\n'
                                'Fecha de contratación: ${_fmtDate(worker.contractStartDate)} • '
                                'Editar partes: ${worker.canEditWorkOrders ? 'Sí' : 'No'}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openEditWorkerDialog(worker);
                                  }
                                  if (value == 'delete') {
                                    _deleteWorker(worker);
                                  }
                                  if (value == 'reset') {
                                    _resetPassword(worker);
                                  }
                                  if (value == 'toggle_active') {
                                    _toggleActive(worker, !worker.active);
                                  }
                                  if (value == 'toggle_edit') {
                                    _toggleEditPermission(
                                      worker,
                                      !worker.canEditWorkOrders,
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Text('Editar trabajador'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Eliminar trabajador'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'toggle_active',
                                    child: Text(
                                      worker.active ? 'Desactivar' : 'Activar',
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'toggle_edit',
                                    child: Text(
                                      worker.canEditWorkOrders
                                          ? 'Quitar permiso editar partes'
                                          : 'Dar permiso editar partes',
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'reset',
                                    child: Text('Restablecer contraseña'),
                                  ),
                                ],
                              ),
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
          'Da de alta un nuevo perfil del equipo con el mismo formato visual del resto de formularios principales.',
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: CheckboxListTile(
                  value: _canEditWorkOrders,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: NavalgoColors.tide,
                  title: const Text('Permitir editar partes'),
                  subtitle: const Text(
                    'Activa este permiso si podrá completar o modificar partes.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _canEditWorkOrders = value ?? false;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fecha de contratación',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: NavalgoFormStyles.inputDecoration(
                    context,
                    label: 'Fecha de contratación',
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    _formatDate(_contractStartDate),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NavalgoColors.deepSea,
                      fontWeight: FontWeight.w600,
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
      title: 'Editar trabajador',
      eyebrow: 'GESTIÓN DE EQUIPO',
      subtitle:
          'Ajusta los datos del trabajador con la misma estructura visual que el resto de formularios del panel.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar cambios'),
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: CheckboxListTile(
                  value: _canEditWorkOrders,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: NavalgoColors.tide,
                  title: const Text('Permitir editar partes'),
                  subtitle: const Text(
                    'Activa este permiso si podrá completar o modificar partes.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _canEditWorkOrders = value ?? false;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fecha de contratación',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: NavalgoFormStyles.inputDecoration(
                    context,
                    label: 'Fecha de contratación',
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    _formatDate(_contractStartDate),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NavalgoColors.deepSea,
                      fontWeight: FontWeight.w600,
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
