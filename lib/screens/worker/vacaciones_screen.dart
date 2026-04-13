import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leave_request.dart';
import '../../services/leave_service.dart';
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

  bool get _isAdmin => context.read<SessionViewModel>().user?.role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final session = context.read<SessionViewModel>();
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
        workerId: _isAdmin ? null : session.user?.id,
      );
      setState(() {
        _requests = requests;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createRequest() async {
    final result = await showDialog<_LeaveFormResult>(
      context: context,
      builder: (_) => const _FormularioAusenciaDialog(),
    );

    if (result == null) {
      return;
    }

    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada')),
        );
      }
      await _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear la solicitud: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(int requestId, String status) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    try {
      await context.read<LeaveService>().updateStatus(
        token,
        leaveRequestId: requestId,
        status: status,
      );
      await _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar la solicitud: $e')),
        );
      }
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
          onPressed: _loadRequests,
          child: const Icon(Icons.refresh),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _requests.length,
          itemBuilder: (context, index) {
            final req = _requests[index];
            final color = _statusColor(req.status);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.event_note, color: color),
                ),
                title: Text(
                  '${_fmt(req.startDate)} - ${_fmt(req.endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _isAdmin
                      ? 'Trabajador: ${req.workerName}\nMotivo: ${req.reason}'
                      : 'Motivo: ${req.reason}',
                ),
                isThreeLine: _isAdmin,
                trailing: _isAdmin && req.status == 'PENDING'
                    ? Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'Aprobar',
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => _updateStatus(req.id, 'APPROVED'),
                          ),
                          IconButton(
                            tooltip: 'Rechazar',
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _updateStatus(req.id, 'REJECTED'),
                          ),
                        ],
                      )
                    : Chip(
                        label: Text(_statusLabel(req.status)),
                        backgroundColor: color.withValues(alpha: 0.12),
                        side: BorderSide.none,
                      ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _createRequest,
              icon: const Icon(Icons.add),
              label: const Text('Solicitar Ausencia'),
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
            ),
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Aprobada';
      case 'REJECTED':
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
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

class _FormularioAusenciaDialog extends StatefulWidget {
  const _FormularioAusenciaDialog();

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
      title: const Text('Solicitar Ausencia', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    : '${_fechas!.start.day}/${_fechas!.start.month}/${_fechas!.start.year} - '
                          '${_fechas!.end.day}/${_fechas!.end.month}/${_fechas!.end.year}',
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
          child: const Text('Solicitar'),
        ),
      ],
    );
  }
}
