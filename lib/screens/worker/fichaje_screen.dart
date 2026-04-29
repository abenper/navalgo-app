import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_adjustment_request.dart';
import '../../models/time_entry.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

const List<_ClockWorkSiteOption> _clockWorkSiteOptions = [
  _ClockWorkSiteOption(
    value: 'WORKSHOP',
    title: 'Taller',
    subtitle: 'Jornada en taller, base o instalaciones propias.',
    icon: Icons.home_repair_service_rounded,
    accent: NavalgoColors.tide,
  ),
  _ClockWorkSiteOption(
    value: 'TRAVEL',
    title: 'Viaje',
    subtitle: 'Jornada en desplazamiento o servicio fuera del taller.',
    icon: Icons.route_rounded,
    accent: NavalgoColors.harbor,
  ),
];

class FichajeScreen extends StatefulWidget {
  const FichajeScreen({super.key});

  @override
  State<FichajeScreen> createState() => _FichajeScreenState();
}

class _FichajeScreenState extends State<FichajeScreen> {
  bool _isLoading = true;
  String? _error;
  bool _isPunchedIn = false;
  List<TimeEntry> _entries = <TimeEntry>[];
  List<TimeAdjustmentRequest> _adjustmentRequests =
      <TimeAdjustmentRequest>[];
  TodayClockedWorkersSummary? _todaySummary;
  bool _adjustmentBusy = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;
    final isAdmin = session.user?.role == 'ADMIN';

    if (token == null || workerId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sesión no válida';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final timeTrackingService = context.read<TimeTrackingService>();
      final entries = await timeTrackingService.getByWorker(
        token,
        workerId: workerId,
      );

      TodayClockedWorkersSummary? todaySummary;
      List<TimeAdjustmentRequest> adjustmentRequests =
          <TimeAdjustmentRequest>[];
      try {
        if (isAdmin) {
          todaySummary = await timeTrackingService.getTodaySummary(token);
          adjustmentRequests = await timeTrackingService.getAdjustmentRequests(
            token,
            status: 'PENDING',
          );
        } else {
          adjustmentRequests = await timeTrackingService.getAdjustmentRequests(
            token,
          );
        }
      } catch (_) {}

      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _isPunchedIn = entries.any((e) => e.clockOut == null);
        _todaySummary = todaySummary;
        _adjustmentRequests = adjustmentRequests;
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

  Future<void> _toggleClock() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;
    final messenger = ScaffoldMessenger.of(context);
    final timeTrackingService = context.read<TimeTrackingService>();

    if (token == null || workerId == null) {
      return;
    }

    try {
      if (_isPunchedIn) {
        await timeTrackingService.clockOut(token, workerId: workerId);
      } else {
        final workSite = await _selectWorkSite();
        if (!mounted || workSite == null) {
          return;
        }
        await timeTrackingService.clockIn(
          token,
          workerId: workerId,
          workSite: workSite,
        );
      }
      await _loadEntries();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('No se pudo fichar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<SessionViewModel, bool>(
      (session) => session.user?.role == 'ADMIN',
    );
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadEntries,
          child: const Icon(Icons.refresh),
        ),
      );
    }

    final todayEntries = _entries.where(_isToday).toList();
    final totalToday = todayEntries.fold<Duration>(
      Duration.zero,
      (acc, item) => acc + _durationForEntry(item),
    );
    final activeEntry = _entries.cast<TimeEntry?>().firstWhere(
      (item) => item?.clockOut == null,
      orElse: () => null,
    );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NavalgoPanel(
            child: Column(
              children: [
                Icon(
                  _isPunchedIn ? Icons.timer : Icons.timer_off,
                  size: 92,
                  color: _isPunchedIn
                      ? NavalgoColors.kelp
                      : NavalgoColors.storm,
                ),
                const SizedBox(height: 20),
                Text(
                  _isPunchedIn
                      ? 'Estado: Trabajando'
                      : 'Estado: Fuera de turno',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Total hoy: ${_formatDuration(totalToday)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (activeEntry != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ubicación actual: ${_workSiteLabel(activeEntry.workSite)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _isPunchedIn
                          ? NavalgoColors.coral
                          : NavalgoColors.kelp,
                    ),
                    onPressed: _toggleClock,
                    icon: Icon(_isPunchedIn ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isPunchedIn ? 'Finalizar Turno' : 'Iniciar Turno',
                    ),
                  ),
                ),
                if (!isAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _adjustmentBusy
                          ? null
                          : _openAdjustmentRequestDialog,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Solicitar ajuste de fichaje'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAdmin && _todaySummary != null) ...[
            const SizedBox(height: 18),
            const NavalgoSectionHeader(title: 'Resumen del día'),
            const SizedBox(height: 12),
            NavalgoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_todaySummary!.clockedWorkersCount} trabajador(es) con actividad hoy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _todaySummary!.workerNames.isEmpty
                        ? 'Todavía no hay registros hoy.'
                        : _todaySummary!.workerNames.join(', '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          NavalgoSectionHeader(
            title: isAdmin
                ? 'Solicitudes pendientes de ajuste'
                : 'Mis solicitudes de ajuste',
            subtitle: isAdmin
                ? 'Aprueba o rechaza los cambios solicitados por el equipo.'
                : 'Consulta el estado de tus solicitudes recientes.',
          ),
          const SizedBox(height: 12),
          if (_adjustmentRequests.isEmpty)
            NavalgoPanel(
              child: Text(
                isAdmin
                    ? 'No hay solicitudes pendientes de revisión.'
                    : 'Todavía no has enviado solicitudes de ajuste.',
              ),
            )
          else
            ..._adjustmentRequests.map((request) {
              final requestedClockIn = request.requestedClockIn;
              final requestedClockOut = request.requestedClockOut;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TimeAdjustmentRequestCard(
                  request: request,
                  workDateLabel: _fmtDate(request.workDate),
                  requestedHoursLabel:
                      '${requestedClockIn == null ? '--:--' : _fmtHour(requestedClockIn)} - ${requestedClockOut == null ? '--:--' : _fmtHour(requestedClockOut)}',
                  workSiteLabel: _workSiteLabel(request.workSite),
                  busy: _adjustmentBusy,
                  canReview: isAdmin && request.isPending,
                  onApprove: isAdmin && request.isPending
                      ? () => _reviewAdjustmentRequest(
                          request,
                          approve: true,
                        )
                      : null,
                  onReject: isAdmin && request.isPending
                      ? () => _reviewAdjustmentRequest(
                          request,
                          approve: false,
                        )
                      : null,
                ),
              );
            }),
          const SizedBox(height: 18),
          const NavalgoSectionHeader(title: 'Últimos registros'),
          const SizedBox(height: 12),
          ..._entries.take(6).map((item) {
            final duration = _durationForEntry(item);
            final active = item.clockOut == null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NavalgoPanel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (active ? NavalgoColors.kelp : NavalgoColors.coral)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      active ? Icons.login : Icons.logout,
                      color: active ? NavalgoColors.kelp : NavalgoColors.coral,
                    ),
                  ),
                  title: Text(_fmtDate(item.clockIn)),
                  subtitle: Text(
                    '${_workSiteLabel(item.workSite)} • Entrada: ${_fmtHour(item.clockIn)} - Salida: ${item.clockOut == null ? '--:--' : _fmtHour(item.clockOut!)}',
                  ),
                  trailing: Text(
                    _formatDuration(duration),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isToday(TimeEntry entry) {
    final now = DateTime.now();
    final inLocal = entry.clockIn.toLocal();
    return inLocal.year == now.year &&
        inLocal.month == now.month &&
        inLocal.day == now.day;
  }

  Duration _durationForEntry(TimeEntry entry) {
    final out = entry.clockOut?.toLocal() ?? DateTime.now();
    return out.difference(entry.clockIn.toLocal());
  }

  Future<String?> _selectWorkSite() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: NavalgoColors.heroGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Dónde comienza la jornada?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selecciona si el fichaje de hoy corresponde a taller o a viaje.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._clockWorkSiteOptions.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildWorkSiteAction(
                      context: sheetContext,
                      option: option,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkSiteAction({
    required BuildContext context,
    required _ClockWorkSiteOption option,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).pop(option.value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: option.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: option.accent.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: option.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(option.icon, color: option.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: option.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _workSiteLabel(String workSite) {
    switch (workSite) {
      case 'TRAVEL':
        return 'Viaje';
      default:
        return 'Taller';
    }
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  String _fmtHour(DateTime d) {
    final local = d.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '0h 00m';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  Future<void> _openAdjustmentRequestDialog() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final result = await showDialog<_TimeAdjustmentRequestInput>(
      context: context,
      builder: (_) => _TimeAdjustmentRequestDialog(entries: _entries),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() => _adjustmentBusy = true);
    try {
      await context.read<TimeTrackingService>().createAdjustmentRequest(
        token,
        timeEntryId: result.timeEntryId,
        workDate: result.workDate,
        requestedClockIn: result.requestedClockIn,
        requestedClockOut: result.requestedClockOut,
        workSite: result.workSite,
        reason: result.reason,
      );
      await _loadEntries();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Solicitud de ajuste enviada.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo enviar la solicitud: $e');
    } finally {
      if (mounted) {
        setState(() => _adjustmentBusy = false);
      }
    }
  }

  Future<void> _reviewAdjustmentRequest(
    TimeAdjustmentRequest request, {
    required bool approve,
  }) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final commentController = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            approve
                ? 'Aprobar ajuste de fichaje'
                : 'Rechazar ajuste de fichaje',
          ),
          content: TextField(
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comentario para el trabajador',
              hintText: 'Opcional',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                commentController.text.trim(),
              ),
              child: Text(approve ? 'Aprobar' : 'Rechazar'),
            ),
          ],
        );
      },
    );
    commentController.dispose();

    if (!mounted || comment == null) {
      return;
    }

    setState(() => _adjustmentBusy = true);
    try {
      await context.read<TimeTrackingService>().reviewAdjustmentRequest(
        token,
        requestId: request.id,
        status: approve ? 'APPROVED' : 'REJECTED',
        adminComment: comment.isEmpty ? null : comment,
      );
      await _loadEntries();
      if (!mounted) {
        return;
      }
      AppToast.success(
        context,
        approve
            ? 'Ajuste aprobado y aplicado.'
            : 'Solicitud rechazada correctamente.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo revisar la solicitud: $e');
    } finally {
      if (mounted) {
        setState(() => _adjustmentBusy = false);
      }
    }
  }
}

class _TimeAdjustmentRequestInput {
  const _TimeAdjustmentRequestInput({
    required this.timeEntryId,
    required this.workDate,
    required this.requestedClockIn,
    required this.requestedClockOut,
    required this.workSite,
    required this.reason,
  });

  final int? timeEntryId;
  final DateTime workDate;
  final DateTime? requestedClockIn;
  final DateTime? requestedClockOut;
  final String workSite;
  final String reason;
}

class _TimeAdjustmentRequestDialog extends StatefulWidget {
  const _TimeAdjustmentRequestDialog({required this.entries});

  final List<TimeEntry> entries;

  @override
  State<_TimeAdjustmentRequestDialog> createState() =>
      _TimeAdjustmentRequestDialogState();
}

class _TimeAdjustmentRequestDialogState
    extends State<_TimeAdjustmentRequestDialog> {
  final TextEditingController _reasonController = TextEditingController();
  int? _selectedEntryId;
  late DateTime _workDate;
  TimeOfDay? _clockInTime;
  TimeOfDay? _clockOutTime;
  String _workSite = 'WORKSHOP';
  String? _error;

  @override
  void initState() {
    super.initState();
    _workDate = DateTime.now();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Solicitar ajuste de fichaje'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: _selectedEntryId,
              decoration: const InputDecoration(
                labelText: 'Fichaje a ajustar',
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin registro existente'),
                ),
                ...widget.entries.map(
                  (entry) => DropdownMenuItem<int?>(
                    value: entry.id,
                    child: Text(
                      '${_formatDialogDate(entry.clockIn)} · ${_workSiteLabelForDialog(entry.workSite)} · ${_formatDialogHour(entry.clockIn)} - ${entry.clockOut == null ? '--:--' : _formatDialogHour(entry.clockOut!)}',
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                final selectedEntry = widget.entries
                    .where((entry) => entry.id == value)
                    .cast<TimeEntry?>()
                    .firstOrNull;
                setState(() {
                  _selectedEntryId = value;
                  if (selectedEntry != null) {
                    final localClockIn = selectedEntry.clockIn.toLocal();
                    _workDate = DateTime(
                      localClockIn.year,
                      localClockIn.month,
                      localClockIn.day,
                    );
                    _clockInTime = TimeOfDay.fromDateTime(localClockIn);
                    _clockOutTime = selectedEntry.clockOut == null
                        ? null
                        : TimeOfDay.fromDateTime(selectedEntry.clockOut!.toLocal());
                    _workSite = selectedEntry.workSite;
                  }
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _workDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (!mounted || picked == null) {
                  return;
                }
                setState(() {
                  _workDate = picked;
                });
              },
              icon: const Icon(Icons.event_outlined),
              label: Text('Fecha: ${_formatDialogDate(_workDate)}'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _clockInTime ??
                            const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (!mounted || picked == null) {
                        return;
                      }
                      setState(() {
                        _clockInTime = picked;
                      });
                    },
                    icon: const Icon(Icons.login),
                    label: Text(
                      _clockInTime == null
                          ? 'Entrada'
                          : 'Entrada ${_clockInTime!.format(context)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _clockOutTime ??
                            const TimeOfDay(hour: 17, minute: 0),
                      );
                      if (!mounted || picked == null) {
                        return;
                      }
                      setState(() {
                        _clockOutTime = picked;
                      });
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(
                      _clockOutTime == null
                          ? 'Salida'
                          : 'Salida ${_clockOutTime!.format(context)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _workSite,
              decoration: const InputDecoration(labelText: 'Tipo de jornada'),
              items: const [
                DropdownMenuItem(value: 'WORKSHOP', child: Text('Taller')),
                DropdownMenuItem(value: 'TRAVEL', child: Text('Viaje')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _workSite = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText:
                    'Explica qué hora debe corregirse y por qué no quedó registrada correctamente.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enviar solicitud'),
        ),
      ],
    );
  }

  void _submit() {
    if (_reasonController.text.trim().isEmpty) {
      setState(() {
        _error = 'Debes indicar el motivo del ajuste.';
      });
      return;
    }
    if (_clockInTime == null && _clockOutTime == null) {
      setState(() {
        _error = 'Indica al menos una hora a ajustar.';
      });
      return;
    }

    DateTime? combine(TimeOfDay? time) {
      if (time == null) {
        return null;
      }
      return DateTime(
        _workDate.year,
        _workDate.month,
        _workDate.day,
        time.hour,
        time.minute,
      );
    }

    Navigator.pop(
      context,
      _TimeAdjustmentRequestInput(
        timeEntryId: _selectedEntryId,
        workDate: DateTime(_workDate.year, _workDate.month, _workDate.day),
        requestedClockIn: combine(_clockInTime),
        requestedClockOut: combine(_clockOutTime),
        workSite: _workSite,
        reason: _reasonController.text.trim(),
      ),
    );
  }
}

class _TimeAdjustmentRequestCard extends StatelessWidget {
  const _TimeAdjustmentRequestCard({
    required this.request,
    required this.workDateLabel,
    required this.requestedHoursLabel,
    required this.workSiteLabel,
    required this.busy,
    required this.canReview,
    this.onApprove,
    this.onReject,
  });

  final TimeAdjustmentRequest request;
  final String workDateLabel;
  final String requestedHoursLabel;
  final String workSiteLabel;
  final bool busy;
  final bool canReview;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final statusColor = _timeAdjustmentStatusColor(request.status);
    return NavalgoPanel(
      tint: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.workerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$workDateLabel · $workSiteLabel · $requestedHoursLabel',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              NavalgoStatusChip(
                label: _timeAdjustmentStatusLabel(request.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(request.reason, style: Theme.of(context).textTheme.bodyLarge),
          if (request.adminComment != null && request.adminComment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Comentario: ${request.adminComment}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check_outlined),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClockWorkSiteOption {
  const _ClockWorkSiteOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

Color _timeAdjustmentStatusColor(String status) {
  switch (status) {
    case 'APPROVED':
      return NavalgoColors.kelp;
    case 'REJECTED':
      return NavalgoColors.coral;
    case 'PENDING':
    default:
      return NavalgoColors.sand;
  }
}

String _timeAdjustmentStatusLabel(String status) {
  switch (status) {
    case 'APPROVED':
      return 'Aprobada';
    case 'REJECTED':
      return 'Rechazada';
    case 'PENDING':
    default:
      return 'Pendiente';
  }
}

String _formatDialogDate(DateTime d) {
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  return '$dd/$mm/$yyyy';
}

String _formatDialogHour(DateTime d) {
  final local = d.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _workSiteLabelForDialog(String workSite) {
  switch (workSite) {
    case 'TRAVEL':
      return 'Viaje';
    default:
      return 'Taller';
  }
}
