import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leave_request.dart';
import '../../models/worker_profile.dart';
import '../../services/leave_service.dart';
import '../../services/worker_service.dart';
import '../../viewmodels/session_view_model.dart';

class AusenciasScreen extends StatefulWidget {
  const AusenciasScreen({super.key});

  @override
  State<AusenciasScreen> createState() => _AusenciasScreenState();
}

class _AusenciasScreenState extends State<AusenciasScreen> {
  bool _isLoading = true;
  String? _error;
  List<LeaveRequestModel> _requests = <LeaveRequestModel>[];
  LeaveBalance? _balance;
  List<WorkerProfile> _workers = <WorkerProfile>[];

  bool get _isAdmin => context.read<SessionViewModel>().user?.role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionViewModel>();
    final isAdmin = _isAdmin;
    final workerService = context.read<WorkerService>();
    final token = session.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesion activa';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final leaveService = context.read<LeaveService>();
      final requests = await leaveService.getLeaveRequests(
        token,
        workerId: isAdmin ? null : session.user?.id,
      );

      LeaveBalance? balance;
      if (!isAdmin) {
        balance = await leaveService.getLeaveBalance(
          token,
          workerId: session.user?.id,
        );
      }

      List<WorkerProfile> workers = <WorkerProfile>[];
      if (isAdmin) {
        workers = await workerService.getWorkers(token);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = requests;
        _balance = balance;
        _workers = workers;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createRequest() async {
    final result = await showDialog<_LeaveFormResult>(
      context: context,
      builder: (_) => const _FormularioAusenciaDialog(),
    );

    if (!mounted || result == null) {
      return;
    }

    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;
    final messenger = ScaffoldMessenger.of(context);

    if (token == null || workerId == null) {
      return;
    }

    try {
      await context.read<LeaveService>().createLeaveRequest(
        token,
        workerId: workerId,
        reason: result.reason,
        startDate: result.range.start,
        endDate: result.range.end,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Solicitud enviada')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo crear la solicitud: $e')),
      );
    }
  }

  Future<void> _editRequest(LeaveRequestModel request) async {
    final result = await showDialog<_LeaveFormResult>(
      context: context,
      builder: (_) => _FormularioAusenciaDialog(
        title: 'Editar Solicitud',
        submitLabel: 'Guardar cambios',
        initialReason: request.reason,
        initialRange: DateTimeRange(start: request.startDate, end: request.endDate),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final session = context.read<SessionViewModel>();
    final token = session.token;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      await context.read<LeaveService>().updateLeaveRequest(
        token,
        leaveRequestId: request.id,
        reason: result.reason,
        startDate: result.range.start,
        endDate: result.range.end,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Solicitud editada. Estado: pendiente de confirmacion')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo editar la solicitud: $e')),
      );
    }
  }

  Future<void> _cancelRequest(LeaveRequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar vacaciones'),
        content: const Text('Esta accion cancelara la solicitud actual. ¿Deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Si, cancelar'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      await context.read<LeaveService>().cancelLeaveRequest(
        token,
        leaveRequestId: request.id,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Vacaciones canceladas.')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cancelar la solicitud: $e')),
      );
    }
  }

  Future<void> _adminAssignRequest() async {
    if (_workers.isEmpty) {
      return;
    }

    final result = await showDialog<_AdminAssignLeaveFormResult>(
      context: context,
      builder: (_) => _AdminAssignLeaveDialog(workers: _workers),
    );

    if (!mounted || result == null) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      await context.read<LeaveService>().adminAssignLeave(
        token,
        workerId: result.workerId,
        reason: result.reason,
        startDate: result.range.start,
        endDate: result.range.end,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Vacaciones asignadas y aceptadas correctamente')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo asignar la vacacion: $e')),
      );
    }
  }

  Future<void> _updateStatus(int requestId, String status) async {
    final token = context.read<SessionViewModel>().token;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      await context.read<LeaveService>().updateStatus(
        token,
        leaveRequestId: requestId,
        status: status,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la solicitud: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadData,
          child: const Icon(Icons.refresh),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_balance != null)
              Card(
                color: Colors.indigo.shade50,
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAdmin
                            ? 'Saldo global de ${_balance!.workerName}'
                            : 'Tus dias de vacaciones',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Disponibles: ${_balance!.availableDays.toStringAsFixed(1)} dias',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Devengados: ${_balance!.accruedDays.toStringAsFixed(1)} • Consumidos: ${_balance!.consumedDays}',
                      ),
                    ],
                  ),
                ),
              ),
            ..._requests.map((req) {
              final color = _statusColor(req.status);
              final statusLabel = _statusLabel(req.status);
              final workerCanEditOrCancel = !_isAdmin && req.status == 'APPROVED';
              final adminCanChangeStatus = _isAdmin;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(Icons.event_note, color: color),
                  ),
                  title: Text(
                    '${_fmt(req.startDate)} - ${_fmt(req.endDate)} (${req.requestedDays} dias)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isAdmin
                        ? 'Trabajador: ${req.workerName}\nMotivo: ${req.reason}'
                        : 'Motivo: ${req.reason}',
                  ),
                  isThreeLine: _isAdmin,
                  trailing: SizedBox(
                    width: 156,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(statusLabel),
                          backgroundColor: color.withValues(alpha: 0.12),
                          side: BorderSide.none,
                        ),
                        if (workerCanEditOrCancel || adminCanChangeStatus)
                          PopupMenuButton<String>(
                            tooltip: 'Acciones',
                            onSelected: (value) {
                              if (value == 'EDIT') {
                                _editRequest(req);
                                return;
                              }
                              if (value == 'CANCEL') {
                                _cancelRequest(req);
                                return;
                              }
                              _updateStatus(req.id, value);
                            },
                            itemBuilder: (_) {
                              final items = <PopupMenuEntry<String>>[];
                              if (workerCanEditOrCancel) {
                                items.add(
                                  const PopupMenuItem(
                                    value: 'EDIT',
                                    child: Text('Editar (volver a pendiente)'),
                                  ),
                                );
                                items.add(
                                  const PopupMenuItem(
                                    value: 'CANCEL',
                                    child: Text('Cancelar vacaciones'),
                                  ),
                                );
                              }
                              if (adminCanChangeStatus) {
                                if (req.status != 'PENDING') {
                                  items.add(const PopupMenuItem(value: 'PENDING', child: Text('Marcar pendiente')));
                                }
                                if (req.status != 'APPROVED') {
                                  items.add(const PopupMenuItem(value: 'APPROVED', child: Text('Marcar aceptada')));
                                }
                                if (req.status != 'REJECTED') {
                                  items.add(const PopupMenuItem(value: 'REJECTED', child: Text('Marcar rechazada')));
                                }
                                if (req.status != 'CANCELLED') {
                                  items.add(const PopupMenuItem(value: 'CANCELLED', child: Text('Marcar cancelada')));
                                }
                              }
                              return items;
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.more_horiz, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _isAdmin
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _adminAssignRequest,
                        icon: const Icon(Icons.event_available),
                        label: const Text('Asignar Vacaciones'),
                      ),
                    ),
                  ],
                )
              : FilledButton.icon(
                  onPressed: _createRequest,
                  icon: const Icon(Icons.add),
                  label: const Text('Solicitar Ausencia'),
                ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Aceptada';
      case 'REJECTED':
        return 'Rechazada';
      case 'CANCELLED':
        return 'Cancelada';
      default:
        return 'Pendiente (A la espera)';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}

class _LeaveFormResult {
  const _LeaveFormResult({required this.reason, required this.range});

  final String reason;
  final DateTimeRange range;
}

class _AdminAssignLeaveFormResult {
  const _AdminAssignLeaveFormResult({
    required this.workerId,
    required this.reason,
    required this.range,
  });

  final int workerId;
  final String reason;
  final DateTimeRange range;
}

class _FormularioAusenciaDialog extends StatefulWidget {
  const _FormularioAusenciaDialog({
    this.title = 'Solicitar Ausencia',
    this.submitLabel = 'Enviar Solicitud',
    this.initialReason,
    this.initialRange,
  });

  final String title;
  final String submitLabel;
  final String? initialReason;
  final DateTimeRange? initialRange;

  @override
  State<_FormularioAusenciaDialog> createState() => _FormularioAusenciaDialogState();
}

class _FormularioAusenciaDialogState extends State<_FormularioAusenciaDialog> {
  String _motivo = 'Vacaciones';
  DateTimeRange? _fechas;

  final List<String> _motivos = [
    'Vacaciones',
    'Medico',
    'Maternidad/Paternidad',
    'Asuntos Propios',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _motivo = widget.initialReason ?? 'Vacaciones';
    _fechas = widget.initialRange;
  }

  Future<void> _seleccionarFechas() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _fechas,
      helpText: 'Selecciona fechas',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade900),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechas = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Motivo', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _motivo,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: _motivos.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (val) => setState(() => _motivo = val!),
          ),
          const SizedBox(height: 20),
          const Text('Fechas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.maxFinite,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _fechas == null
                    ? 'Toca para seleccionar fechas'
                    : '${_fechas!.start.day}/${_fechas!.start.month}/${_fechas!.start.year} - ${_fechas!.end.day}/${_fechas!.end.month}/${_fechas!.end.year}',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              onPressed: _seleccionarFechas,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade900,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (_fechas == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selecciona fechas')),
              );
              return;
            }
            Navigator.pop(
              context,
              _LeaveFormResult(reason: _motivo, range: _fechas!),
            );
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

class _AdminAssignLeaveDialog extends StatefulWidget {
  const _AdminAssignLeaveDialog({required this.workers});

  final List<WorkerProfile> workers;

  @override
  State<_AdminAssignLeaveDialog> createState() => _AdminAssignLeaveDialogState();
}

class _AdminAssignLeaveDialogState extends State<_AdminAssignLeaveDialog> {
  String _reason = 'Vacaciones';
  DateTimeRange? _dates;
  late int _workerId;

  @override
  void initState() {
    super.initState();
    _workerId = widget.workers.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar Vacaciones (Aceptada)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _workerId,
              decoration: const InputDecoration(
                labelText: 'Trabajador',
                border: OutlineInputBorder(),
              ),
              items: widget.workers
                  .map((worker) => DropdownMenuItem<int>(
                        value: worker.id,
                        child: Text(worker.fullName),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _workerId = value ?? _workerId),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _reason,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _reason = value,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _dates == null
                    ? 'Seleccionar fechas'
                    : '${_dates!.start.day}/${_dates!.start.month}/${_dates!.start.year} - ${_dates!.end.day}/${_dates!.end.month}/${_dates!.end.year}',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_dates == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selecciona un rango de fechas')),
              );
              return;
            }
            Navigator.pop(
              context,
              _AdminAssignLeaveFormResult(
                workerId: _workerId,
                reason: _reason.trim().isEmpty ? 'Vacaciones' : _reason.trim(),
                range: _dates!,
              ),
            );
          },
          child: const Text('Asignar'),
        ),
      ],
    );
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dates,
    );

    if (picked != null) {
      setState(() {
        _dates = picked;
      });
    }
  }
}
