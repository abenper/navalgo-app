import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/leave_request.dart';
import '../../models/worker_profile.dart';
import '../../services/leave_service.dart';
import '../../services/worker_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

const List<String> _leaveReasons = [
  'Vacaciones',
  'Médico',
  'Maternidad/Paternidad',
  'Asuntos Propios',
  'Otros',
];

const List<String> _calendarWeekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const String _otherLeaveReason = 'Otros';
final DateFormat _shortDateFormatter = DateFormat('d MMM yyyy', 'es');
final DateFormat _monthLabelFormatter = DateFormat('MMMM yyyy', 'es');
final DateFormat _longDayFormatter = DateFormat("EEEE d 'de' MMMM", 'es');

bool _isOtherReason(String reason) {
  final normalized = reason.trim().toLowerCase();
  return normalized == 'otro' ||
      normalized == 'otros' ||
      normalized.startsWith('otro:') ||
      normalized.startsWith('otros:') ||
      !_leaveReasons.contains(reason);
}

String _selectorReason(String? initialReason) {
  final reason = initialReason?.trim();
  if (reason == null || reason.isEmpty) {
    return 'Vacaciones';
  }
  if (!_isOtherReason(reason)) {
    return reason;
  }
  return _otherLeaveReason;
}

String _extractOtherReason(String? initialReason) {
  final reason = initialReason?.trim() ?? '';
  if (reason.isEmpty) {
    return '';
  }
  final lower = reason.toLowerCase();
  if (lower.startsWith('otro:') || lower.startsWith('otros:')) {
    final separator = reason.indexOf(':');
    if (separator != -1 && separator + 1 < reason.length) {
      return reason.substring(separator + 1).trim();
    }
  }
  if (_leaveReasons.contains(reason)) {
    return '';
  }
  return reason;
}

String _composeReason(String selectedReason, String otherReason) {
  if (selectedReason != _otherLeaveReason) {
    return selectedReason;
  }

  final trimmed = otherReason.trim();
  return trimmed.isEmpty ? _otherLeaveReason : 'Otros: $trimmed';
}

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
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedCalendarDay = DateTime.now();

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
        _error = 'No hay sesión activa';
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
        final visibleRequests = requests
            .where(
              (item) => item.status == 'APPROVED' || item.status == 'PENDING',
            )
            .toList();
        if (visibleRequests.isNotEmpty) {
          final currentSelection = DateTime(
            _selectedCalendarDay.year,
            _selectedCalendarDay.month,
            _selectedCalendarDay.day,
          );
          final hasSelectedDayData = _requestsForDay(
            currentSelection,
            source: visibleRequests,
          ).isNotEmpty;
          if (!hasSelectedDayData) {
            _selectedCalendarDay = visibleRequests.first.startDate;
          }
        }
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
        initialRange: DateTimeRange(
          start: request.startDate,
          end: request.endDate,
        ),
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
        const SnackBar(
          content: Text('Solicitud editada. Estado: pendiente de confirmación'),
        ),
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
        title: const Text('Eliminar solicitud'),
        content: const Text(
          'Esta acción cancelará la solicitud actual. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
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
        const SnackBar(content: Text('Solicitud eliminada.')),
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
        const SnackBar(
          content: Text('Ausencia asignada y aceptada correctamente'),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo asignar la vacación: $e')),
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

  List<LeaveRequestModel> get _calendarRequests => _requests
      .where((item) => item.status == 'APPROVED' || item.status == 'PENDING')
      .toList();

  List<LeaveRequestModel> _requestsForDay(
    DateTime day, {
    List<LeaveRequestModel>? source,
  }) {
    final currentDay = DateTime(day.year, day.month, day.day);
    return (source ?? _calendarRequests).where((item) {
      final start = DateTime(
        item.startDate.year,
        item.startDate.month,
        item.startDate.day,
      );
      final end = DateTime(
        item.endDate.year,
        item.endDate.month,
        item.endDate.day,
      );
      return !currentDay.isBefore(start) && !currentDay.isAfter(end);
    }).toList()..sort((a, b) {
      final statusOrder = _statusPriority(
        a.status,
      ).compareTo(_statusPriority(b.status));
      if (statusOrder != 0) {
        return statusOrder;
      }
      return a.workerName.compareTo(b.workerName);
    });
  }

  int _statusPriority(String status) {
    switch (status) {
      case 'APPROVED':
        return 0;
      case 'PENDING':
        return 1;
      default:
        return 2;
    }
  }

  String _formatShortDate(DateTime value) {
    return _shortDateFormatter.format(value);
  }

  String _formatMonthLabel(DateTime value) {
    final raw = _monthLabelFormatter.format(value);
    if (raw.isEmpty) {
      return raw;
    }
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _formatLongDay(DateTime value) {
    final raw = _longDayFormatter.format(value);
    if (raw.isEmpty) {
      return raw;
    }
    return raw[0].toUpperCase() + raw.substring(1);
  }

  Widget _buildAdminCalendar() {
    final month = DateTime(_calendarMonth.year, _calendarMonth.month);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final gridStart = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday - 1),
    );
    final selectedItems = _requestsForDay(_selectedCalendarDay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final spacing = compact ? 4.0 : 8.0;
        final cellRatio = compact ? 0.72 : 0.96;
        final cellPadding = compact ? 4.0 : 10.0;

        final calendarGrid = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: _calendarWeekdays
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 4 : 6,
                          ),
                          child: Text(
                            label,
                            style:
                                (compact
                                        ? Theme.of(context).textTheme.labelSmall
                                        : Theme.of(
                                            context,
                                          ).textTheme.labelLarge)
                                    ?.copyWith(color: NavalgoColors.storm),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: cellRatio,
              ),
              itemBuilder: (context, index) {
                final day = gridStart.add(Duration(days: index));
                final items = _requestsForDay(day);
                final approvedCount = items
                    .where((item) => item.status == 'APPROVED')
                    .length;
                final pendingCount = items
                    .where((item) => item.status == 'PENDING')
                    .length;
                final inMonth = day.month == month.month;
                final isSelected = DateUtils.isSameDay(
                  day,
                  _selectedCalendarDay,
                );
                final isToday = DateUtils.isSameDay(day, DateTime.now());

                return InkWell(
                  borderRadius: BorderRadius.circular(compact ? 10 : 18),
                  onTap: () {
                    setState(() {
                      _selectedCalendarDay = day;
                      _calendarMonth = DateTime(day.year, day.month);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.all(cellPadding),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? NavalgoColors.deepSea.withValues(alpha: 0.08)
                          : inMonth
                          ? NavalgoColors.shell
                          : NavalgoColors.mist.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(compact ? 10 : 18),
                      border: Border.all(
                        color: isSelected
                            ? NavalgoColors.harbor
                            : isToday
                            ? NavalgoColors.sand
                            : NavalgoColors.border,
                        width: isSelected || isToday ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${day.day}',
                          style:
                              (compact
                                      ? Theme.of(context).textTheme.labelMedium
                                      : Theme.of(context).textTheme.titleMedium)
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: inMonth
                                        ? NavalgoColors.deepSea
                                        : NavalgoColors.storm,
                                  ),
                        ),
                        if (!compact) const Spacer(),
                        if (approvedCount > 0 || pendingCount > 0)
                          Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              if (approvedCount > 0)
                                compact
                                    ? _CalendarDot(color: NavalgoColors.kelp)
                                    : _CalendarCountBadge(
                                        label: '$approvedCount C',
                                        color: NavalgoColors.kelp,
                                      ),
                              if (pendingCount > 0)
                                compact
                                    ? _CalendarDot(color: NavalgoColors.sand)
                                    : _CalendarCountBadge(
                                        label: '$pendingCount P',
                                        color: NavalgoColors.sand,
                                      ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );

        return NavalgoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendario de ausencias',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Visualiza de un vistazo qué días tienen ausencias pendientes o confirmadas y quién está fuera cada jornada.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Mes anterior',
                          onPressed: () {
                            setState(() {
                              _calendarMonth = DateTime(
                                month.year,
                                month.month - 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            _formatMonthLabel(month),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mes siguiente',
                          onPressed: () {
                            setState(() {
                              _calendarMonth = DateTime(
                                month.year,
                                month.month + 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calendario de ausencias',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Visualiza de un vistazo qué días tienen ausencias pendientes o confirmadas y quién está fuera cada jornada.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mes anterior',
                      onPressed: () {
                        setState(() {
                          _calendarMonth = DateTime(
                            month.year,
                            month.month - 1,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      _formatMonthLabel(month),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mes siguiente',
                      onPressed: () {
                        setState(() {
                          _calendarMonth = DateTime(
                            month.year,
                            month.month + 1,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _CalendarLegendChip(
                    label: 'Confirmadas',
                    color: NavalgoColors.kelp,
                  ),
                  _CalendarLegendChip(
                    label: 'Pendientes',
                    color: NavalgoColors.sand,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              calendarGrid,
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: NavalgoColors.shell,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: NavalgoColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ausencias del ${_formatLongDay(_selectedCalendarDay)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedItems.isEmpty)
                      Text(
                        'No hay ausencias pendientes ni confirmadas para este día.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ...selectedItems.map(_buildSelectedDayItem),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedDayItem(LeaveRequestModel item) {
    final color = _statusColor(item.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NavalgoColors.border),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.event_busy_outlined,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.workerName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(item.reason),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatShortDate(item.startDate)} - ${_formatShortDate(item.endDate)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      NavalgoStatusChip(
                        label: _statusLabel(item.status),
                        color: color,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.event_busy_outlined, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.workerName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(item.reason),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatShortDate(item.startDate)} - ${_formatShortDate(item.endDate)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      NavalgoStatusChip(
                        label: _statusLabel(item.status),
                        color: color,
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  List<Widget> _buildAdminRequestActions(LeaveRequestModel request) {
    final actions = <Widget>[];

    if (request.status == 'PENDING') {
      actions.add(
        FilledButton.tonalIcon(
          onPressed: () => _updateStatus(request.id, 'APPROVED'),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Aceptar'),
        ),
      );
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _updateStatus(request.id, 'REJECTED'),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Rechazar'),
        ),
      );
    } else if (request.status == 'APPROVED') {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _updateStatus(request.id, 'PENDING'),
          icon: const Icon(Icons.hourglass_top_rounded, size: 18),
          label: const Text('En espera'),
        ),
      );
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _updateStatus(request.id, 'REJECTED'),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Rechazar'),
        ),
      );
    } else if (request.status == 'REJECTED') {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _updateStatus(request.id, 'PENDING'),
          icon: const Icon(Icons.hourglass_top_rounded, size: 18),
          label: const Text('En espera'),
        ),
      );
      actions.add(
        FilledButton.tonalIcon(
          onPressed: () => _updateStatus(request.id, 'APPROVED'),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Aceptar'),
        ),
      );
    } else if (request.status == 'CANCELLED') {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _updateStatus(request.id, 'PENDING'),
          icon: const Icon(Icons.hourglass_top_rounded, size: 18),
          label: const Text('En espera'),
        ),
      );
    }

    actions.add(
      OutlinedButton.icon(
        onPressed: () => _cancelRequest(request),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Eliminar'),
      ),
    );

    return actions;
  }

  Widget? _buildWorkerRequestActions(LeaveRequestModel request) {
    if (_isAdmin) {
      return null;
    }

    final canEdit = request.status != 'CANCELLED';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: canEdit ? () => _editRequest(request) : null,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          onPressed: canEdit ? () => _cancelRequest(request) : null,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Eliminar'),
        ),
      ],
    );
  }

  Widget _buildRequestCard(LeaveRequestModel req) {
    final color = _statusColor(req.status);
    final statusLabel = _statusLabel(req.status);
    final workerActions = _buildWorkerRequestActions(req);
    final adminActions = _isAdmin ? _buildAdminRequestActions(req) : const <Widget>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmt(req.startDate)} - ${_fmt(req.endDate)} (${req.requestedDays} días)',
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 6),
                Text(
                  'Trabajador: ${req.workerName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 2),
              Text(
                'Motivo: ${req.reason}',
                maxLines: compact ? 4 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(Icons.event_note, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: details),
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      NavalgoStatusChip(label: statusLabel, color: color),
                    ],
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 12),
                  NavalgoStatusChip(label: statusLabel, color: color),
                ],
                if (adminActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: adminActions,
                  ),
                ],
                if (workerActions != null) ...[
                  const SizedBox(height: 12),
                  workerActions,
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminMobileSummary() {
    final pendingCount = _requests.where((item) => item.status == 'PENDING').length;
    final approvedCount = _requests
        .where((item) => item.status == 'APPROVED')
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: NavalgoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ausencias del equipo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'En móvil mostramos las solicitudes directamente en tarjetas para revisar el equipo más rápido.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                NavalgoStatusChip(
                  label: 'Pendientes $pendingCount',
                  color: NavalgoColors.sand,
                ),
                NavalgoStatusChip(
                  label: 'Aceptadas $approvedCount',
                  color: NavalgoColors.kelp,
                ),
                NavalgoStatusChip(
                  label: 'Total ${_requests.length}',
                  color: NavalgoColors.tide,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarActions() {
    final compact = MediaQuery.sizeOf(context).width < 520;
    if (_isAdmin) {
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _adminAssignRequest,
              icon: const Icon(Icons.event_available),
              label: const Text('Asignar ausencia'),
            ),
          ],
        );
      }

      return Row(
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
              label: const Text('Asignar ausencia'),
            ),
          ),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: _createRequest,
      icon: const Icon(Icons.add),
      label: const Text('Solicitar ausencia'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useAdminCardsLayout =
        _isAdmin && MediaQuery.sizeOf(context).width < 900;

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
            if (_isAdmin && !useAdminCardsLayout) ...[
              _buildAdminCalendar(),
              const SizedBox(height: 18),
            ],
            if (useAdminCardsLayout) _buildAdminMobileSummary(),
            if (_balance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: NavalgoPanel(
                  tint: NavalgoColors.mist,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAdmin
                              ? 'Saldo global de ${_balance!.workerName}'
                              : 'Tus días naturales disponibles',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Disponibles: ${_balance!.availableDays} días naturales',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: NavalgoColors.deepSea,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Base: ${_balance!.accruedDays} • Extra por viaje: ${_balance!.bonusDays} • Reservados: ${_balance!.consumedDays}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ..._requests.map(_buildRequestCard),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: NavalgoPanel(
            padding: const EdgeInsets.all(12),
            child: _buildBottomBarActions(),
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
        return NavalgoColors.kelp;
      case 'REJECTED':
        return NavalgoColors.coral;
      case 'CANCELLED':
        return NavalgoColors.storm;
      default:
        return NavalgoColors.sand;
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
  State<_FormularioAusenciaDialog> createState() =>
      _FormularioAusenciaDialogState();
}

class _FormularioAusenciaDialogState extends State<_FormularioAusenciaDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _otherReasonController;
  late String _motivo;
  DateTimeRange? _fechas;

  @override
  void initState() {
    super.initState();
    _motivo = _selectorReason(widget.initialReason);
    _otherReasonController = TextEditingController(
      text: _extractOtherReason(widget.initialReason),
    );
    _fechas = widget.initialRange;
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechas() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      locale: const Locale('es'),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _fechas,
      helpText: 'Selecciona fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      saveText: 'Guardar',
      fieldStartHintText: 'Inicio',
      fieldEndHintText: 'Fin',
      fieldStartLabelText: 'Fecha de inicio',
      fieldEndLabelText: 'Fecha de fin',
      errorFormatText: 'Fecha inválida',
      errorInvalidText: 'Fecha inválida',
      errorInvalidRangeText: 'El rango no es válido',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: NavalgoColors.tide,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: NavalgoColors.ink,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: NavalgoColors.deepSea,
              ),
            ),
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
    return NavalgoFormDialog(
      title: widget.title,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: widget.submitLabel,
          icon: Icons.event_available_outlined,
          onPressed: () {
            final form = _formKey.currentState;
            if (form == null || !form.validate()) {
              return;
            }
            if (_fechas == null) {
              AppToast.warning(context, 'Selecciona un rango de fechas.');
              return;
            }
            Navigator.pop(
              context,
              _LeaveFormResult(
                reason: _composeReason(_motivo, _otherReasonController.text),
                range: _fechas!,
              ),
            );
          },
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavalgoFormFieldBlock(
              label: 'Tipo de ausencia',
              child: DropdownButtonFormField<String>(
                initialValue: _motivo,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Tipo de ausencia',
                  prefixIcon: const Icon(Icons.fact_check_outlined),
                ),
                items: _leaveReasons
                    .map(
                      (reason) =>
                          DropdownMenuItem(value: reason, child: Text(reason)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _motivo = value ?? _motivo),
              ),
            ),
            if (_motivo == _otherLeaveReason) ...[
              const SizedBox(height: 14),
              NavalgoFormFieldBlock(
                label: '¿Qué ocurre?',
                caption:
                    'Este texto se guardará junto a la solicitud para que el equipo sepa el motivo real.',
                child: TextFormField(
                  controller: _otherReasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: NavalgoFormStyles.inputDecoration(
                    context,
                    label: '¿Qué ocurre?',
                    hint: 'Explica brevemente el motivo de la ausencia.',
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                  ),
                  validator: (value) {
                    if (_motivo != _otherLeaveReason) {
                      return null;
                    }
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Añade un detalle para el motivo "Otros".';
                    }
                    return null;
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Rango de fechas',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _seleccionarFechas,
                child: InputDecorator(
                  decoration: NavalgoFormStyles.inputDecoration(
                    context,
                    label: 'Rango de fechas',
                    hint: 'Toca para seleccionar las fechas',
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    _fechas == null
                        ? 'Toca para seleccionar las fechas'
                        : '${_shortDateFormatter.format(_fechas!.start)} - ${_shortDateFormatter.format(_fechas!.end)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _fechas == null
                          ? NavalgoColors.storm
                          : NavalgoColors.deepSea,
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
}

class _AdminAssignLeaveDialog extends StatefulWidget {
  const _AdminAssignLeaveDialog({required this.workers});

  final List<WorkerProfile> workers;

  @override
  State<_AdminAssignLeaveDialog> createState() =>
      _AdminAssignLeaveDialogState();
}

class _AdminAssignLeaveDialogState extends State<_AdminAssignLeaveDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _otherReasonController;
  String _reason = 'Vacaciones';
  DateTimeRange? _dates;
  late int _workerId;

  @override
  void initState() {
    super.initState();
    _workerId = widget.workers.first.id;
    _otherReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      title: 'Asignar ausencia',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Asignar ausencia',
          icon: Icons.event_busy_outlined,
          onPressed: () {
            final form = _formKey.currentState;
            if (form == null || !form.validate()) {
              return;
            }
            if (_dates == null) {
              AppToast.warning(context, 'Selecciona un rango de fechas.');
              return;
            }
            Navigator.pop(
              context,
              _AdminAssignLeaveFormResult(
                workerId: _workerId,
                reason: _composeReason(_reason, _otherReasonController.text),
                range: _dates!,
              ),
            );
          },
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavalgoFormFieldBlock(
              label: 'Trabajador',
              child: DropdownButtonFormField<int>(
                initialValue: _workerId,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Trabajador',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                items: widget.workers
                    .map(
                      (worker) => DropdownMenuItem<int>(
                        value: worker.id,
                        child: Text(worker.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _workerId = value ?? _workerId),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Motivo',
              child: DropdownButtonFormField<String>(
                initialValue: _reason,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Motivo',
                  prefixIcon: const Icon(Icons.fact_check_outlined),
                ),
                items: _leaveReasons
                    .map(
                      (reason) =>
                          DropdownMenuItem(value: reason, child: Text(reason)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _reason = value ?? _reason),
              ),
            ),
            if (_reason == _otherLeaveReason) ...[
              const SizedBox(height: 14),
              NavalgoFormFieldBlock(
                label: 'Detalle del motivo',
                caption:
                    'Este texto queda visible en el calendario y en la ficha de ausencia.',
                child: TextFormField(
                  controller: _otherReasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: NavalgoFormStyles.inputDecoration(
                    context,
                    label: 'Detalle del motivo',
                    hint: 'Especifica qué sucede con esta ausencia.',
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  validator: (value) {
                    if (_reason != _otherLeaveReason) {
                      return null;
                    }
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Añade un detalle para el motivo "Otros".';
                    }
                    return null;
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fechas reservadas',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickDates,
                child: InputDecorator(
                  decoration: NavalgoFormStyles.inputDecoration(
                    context,
                    label: 'Fechas reservadas',
                    hint: 'Selecciona el rango de fechas',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _dates == null
                        ? 'Selecciona el rango de fechas'
                        : '${_shortDateFormatter.format(_dates!.start)} - ${_shortDateFormatter.format(_dates!.end)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _dates == null
                          ? NavalgoColors.storm
                          : NavalgoColors.deepSea,
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

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('es'),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dates,
      helpText: 'Selecciona fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      saveText: 'Guardar',
      fieldStartHintText: 'Inicio',
      fieldEndHintText: 'Fin',
      fieldStartLabelText: 'Fecha de inicio',
      fieldEndLabelText: 'Fecha de fin',
      errorFormatText: 'Fecha inválida',
      errorInvalidText: 'Fecha inválida',
      errorInvalidRangeText: 'El rango no es válido',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: NavalgoColors.tide,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: NavalgoColors.ink,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: NavalgoColors.deepSea,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dates = picked;
      });
    }
  }
}

class _CalendarLegendChip extends StatelessWidget {
  const _CalendarLegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: NavalgoColors.deepSea),
          ),
        ],
      ),
    );
  }
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CalendarCountBadge extends StatelessWidget {
  const _CalendarCountBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
