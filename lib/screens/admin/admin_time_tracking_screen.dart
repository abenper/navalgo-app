import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_entry.dart';
import '../../models/worker_profile.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../utils/media_url.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class WorkerJornadaAdjustmentScreen extends StatefulWidget {
  const WorkerJornadaAdjustmentScreen({super.key, required this.worker});

  final WorkerProfile worker;

  @override
  State<WorkerJornadaAdjustmentScreen> createState() =>
      _WorkerJornadaAdjustmentScreenState();
}

class _WorkerJornadaAdjustmentScreenState
    extends State<WorkerJornadaAdjustmentScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  WorkerTimeTrackingInsight? _insight;
  List<TimeEntry> _entries = <TimeEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Sesion no valida';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = context.read<TimeTrackingService>();
      final insight = await service.getWorkerInsight(token, workerId: widget.worker.id);
      final entries = await service.getByWorker(token, workerId: widget.worker.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _insight = insight;
        _entries = entries;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editEntry(TimeEntry entry) async {
    final input = await showDialog<_EditTimeEntryInput>(
      context: context,
      builder: (context) => _EditTimeEntryDialog(entry: entry),
    );
    if (!mounted || input == null) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<TimeTrackingService>().updateTimeEntry(
        token,
        entryId: entry.id,
        clockIn: input.clockIn,
        clockOut: input.clockOut,
        plannedClockOut: input.plannedClockOut,
        workSite: input.workSite,
      );
      await _load();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Jornada actualizada.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo actualizar la jornada: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _insight == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && _insight == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajuste de jornada')),
        body: Center(child: Text(_error!)),
      );
    }

    final insight = _insight;
    if (insight == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuste de jornada'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHero(context, insight),
          const SizedBox(height: 18),
          _buildQualityFactors(context, insight),
          const SizedBox(height: 18),
          _buildResolvedTable(context, insight),
          const SizedBox(height: 18),
          _buildEntries(context),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, WorkerTimeTrackingInsight insight) {
    final compact = MediaQuery.sizeOf(context).width < 980;
    final scoreColor = _scoreColor(insight.qualityScore);
    final token = context.read<SessionViewModel>().token;
    final photoUrl = resolveMediaUrl(widget.worker.photoUrl);

    return NavalgoPageIntro(
      eyebrow: 'JORNADA Y RENDIMIENTO',
      title: widget.worker.fullName,
      subtitle:
          'Vista operativa para entender productividad, control de cierres y ajustar jornadas cuando haga falta.',
      trailing: compact
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QualityGauge(score: insight.qualityScore, color: scoreColor),
                const SizedBox(width: 18),
                _WorkerPhotoCard(photoUrl: photoUrl, token: token),
              ],
            ),
      footer: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _QualityGauge(score: insight.qualityScore, color: scoreColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _WorkerPhotoCard(photoUrl: photoUrl, token: token),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHeroPills(insight),
              ],
            )
          : _buildHeroPills(insight),
    );
  }

  Widget _buildHeroPills(WorkerTimeTrackingInsight insight) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        NavalgoStatusChip(
          label: insight.currentlyClockedIn ? 'Jornada abierta' : 'Jornada cerrada',
          color: insight.currentlyClockedIn
              ? NavalgoColors.kelp
              : NavalgoColors.storm,
        ),
        NavalgoStatusChip(
          label: _absenceComparisonLabel(insight.absenceVsAveragePercent),
          color: insight.absenceVsAveragePercent > 0
              ? NavalgoColors.coral
              : NavalgoColors.kelp,
        ),
        NavalgoStatusChip(
          label: widget.worker.speciality?.trim().isNotEmpty == true
              ? widget.worker.speciality!
              : 'Sin especialidad',
          color: NavalgoColors.harbor,
        ),
      ],
    );
  }

  Widget _buildQualityFactors(BuildContext context, WorkerTimeTrackingInsight insight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NavalgoSectionHeader(
          title: 'Calidad del trabajador',
          subtitle:
              'La media combina ausencias no vacacionales, partes resueltos por hora, disciplina de cierre y firmas completas.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            NavalgoMetricCard(
              label: 'Horas hoy',
              value: _formatMinutes(insight.workedMinutesToday),
              icon: const Icon(Icons.today_outlined),
              accent: NavalgoColors.tide,
              note: 'Sesión actual del día',
            ),
            NavalgoMetricCard(
              label: 'Horas este mes',
              value: _formatMinutes(insight.workedMinutesThisMonth),
              icon: const Icon(Icons.calendar_view_month_rounded),
              accent: NavalgoColors.harbor,
              note: 'Carga acumulada del mes',
            ),
            NavalgoMetricCard(
              label: 'Horas este año',
              value: _formatMinutes(insight.workedMinutesThisYear),
              icon: const Icon(Icons.calendar_month_rounded),
              accent: NavalgoColors.kelp,
              note: 'Ritmo global anual',
            ),
            NavalgoMetricCard(
              label: 'Ausencias no vacacionales',
              value: '${insight.approvedNonVacationAbsenceDaysThisYear}',
              icon: const Icon(Icons.event_busy_outlined),
              accent: NavalgoColors.coral,
              note: 'No cuenta vacaciones',
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...insight.qualityFactors.map(
          (factor) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NavalgoPanel(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _scoreColor(factor.score).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        factor.score.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _scoreColor(factor.score),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          factor.label,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(factor.detail),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResolvedTable(BuildContext context, WorkerTimeTrackingInsight insight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NavalgoSectionHeader(
          title: 'Partes y horas',
          subtitle:
              'Aquí ves cuántos partes resuelve y cuánto tiempo le cuesta resolverlos según las jornadas registradas.',
        ),
        const SizedBox(height: 12),
        NavalgoPanel(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Periodo')),
                DataColumn(label: Text('Partes cerrados')),
                DataColumn(label: Text('Horas fichadas')),
                DataColumn(label: Text('Horas imputadas')),
                DataColumn(label: Text('Media h/parte')),
              ],
              rows: insight.resolvedWorkOrderStats
                  .map(
                    (row) => DataRow(
                      cells: [
                        DataCell(Text(row.label)),
                        DataCell(Text('${row.completedWorkOrders}')),
                        DataCell(Text(_formatMinutes(row.workedMinutes))),
                        DataCell(Text(row.loggedLaborHours.toStringAsFixed(1))),
                        DataCell(
                          Text(row.averageWorkedHoursPerOrder.toStringAsFixed(1)),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntries(BuildContext context) {
    return NavalgoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Jornadas del trabajador',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_isSaving)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_entries.isEmpty)
            const Text('Todavía no hay jornadas registradas.')
          else
            ..._entries.take(45).map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TimeEntryAdminCard(
                  entry: entry,
                  onEdit: () => _editEntry(entry),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkerPhotoCard extends StatelessWidget {
  const _WorkerPhotoCard({required this.photoUrl, required this.token});

  final String photoUrl;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    return Container(
      width: 132,
      height: 132,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: hasPhoto
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                headers: buildMediaHeaders(token),
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      child: const Icon(Icons.person_outline_rounded, size: 56, color: Colors.white),
    );
  }
}

class _QualityGauge extends StatelessWidget {
  const _QualityGauge({required this.score, required this.color});

  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: CircularProgressIndicator(
              value: (score.clamp(0, 100)) / 100,
              strokeWidth: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Calidad',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeEntryAdminCard extends StatelessWidget {
  const _TimeEntryAdminCard({
    required this.entry,
    required this.onEdit,
  });

  final TimeEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NavalgoColors.border),
      ),
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
                      _formatDate(entry.clockIn),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entrada ${_formatHour(entry.clockIn)} · Salida ${entry.clockOut == null ? '--:--' : _formatHour(entry.clockOut!)}',
                    ),
                    const SizedBox(height: 4),
                    Text('Tipo: ${entry.workSite == 'TRAVEL' ? 'Viaje' : 'Taller'}'),
                    if (entry.plannedClockOut != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Cierre previsto: ${_formatHour(entry.plannedClockOut!)}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ajustar'),
              ),
            ],
          ),
          if (entry.autoCloseReason != null) ...[
            const SizedBox(height: 10),
            NavalgoStatusChip(
              label: entry.autoCloseReason == 'PLANNED_END_TIME'
                  ? 'Cierre automático por hora prevista'
                  : 'Cierre automático fin de día',
              color: NavalgoColors.sand,
            ),
          ],
        ],
      ),
    );
  }
}

class _EditTimeEntryInput {
  const _EditTimeEntryInput({
    required this.clockIn,
    required this.clockOut,
    required this.plannedClockOut,
    required this.workSite,
  });

  final DateTime clockIn;
  final DateTime? clockOut;
  final DateTime? plannedClockOut;
  final String workSite;
}

class _EditTimeEntryDialog extends StatefulWidget {
  const _EditTimeEntryDialog({required this.entry});

  final TimeEntry entry;

  @override
  State<_EditTimeEntryDialog> createState() => _EditTimeEntryDialogState();
}

class _EditTimeEntryDialogState extends State<_EditTimeEntryDialog> {
  late DateTime _workDate;
  late TimeOfDay _clockInTime;
  TimeOfDay? _clockOutTime;
  TimeOfDay? _plannedClockOutTime;
  late String _workSite;
  String? _error;

  @override
  void initState() {
    super.initState();
    final clockIn = widget.entry.clockIn.toLocal();
    _workDate = DateTime(clockIn.year, clockIn.month, clockIn.day);
    _clockInTime = TimeOfDay.fromDateTime(clockIn);
    _clockOutTime = widget.entry.clockOut == null
        ? null
        : TimeOfDay.fromDateTime(widget.entry.clockOut!.toLocal());
    _plannedClockOutTime = widget.entry.plannedClockOut == null
        ? null
        : TimeOfDay.fromDateTime(widget.entry.plannedClockOut!.toLocal());
    _workSite = widget.entry.workSite;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustar jornada'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Fecha'),
                subtitle: Text(_formatDate(_workDate)),
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
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerTile(
                      label: 'Entrada',
                      value: _clockInTime.format(context),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _clockInTime,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerTile(
                      label: 'Salida',
                      value: _clockOutTime?.format(context) ?? 'Sin cerrar',
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _clockOutTime ??
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
                ],
              ),
              const SizedBox(height: 12),
              _TimePickerTile(
                label: 'Hora prevista de cierre',
                value: _plannedClockOutTime?.format(context) ?? 'No definida',
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _clockOutTime = null;
                      _plannedClockOutTime = null;
                      _error = null;
                    });
                  },
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Limpiar salida y hora prevista'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _workSite,
                decoration: const InputDecoration(
                  labelText: 'Tipo de jornada',
                  prefixIcon: Icon(Icons.route_outlined),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _submit() {
    DateTime combine(TimeOfDay time) {
      return DateTime(
        _workDate.year,
        _workDate.month,
        _workDate.day,
        time.hour,
        time.minute,
      );
    }

    final clockIn = combine(_clockInTime);
    final clockOut = _clockOutTime == null ? null : combine(_clockOutTime!);
    final plannedClockOut = _plannedClockOutTime == null
        ? null
        : combine(_plannedClockOutTime!);

    if (clockOut != null && clockOut.isBefore(clockIn)) {
      setState(() {
        _error = 'La salida no puede ser anterior a la entrada.';
      });
      return;
    }
    if (plannedClockOut != null && plannedClockOut.isBefore(clockIn)) {
      setState(() {
        _error = 'La hora prevista no puede ser anterior a la entrada.';
      });
      return;
    }

    Navigator.of(context).pop(
      _EditTimeEntryInput(
        clockIn: clockIn,
        clockOut: clockOut,
        plannedClockOut: plannedClockOut,
        workSite: _workSite,
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(value),
      ),
    );
  }
}

Color _scoreColor(double score) {
  if (score >= 80) {
    return NavalgoColors.kelp;
  }
  if (score >= 60) {
    return NavalgoColors.harbor;
  }
  if (score >= 40) {
    return NavalgoColors.sand;
  }
  return NavalgoColors.coral;
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')}m';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _formatHour(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _absenceComparisonLabel(double percent) {
  if (percent.abs() < 0.05) {
    return 'En la media del equipo';
  }
  if (percent > 0) {
    return '${percent.toStringAsFixed(0)}% más ausencias que la media';
  }
  return '${percent.abs().toStringAsFixed(0)}% menos ausencias que la media';
}
