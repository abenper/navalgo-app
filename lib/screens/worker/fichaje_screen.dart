import 'dart:async';

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
  List<TimeAdjustmentRequest> _adjustmentRequests = <TimeAdjustmentRequest>[];
  TodayClockedWorkersSummary? _todaySummary;
  bool _adjustmentBusy = false;
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
    _loadEntries();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
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
        final clockInInput = await _selectClockInInput();
        if (!mounted || clockInInput == null) {
          return;
        }
        await timeTrackingService.clockIn(
          token,
          workerId: workerId,
          workSite: clockInInput.workSite,
          plannedClockOut: clockInInput.plannedClockOut,
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
          _buildClockControlPanel(
            context,
            isAdmin: isAdmin,
            totalToday: totalToday,
            activeEntry: activeEntry,
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
                  canEdit: !isAdmin && request.isPending,
                  canDelete: !isAdmin && request.isPending,
                  onApprove: isAdmin && request.isPending
                      ? () => _reviewAdjustmentRequest(request, approve: true)
                      : null,
                  onReject: isAdmin && request.isPending
                      ? () => _reviewAdjustmentRequest(request, approve: false)
                      : null,
                  onEdit: !isAdmin && request.isPending
                      ? () => _editAdjustmentRequest(request)
                      : null,
                  onDelete: !isAdmin && request.isPending
                      ? () => _deleteAdjustmentRequest(request)
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

  Widget _buildClockControlPanel(
    BuildContext context, {
    required bool isAdmin,
    required Duration totalToday,
    required TimeEntry? activeEntry,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 860;
    final stateColor = _isPunchedIn ? NavalgoColors.kelp : NavalgoColors.storm;

    final clockBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPunchedIn ? Icons.radio_button_checked : Icons.timer_off,
                size: 18,
                color: stateColor,
              ),
              const SizedBox(width: 8),
              Text(
                _isPunchedIn ? 'Trabajando' : 'Fuera de turno',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _fmtHourWithSeconds(_now),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: NavalgoColors.deepSea,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _fmtLongDate(_now),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: NavalgoColors.storm,
          ),
        ),
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _isPunchedIn
                ? NavalgoColors.coral
                : NavalgoColors.kelp,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
          onPressed: _toggleClock,
          icon: Icon(_isPunchedIn ? Icons.stop : Icons.play_arrow),
          label: Text(_isPunchedIn ? 'Finalizar turno' : 'Iniciar turno'),
        ),
        if (!isAdmin) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _adjustmentBusy ? null : _openAdjustmentRequestDialog,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Solicitar ajuste'),
          ),
        ],
      ],
    );

    return NavalgoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    clockBlock,
                    const SizedBox(height: 18),
                    actions,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: clockBlock),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: actions),
                  ],
                ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NavalgoColors.shell,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: NavalgoColors.border),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _ClockInfoPill(
                  label: 'Total hoy',
                  value: _formatDuration(totalToday),
                  icon: Icons.schedule_rounded,
                ),
                if (activeEntry != null)
                  _ClockInfoPill(
                    label: 'Ubicación actual',
                    value: _workSiteLabel(activeEntry.workSite),
                    icon: Icons.place_outlined,
                  ),
                if (activeEntry?.plannedClockOut != null)
                  _ClockInfoPill(
                    label: 'Cierre previsto',
                    value: _fmtHour(activeEntry!.plannedClockOut!),
                    icon: Icons.alarm_on_outlined,
                  ),
                _ClockInfoPill(
                  label: 'Registros recientes',
                  value: '${_entries.length}',
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            ),
          ),
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

  Future<_ClockInInput?> _selectClockInInput() async {
    return showModalBottomSheet<_ClockInInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ClockInSheet(options: _clockWorkSiteOptions),
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

  Future<void> _editAdjustmentRequest(TimeAdjustmentRequest request) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final result = await showDialog<_TimeAdjustmentRequestInput>(
      context: context,
      builder: (_) => _TimeAdjustmentRequestDialog(
        entries: _entries,
        title: 'Editar ajuste de fichaje',
        submitLabel: 'Guardar cambios',
        initialRequest: request,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() => _adjustmentBusy = true);
    try {
      await context.read<TimeTrackingService>().updateAdjustmentRequest(
        token,
        requestId: request.id,
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
      AppToast.success(context, 'Ajuste actualizado.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo actualizar el ajuste: $e');
    } finally {
      if (mounted) {
        setState(() => _adjustmentBusy = false);
      }
    }
  }

  Future<void> _deleteAdjustmentRequest(TimeAdjustmentRequest request) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar ajuste'),
        content: const Text(
          'Esta solicitud de ajuste se eliminará por completo. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() => _adjustmentBusy = true);
    try {
      await context.read<TimeTrackingService>().deleteAdjustmentRequest(
        token,
        requestId: request.id,
      );
      await _loadEntries();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Ajuste eliminado.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo eliminar el ajuste: $e');
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
              onPressed: () =>
                  Navigator.pop(dialogContext, commentController.text.trim()),
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
  const _TimeAdjustmentRequestDialog({
    required this.entries,
    this.title = 'Solicitar ajuste de fichaje',
    this.submitLabel = 'Enviar solicitud',
    this.initialRequest,
  });

  final List<TimeEntry> entries;
  final String title;
  final String submitLabel;
  final TimeAdjustmentRequest? initialRequest;

  @override
  State<_TimeAdjustmentRequestDialog> createState() =>
      _TimeAdjustmentRequestDialogState();
}

class _TimeAdjustmentRequestDialogState
    extends State<_TimeAdjustmentRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
    final initialRequest = widget.initialRequest;
    if (initialRequest != null) {
      _selectedEntryId = initialRequest.timeEntryId;
      _workDate = DateTime(
        initialRequest.workDate.year,
        initialRequest.workDate.month,
        initialRequest.workDate.day,
      );
      _clockInTime = initialRequest.requestedClockIn == null
          ? null
          : TimeOfDay.fromDateTime(initialRequest.requestedClockIn!.toLocal());
      _clockOutTime = initialRequest.requestedClockOut == null
          ? null
          : TimeOfDay.fromDateTime(
              initialRequest.requestedClockOut!.toLocal(),
            );
      _workSite = initialRequest.workSite;
      _reasonController.text = initialRequest.reason;
    } else {
      _workDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      title: widget.title,
      subtitle:
          'Replica el patrón de Partes para documentar la jornada corregida y dejar trazabilidad clara.',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: widget.submitLabel,
          icon: Icons.send_outlined,
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
              label: 'Fichaje a ajustar',
              caption:
                  'Puedes vincular la corrección a un registro existente o crearla como ajuste independiente.',
              child: DropdownButtonFormField<int?>(
                initialValue: _selectedEntryId,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Fichaje a ajustar',
                  prefixIcon: const Icon(Icons.fact_check_outlined),
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
                          : TimeOfDay.fromDateTime(
                              selectedEntry.clockOut!.toLocal(),
                            );
                      _workSite = selectedEntry.workSite;
                    }
                    _error = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fecha',
              child: NavalgoPickerField(
                label: 'Fecha',
                prefixIcon: const Icon(Icons.event_outlined),
                value: _formatDialogDate(_workDate),
                onTap: () async {
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
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NavalgoFormFieldBlock(
                    label: 'Entrada',
                    child: NavalgoPickerField(
                      label: 'Entrada',
                      prefixIcon: const Icon(Icons.login),
                      value: _clockInTime?.format(context),
                      placeholder: 'Seleccionar hora',
                      onTap: () async {
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
                          _error = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NavalgoFormFieldBlock(
                    label: 'Salida',
                    child: NavalgoPickerField(
                      label: 'Salida',
                      prefixIcon: const Icon(Icons.logout),
                      value: _clockOutTime?.format(context),
                      placeholder: 'Seleccionar hora',
                      onTap: () async {
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
                          _error = null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Tipo de jornada',
              child: DropdownButtonFormField<String>(
                initialValue: _workSite,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Tipo de jornada',
                  prefixIcon: const Icon(Icons.route_outlined),
                ),
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
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Motivo',
              caption:
                  'Explica qué hora debe corregirse y por qué no quedó registrada correctamente.',
              child: TextFormField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Motivo',
                  hint: 'Describe el ajuste solicitado.',
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Debes indicar el motivo del ajuste.';
                  }
                  return null;
                },
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
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
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
    this.canEdit = false,
    this.canDelete = false,
    this.onApprove,
    this.onReject,
    this.onEdit,
    this.onDelete,
  });

  final TimeAdjustmentRequest request;
  final String workDateLabel;
  final String requestedHoursLabel;
  final String workSiteLabel;
  final bool busy;
  final bool canReview;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
          ] else if (canEdit || canDelete) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                if (canDelete)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Eliminar'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClockInInput {
  const _ClockInInput({
    required this.workSite,
    this.plannedClockOut,
  });

  final String workSite;
  final DateTime? plannedClockOut;
}

class _ClockInSheet extends StatefulWidget {
  const _ClockInSheet({required this.options});

  final List<_ClockWorkSiteOption> options;

  @override
  State<_ClockInSheet> createState() => _ClockInSheetState();
}

class _ClockInSheetState extends State<_ClockInSheet> {
  String? _selectedWorkSite;
  TimeOfDay? _plannedClockOutTime;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedWorkSite = widget.options.firstOrNull?.value;
  }

  @override
  Widget build(BuildContext context) {
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
                    'Marca el tipo de jornada y, si lo sabes, la hora aproximada a la que terminarás.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...widget.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ClockWorkSiteSelector(
                  option: option,
                  selected: option.value == _selectedWorkSite,
                  onTap: () {
                    setState(() {
                      _selectedWorkSite = option.value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm_on_outlined),
              title: const Text('Hora prevista de cierre'),
              subtitle: Text(
                _plannedClockOutTime == null
                    ? 'Opcional, para autocerrar la jornada'
                    : _plannedClockOutTime!.format(context),
              ),
              trailing: _plannedClockOutTime == null
                  ? const Icon(Icons.edit_outlined)
                  : IconButton(
                      onPressed: () {
                        setState(() {
                          _plannedClockOutTime = null;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _plannedClockOutTime ??
                      const TimeOfDay(hour: 17, minute: 0),
                );
                if (!mounted || picked == null) {
                  return;
                }
                setState(() {
                  _plannedClockOutTime = picked;
                  _error = null;
                });
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedWorkSite == null ? null : _submit,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Iniciar jornada'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final selectedWorkSite = _selectedWorkSite;
    if (selectedWorkSite == null) {
      return;
    }

    DateTime? plannedClockOut;
    if (_plannedClockOutTime != null) {
      final now = DateTime.now();
      plannedClockOut = DateTime(
        now.year,
        now.month,
        now.day,
        _plannedClockOutTime!.hour,
        _plannedClockOutTime!.minute,
      );
      if (!plannedClockOut.isAfter(now)) {
        setState(() {
          _error =
              'La hora prevista debe ser posterior a la hora actual para hoy.';
        });
        return;
      }
    }

    Navigator.of(context).pop(
      _ClockInInput(
        workSite: selectedWorkSite,
        plannedClockOut: plannedClockOut,
      ),
    );
  }
}

class _ClockWorkSiteSelector extends StatelessWidget {
  const _ClockWorkSiteSelector({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ClockWorkSiteOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? option.accent.withValues(alpha: 0.12)
                : option.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? option.accent.withValues(alpha: 0.32)
                  : option.accent.withValues(alpha: 0.14),
            ),
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
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off_outlined,
                color: option.accent,
              ),
            ],
          ),
        ),
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

class _ClockInfoPill extends StatelessWidget {
  const _ClockInfoPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: NavalgoColors.mist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: NavalgoColors.tide, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

String _fmtHourWithSeconds(DateTime d) {
  final local = d.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

String _fmtLongDate(DateTime d) {
  const weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${weekdays[d.weekday - 1]}, ${d.day} de ${months[d.month - 1]}';
}

String _workSiteLabelForDialog(String workSite) {
  switch (workSite) {
    case 'TRAVEL':
      return 'Viaje';
    default:
      return 'Taller';
  }
}
