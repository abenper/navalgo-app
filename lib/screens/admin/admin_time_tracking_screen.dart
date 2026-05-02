import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_entry.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class AdminTimeTrackingScreen extends StatefulWidget {
  const AdminTimeTrackingScreen({super.key});

  @override
  State<AdminTimeTrackingScreen> createState() => _AdminTimeTrackingScreenState();
}

class _AdminTimeTrackingScreenState extends State<AdminTimeTrackingScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  int? _selectedWorkerId;
  List<WorkerTimeTrackingStats> _stats = <WorkerTimeTrackingStats>[];
  List<TimeEntry> _entries = <TimeEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final stats = await service.getWorkerStats(token);
      int? selectedWorkerId = _selectedWorkerId;
      if (stats.isEmpty) {
        selectedWorkerId = null;
      } else if (selectedWorkerId == null ||
          !stats.any((item) => item.workerId == selectedWorkerId)) {
        selectedWorkerId = stats.first.workerId;
      }

      List<TimeEntry> entries = <TimeEntry>[];
      if (selectedWorkerId != null) {
        entries = await service.getByWorker(token, workerId: selectedWorkerId);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
        _selectedWorkerId = selectedWorkerId;
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

  Future<void> _selectWorker(int workerId) async {
    if (_selectedWorkerId == workerId) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _selectedWorkerId = workerId;
      _isLoading = true;
    });

    try {
      final entries = await context.read<TimeTrackingService>().getByWorker(
        token,
        workerId: workerId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo cargar la jornada: $e');
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
    if (_isLoading && _stats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final filteredStats = _stats.where((item) {
      if (query.isEmpty) {
        return true;
      }
      return item.workerName.toLowerCase().contains(query);
    }).toList();
    final selectedStats = _stats.cast<WorkerTimeTrackingStats?>().firstWhere(
      (item) => item?.workerId == _selectedWorkerId,
      orElse: () => filteredStats.isEmpty ? null : filteredStats.first,
    );
    final compact = MediaQuery.sizeOf(context).width < 1120;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NavalgoSectionHeader(
          title: 'Fichajes',
          subtitle:
              'Controla horas, ausencias fuera de vacaciones y corrige jornadas del equipo desde un solo sitio.',
          action: compact
              ? null
              : FilledButton.icon(
                  onPressed: _isLoading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
        ),
        const SizedBox(height: 12),
        NavalgoPanel(
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar trabajador',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              if (compact) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (compact) ...[
          _buildWorkerStrip(filteredStats),
          const SizedBox(height: 16),
          if (selectedStats != null) _buildStatsArea(selectedStats),
          const SizedBox(height: 16),
          _buildEntriesArea(selectedStats),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildWorkerList(filteredStats),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 8,
                child: Column(
                  children: [
                    if (selectedStats != null) _buildStatsArea(selectedStats),
                    const SizedBox(height: 16),
                    _buildEntriesArea(selectedStats),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildWorkerStrip(List<WorkerTimeTrackingStats> stats) {
    if (stats.isEmpty) {
      return const NavalgoPanel(
        child: Text('No hay trabajadores que coincidan con la busqueda.'),
      );
    }

    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = stats[index];
          final selected = item.workerId == _selectedWorkerId;
          return SizedBox(
            width: 250,
            child: _WorkerStatsCard(
              item: item,
              selected: selected,
              onTap: () => _selectWorker(item.workerId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkerList(List<WorkerTimeTrackingStats> stats) {
    if (stats.isEmpty) {
      return const NavalgoPanel(
        child: Text('No hay trabajadores que coincidan con la busqueda.'),
      );
    }

    return Column(
      children: stats
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkerStatsCard(
                item: item,
                selected: item.workerId == _selectedWorkerId,
                onTap: () => _selectWorker(item.workerId),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatsArea(WorkerTimeTrackingStats stats) {
    return NavalgoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stats.workerName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'Hoy',
                value: _formatMinutes(stats.workedMinutesToday),
                icon: Icons.today_outlined,
              ),
              _MetricCard(
                label: 'Mes',
                value: _formatMinutes(stats.workedMinutesThisMonth),
                icon: Icons.calendar_view_month_rounded,
              ),
              _MetricCard(
                label: 'Año',
                value: _formatMinutes(stats.workedMinutesThisYear),
                icon: Icons.calendar_month_rounded,
              ),
              _MetricCard(
                label: 'Ausencias no vacacionales',
                value: '${stats.approvedNonVacationAbsenceDaysThisYear} dia(s)',
                icon: Icons.event_busy_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NavalgoColors.shell,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NavalgoColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                NavalgoStatusChip(
                  label: stats.currentlyClockedIn
                      ? 'Jornada abierta'
                      : 'Jornada cerrada',
                  color: stats.currentlyClockedIn
                      ? NavalgoColors.kelp
                      : NavalgoColors.storm,
                ),
                NavalgoStatusChip(
                  label: _absenceComparisonLabel(stats.absenceVsAveragePercent),
                  color: stats.absenceVsAveragePercent > 0
                      ? NavalgoColors.coral
                      : NavalgoColors.kelp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesArea(WorkerTimeTrackingStats? selectedStats) {
    return NavalgoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedStats == null
                      ? 'Jornadas'
                      : 'Jornadas de ${selectedStats.workerName}',
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
          if (_selectedWorkerId == null)
            const Text('Selecciona un trabajador para ver sus jornadas.')
          else if (_entries.isEmpty)
            const Text('Todavia no hay jornadas registradas para este trabajador.')
          else
            ..._entries.take(30).map(
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

class _WorkerStatsCard extends StatelessWidget {
  const _WorkerStatsCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WorkerTimeTrackingStats item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? NavalgoColors.deepSea : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? NavalgoColors.deepSea : NavalgoColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.workerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : NavalgoColors.deepSea,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Mes: ${_formatMinutes(item.workedMinutesThisMonth)}',
                style: TextStyle(
                  color: selected ? Colors.white70 : NavalgoColors.storm,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.currentlyClockedIn ? 'Jornada abierta' : 'Jornada cerrada',
                style: TextStyle(
                  color: selected ? Colors.white70 : NavalgoColors.storm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: NavalgoColors.tide),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
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
                label: const Text('Editar'),
              ),
            ],
          ),
          if (entry.autoCloseReason != null) ...[
            const SizedBox(height: 10),
            NavalgoStatusChip(
              label: entry.autoCloseReason == 'PLANNED_END_TIME'
                  ? 'Cierre automatico por hora prevista'
                  : 'Cierre automatico fin de dia',
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
      title: const Text('Editar jornada'),
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
    return '${percent.toStringAsFixed(0)}% mas ausencias que la media';
  }
  return '${percent.abs().toStringAsFixed(0)}% menos ausencias que la media';
}
