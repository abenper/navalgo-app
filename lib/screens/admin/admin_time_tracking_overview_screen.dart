import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_adjustment_request.dart';
import '../../models/time_entry.dart';
import '../../models/worker_profile.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/workers_view_model.dart';
import '../../widgets/navalgo_ui.dart';
import 'admin_time_tracking_screen.dart';

enum _AuditFilter {
  all,
  incidents,
  openShifts,
  pendingAdjustments,
  forcedClosures,
}

class AdminTimeTrackingOverviewScreen extends StatefulWidget {
  const AdminTimeTrackingOverviewScreen({super.key});

  @override
  State<AdminTimeTrackingOverviewScreen> createState() =>
      _AdminTimeTrackingOverviewScreenState();
}

class _AdminTimeTrackingOverviewScreenState
    extends State<AdminTimeTrackingOverviewScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  String? _error;
  _AuditFilter _filter = _AuditFilter.all;
  List<_WorkerAuditSnapshot> _snapshots = <_WorkerAuditSnapshot>[];
  List<_AuditEvent> _events = <_AuditEvent>[];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
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
      final workersVm = context.read<WorkersViewModel>();
      final timeTrackingService = context.read<TimeTrackingService>();
      await workersVm.loadWorkers();
      final workers =
          workersVm.workers
              .where(
                (worker) =>
                    worker.role == 'WORKER' || worker.role == 'COMERCIAL',
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );

      final statsFuture = timeTrackingService.getWorkerStats(token);
      final adjustmentRequestsFuture = timeTrackingService
          .getAdjustmentRequests(token);
      final entryFutures = <Future<List<TimeEntry>>>[
        for (final worker in workers)
          timeTrackingService.getByWorker(token, workerId: worker.id),
      ];

      final results = await Future.wait<dynamic>([
        statsFuture,
        adjustmentRequestsFuture,
        Future.wait<List<TimeEntry>>(entryFutures),
      ]);

      final stats = results[0] as List<WorkerTimeTrackingStats>;
      final requests = results[1] as List<TimeAdjustmentRequest>;
      final entriesByWorkerIndex = results[2] as List<List<TimeEntry>>;

      final statsByWorkerId = <int, WorkerTimeTrackingStats>{
        for (final item in stats) item.workerId: item,
      };
      final requestsByWorkerId = <int, List<TimeAdjustmentRequest>>{};
      for (final request in requests) {
        requestsByWorkerId
            .putIfAbsent(request.workerId, () => <TimeAdjustmentRequest>[])
            .add(request);
      }

      final snapshots = <_WorkerAuditSnapshot>[];
      for (var index = 0; index < workers.length; index++) {
        final worker = workers[index];
        final entries = entriesByWorkerIndex[index];
        final workerRequests =
            requestsByWorkerId[worker.id] ?? const <TimeAdjustmentRequest>[];
        final pendingRequests = workerRequests
            .where((item) => item.isPending)
            .toList();
        final forcedClosures = entries
            .where((entry) => entry.autoCloseReason == 'END_OF_DAY_FORCE_CLOSE')
            .toList();
        final latestEntry = entries.isEmpty ? null : entries.first;
        final openEntry = _firstWhereOrNull(
          entries,
          (entry) => entry.clockOut == null,
        );

        snapshots.add(
          _WorkerAuditSnapshot(
            worker: worker,
            stats:
                statsByWorkerId[worker.id] ??
                WorkerTimeTrackingStats(
                  workerId: worker.id,
                  workerName: worker.fullName,
                  workerRole: worker.role,
                  photoUrl: worker.photoUrl,
                  qualityScore: 0,
                  currentlyClockedIn: openEntry != null,
                  workedMinutesToday: 0,
                  workedMinutesThisMonth: 0,
                  workedMinutesThisYear: 0,
                  approvedNonVacationAbsenceDaysThisYear: 0,
                  absenceVsAveragePercent: 0,
                ),
            entries: entries,
            latestEntry: latestEntry,
            openEntry: openEntry,
            pendingAdjustmentCount: pendingRequests.length,
            adjustmentHistoryCount: workerRequests.length,
            forcedClosureCount: forcedClosures.length,
            latestPendingRequestAt: pendingRequests
                .map((item) => item.createdAt ?? item.workDate)
                .fold<DateTime?>(null, (current, value) {
                  if (current == null || value.isAfter(current)) {
                    return value;
                  }
                  return current;
                }),
            latestForcedClosureAt: forcedClosures
                .map((entry) => entry.autoClosedAt ?? entry.clockOut)
                .whereType<DateTime>()
                .fold<DateTime?>(null, (current, value) {
                  if (current == null || value.isAfter(current)) {
                    return value;
                  }
                  return current;
                }),
          ),
        );
      }

      snapshots.sort((a, b) {
        final incidentCompare = b.incidentScore.compareTo(a.incidentScore);
        if (incidentCompare != 0) {
          return incidentCompare;
        }
        return a.worker.fullName.toLowerCase().compareTo(
          b.worker.fullName.toLowerCase(),
        );
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _snapshots = snapshots;
        _events = _buildEvents(snapshots);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openWorkerDetail(WorkerProfile worker) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkerJornadaAdjustmentScreen(worker: worker),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _snapshots.isEmpty) {
      return const Scaffold(
        body: NavalgoPageBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null && _snapshots.isEmpty) {
      return Scaffold(
        body: NavalgoPageBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: NavalgoPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: NavalgoColors.coral,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo cargar el control horario global.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    NavalgoGradientButton(
                      label: 'Reintentar',
                      icon: Icons.refresh_rounded,
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final filteredSnapshots = _filteredSnapshots;
    final filteredEvents = _filteredEvents(filteredSnapshots);
    final overview = _buildOverview(filteredSnapshots);

    return Scaffold(
      body: NavalgoPageBackground(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NavalgoPageIntro(
                eyebrow: 'CONTROL HORARIO',
                title: 'Vista global de plantilla',
                subtitle:
                    'Pensada para inspección y revisión rápida. Solo se resaltan incidencias reales: jornadas abiertas, cierres forzados y ajustes pendientes.',
                trailing: _OverviewLegend(overview: overview),
              ),
              const SizedBox(height: 18),
              _buildMetrics(context, overview),
              const SizedBox(height: 18),
              _buildFilters(context),
              const SizedBox(height: 18),
              _buildEventsSection(context, filteredEvents),
              const SizedBox(height: 18),
              _buildWorkersSection(context, filteredSnapshots),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, _OverviewData overview) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.55,
          children: [
            NavalgoMetricCard(
              label: 'Trabajadores monitorizados',
              value: '${overview.totalWorkers}',
              icon: const Icon(Icons.groups_2_outlined),
              accent: NavalgoColors.tide,
              note: 'Incluye perfiles técnicos y comerciales activos.',
            ),
            NavalgoMetricCard(
              label: 'Jornadas abiertas',
              value: '${overview.openShiftWorkers}',
              icon: const Icon(Icons.lock_open_outlined),
              accent: NavalgoColors.kelp,
              note:
                  'Trabajadores que siguen con la jornada abierta ahora mismo.',
            ),
            NavalgoMetricCard(
              label: 'Ajustes pendientes',
              value: '${overview.pendingAdjustments}',
              icon: const Icon(Icons.pending_actions_outlined),
              accent: NavalgoColors.sand,
              note: 'Solicitudes todavía sin revisar por administración.',
            ),
            NavalgoMetricCard(
              label: 'Cierres forzados',
              value: '${overview.forcedClosures}',
              icon: const Icon(Icons.warning_amber_rounded),
              accent: NavalgoColors.coral,
              note:
                  'Solo cuenta cierres por olvido o incidencia. Los autocierres normales por hora prevista no aparecen aquí.',
            ),
            NavalgoMetricCard(
              label: 'Trabajadores con incidencias',
              value: '${overview.workersWithIncidents}',
              icon: const Icon(Icons.fact_check_outlined),
              accent: NavalgoColors.harbor,
              note:
                  'Suma de jornadas abiertas, cierres forzados o ajustes pendientes.',
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(BuildContext context) {
    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NavalgoSectionHeader(
            title: 'Filtros de inspección',
            subtitle:
                'Busca por nombre o correo y enfoca solo los casos que requieren revisión.',
          ),
          const SizedBox(height: 14),
          NavalgoSearchField(
            controller: _searchCtrl,
            label: 'Buscar trabajador',
            hint: 'Nombre o correo',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final filter in _AuditFilter.values)
                ChoiceChip(
                  label: Text(_filterLabel(filter)),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                  selectedColor: _filterColor(filter).withValues(alpha: 0.18),
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _filter == filter
                        ? _filterColor(filter)
                        : NavalgoColors.deepSea,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(BuildContext context, List<_AuditEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavalgoSectionHeader(
          title: 'Actividad relevante',
          subtitle:
              'Lista priorizada de incidencias y revisiones. No incluye autocierres normales por hora prevista.',
          action: OutlinedButton.icon(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar'),
          ),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const NavalgoPanel(
            child: Text(
              'No hay incidencias relevantes con los filtros actuales.',
            ),
          )
        else
          ...events
              .take(12)
              .map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AuditEventCard(
                    event: event,
                    onOpenWorker: () =>
                        _openWorkerDetail(event.snapshot.worker),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildWorkersSection(
    BuildContext context,
    List<_WorkerAuditSnapshot> snapshots,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavalgoSectionHeader(
          title: 'Plantilla completa',
          subtitle:
              'Resumen por trabajador para revisar horas, ausencias, ajustes y cierres forzados sin entrar uno por uno.',
        ),
        const SizedBox(height: 12),
        if (snapshots.isEmpty)
          const NavalgoPanel(
            child: Text(
              'No hay trabajadores que coincidan con el filtro actual.',
            ),
          )
        else
          ...snapshots.map(
            (snapshot) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _WorkerAuditCard(
                snapshot: snapshot,
                onOpenDetail: () => _openWorkerDetail(snapshot.worker),
              ),
            ),
          ),
      ],
    );
  }

  _OverviewData _buildOverview(List<_WorkerAuditSnapshot> snapshots) {
    var openShiftWorkers = 0;
    var pendingAdjustments = 0;
    var forcedClosures = 0;
    var workersWithIncidents = 0;

    for (final snapshot in snapshots) {
      if (snapshot.isCurrentlyClockedIn) {
        openShiftWorkers++;
      }
      pendingAdjustments += snapshot.pendingAdjustmentCount;
      forcedClosures += snapshot.forcedClosureCount;
      if (snapshot.hasIncidents) {
        workersWithIncidents++;
      }
    }

    return _OverviewData(
      totalWorkers: snapshots.length,
      openShiftWorkers: openShiftWorkers,
      pendingAdjustments: pendingAdjustments,
      forcedClosures: forcedClosures,
      workersWithIncidents: workersWithIncidents,
    );
  }

  List<_WorkerAuditSnapshot> get _filteredSnapshots {
    final query = _searchCtrl.text.trim().toLowerCase();

    return _snapshots.where((snapshot) {
      final matchesQuery =
          query.isEmpty ||
          snapshot.worker.fullName.toLowerCase().contains(query) ||
          snapshot.worker.email.toLowerCase().contains(query);
      if (!matchesQuery) {
        return false;
      }

      switch (_filter) {
        case _AuditFilter.all:
          return true;
        case _AuditFilter.incidents:
          return snapshot.hasIncidents;
        case _AuditFilter.openShifts:
          return snapshot.isCurrentlyClockedIn;
        case _AuditFilter.pendingAdjustments:
          return snapshot.pendingAdjustmentCount > 0;
        case _AuditFilter.forcedClosures:
          return snapshot.forcedClosureCount > 0;
      }
    }).toList();
  }

  List<_AuditEvent> _filteredEvents(
    List<_WorkerAuditSnapshot> visibleSnapshots,
  ) {
    final visibleIds = visibleSnapshots.map((item) => item.worker.id).toSet();
    return _events
        .where((event) => visibleIds.contains(event.snapshot.worker.id))
        .toList();
  }

  List<_AuditEvent> _buildEvents(List<_WorkerAuditSnapshot> snapshots) {
    final events = <_AuditEvent>[];

    for (final snapshot in snapshots) {
      if (snapshot.openEntry != null) {
        events.add(
          _AuditEvent(
            snapshot: snapshot,
            type: _AuditEventType.openShift,
            when: snapshot.openEntry!.clockIn,
            title: 'Jornada abierta',
            detail:
                '${snapshot.worker.fullName} sigue con una jornada abierta desde ${_formatDate(snapshot.openEntry!.clockIn)} a las ${_formatHour(snapshot.openEntry!.clockIn)}.',
          ),
        );
      }

      if (snapshot.latestForcedClosureAt != null) {
        events.add(
          _AuditEvent(
            snapshot: snapshot,
            type: _AuditEventType.forcedClosure,
            when: snapshot.latestForcedClosureAt!,
            title: 'Cierre forzado',
            detail:
                '${snapshot.worker.fullName} acumula ${snapshot.forcedClosureCount} cierre(s) forzado(s). El más reciente quedó registrado el ${_formatDate(snapshot.latestForcedClosureAt!)}.',
          ),
        );
      }

      if (snapshot.pendingAdjustmentCount > 0) {
        events.add(
          _AuditEvent(
            snapshot: snapshot,
            type: _AuditEventType.pendingAdjustment,
            when: snapshot.latestRelevantRequestDate,
            title: 'Ajuste pendiente',
            detail:
                '${snapshot.worker.fullName} tiene ${snapshot.pendingAdjustmentCount} solicitud(es) de ajuste pendiente(s) de revisión.',
          ),
        );
      }
    }

    events.sort((a, b) => b.when.compareTo(a.when));
    return events;
  }
}

class _OverviewData {
  const _OverviewData({
    required this.totalWorkers,
    required this.openShiftWorkers,
    required this.pendingAdjustments,
    required this.forcedClosures,
    required this.workersWithIncidents,
  });

  final int totalWorkers;
  final int openShiftWorkers;
  final int pendingAdjustments;
  final int forcedClosures;
  final int workersWithIncidents;
}

class _WorkerAuditSnapshot {
  const _WorkerAuditSnapshot({
    required this.worker,
    required this.stats,
    required this.entries,
    required this.latestEntry,
    required this.openEntry,
    required this.pendingAdjustmentCount,
    required this.adjustmentHistoryCount,
    required this.forcedClosureCount,
    required this.latestPendingRequestAt,
    required this.latestForcedClosureAt,
  });

  final WorkerProfile worker;
  final WorkerTimeTrackingStats stats;
  final List<TimeEntry> entries;
  final TimeEntry? latestEntry;
  final TimeEntry? openEntry;
  final int pendingAdjustmentCount;
  final int adjustmentHistoryCount;
  final int forcedClosureCount;
  final DateTime? latestPendingRequestAt;
  final DateTime? latestForcedClosureAt;

  bool get hasIncidents =>
      isCurrentlyClockedIn ||
      pendingAdjustmentCount > 0 ||
      forcedClosureCount > 0;

  int get incidentScore =>
      (isCurrentlyClockedIn ? 4 : 0) +
      (pendingAdjustmentCount > 0 ? 2 : 0) +
      (forcedClosureCount > 0 ? 1 : 0);

  bool get isCurrentlyClockedIn =>
      openEntry != null || stats.currentlyClockedIn;

  int get workedMinutesToday {
    final now = DateTime.now();
    return _sumWorkedMinutes(
      entries,
      (workDate) =>
          workDate.year == now.year &&
          workDate.month == now.month &&
          workDate.day == now.day,
    );
  }

  int get workedMinutesThisMonth {
    final now = DateTime.now();
    return _sumWorkedMinutes(
      entries,
      (workDate) => workDate.year == now.year && workDate.month == now.month,
    );
  }

  int get workedMinutesThisYear {
    final now = DateTime.now();
    return _sumWorkedMinutes(entries, (workDate) => workDate.year == now.year);
  }

  DateTime get latestRelevantRequestDate =>
      latestPendingRequestAt ?? DateTime.now();
}

enum _AuditEventType { openShift, pendingAdjustment, forcedClosure }

class _AuditEvent {
  const _AuditEvent({
    required this.snapshot,
    required this.type,
    required this.when,
    required this.title,
    required this.detail,
  });

  final _WorkerAuditSnapshot snapshot;
  final _AuditEventType type;
  final DateTime when;
  final String title;
  final String detail;
}

class _OverviewLegend extends StatelessWidget {
  const _OverviewLegend({required this.overview});

  final _OverviewData overview;

  @override
  Widget build(BuildContext context) {
    return NavalgoPanel(
      tint: Colors.white.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lectura rápida',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _LegendLine(
            label: 'Plantilla visible',
            value: '${overview.totalWorkers}',
          ),
          _LegendLine(
            label: 'Con incidencias',
            value: '${overview.workersWithIncidents}',
          ),
          _LegendLine(
            label: 'Ajustes pendientes',
            value: '${overview.pendingAdjustments}',
          ),
          _LegendLine(
            label: 'Cierres forzados',
            value: '${overview.forcedClosures}',
          ),
        ],
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditEventCard extends StatelessWidget {
  const _AuditEventCard({required this.event, required this.onOpenWorker});

  final _AuditEvent event;
  final VoidCallback onOpenWorker;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.type) {
      _AuditEventType.openShift => NavalgoColors.kelp,
      _AuditEventType.pendingAdjustment => NavalgoColors.sand,
      _AuditEventType.forcedClosure => NavalgoColors.coral,
    };
    final icon = switch (event.type) {
      _AuditEventType.openShift => Icons.lock_open_outlined,
      _AuditEventType.pendingAdjustment => Icons.pending_actions_outlined,
      _AuditEventType.forcedClosure => Icons.warning_amber_rounded,
    };

    return NavalgoPanel(
      tint: color.withValues(alpha: 0.06),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    NavalgoStatusChip(
                      label: event.snapshot.worker.fullName,
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(event.detail),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onOpenWorker,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir detalle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerAuditCard extends StatelessWidget {
  const _WorkerAuditCard({required this.snapshot, required this.onOpenDetail});

  final _WorkerAuditSnapshot snapshot;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final worker = snapshot.worker;
    final latestEntry = snapshot.latestEntry;

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
                  worker.role == 'COMERCIAL'
                      ? Icons.support_agent_outlined
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
                    Text(worker.email),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        NavalgoStatusChip(
                          label: worker.role == 'COMERCIAL'
                              ? 'Comercial'
                              : 'Trabajador',
                          color: NavalgoColors.tide,
                        ),
                        if (snapshot.isCurrentlyClockedIn)
                          const NavalgoStatusChip(
                            label: 'Jornada abierta',
                            color: NavalgoColors.kelp,
                          ),
                        if (snapshot.pendingAdjustmentCount > 0)
                          NavalgoStatusChip(
                            label:
                                '${snapshot.pendingAdjustmentCount} ajuste(s) pendiente(s)',
                            color: NavalgoColors.sand,
                          ),
                        if (snapshot.forcedClosureCount > 0)
                          NavalgoStatusChip(
                            label:
                                '${snapshot.forcedClosureCount} cierre(s) forzado(s)',
                            color: NavalgoColors.coral,
                          ),
                        if (!snapshot.hasIncidents)
                          const NavalgoStatusChip(
                            label: 'Sin incidencias visibles',
                            color: NavalgoColors.harbor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Detalle'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniMetricChip(
                label: 'Hoy',
                value: _formatMinutes(snapshot.workedMinutesToday),
                color: NavalgoColors.tide,
              ),
              _MiniMetricChip(
                label: 'Mes',
                value: _formatMinutes(snapshot.workedMinutesThisMonth),
                color: NavalgoColors.harbor,
              ),
              _MiniMetricChip(
                label: 'Ano',
                value: _formatMinutes(snapshot.workedMinutesThisYear),
                color: NavalgoColors.kelp,
              ),
              _MiniMetricChip(
                label: 'Ausencias',
                value:
                    '${snapshot.stats.approvedNonVacationAbsenceDaysThisYear}',
                color: NavalgoColors.coral,
              ),
              _MiniMetricChip(
                label: 'Ajustes',
                value: '${snapshot.adjustmentHistoryCount}',
                color: NavalgoColors.sand,
              ),
            ],
          ),
          if (latestEntry != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NavalgoColors.shell,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: NavalgoColors.border),
              ),
              child: Text(
                _latestEntryLabel(worker, latestEntry),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NavalgoColors.deepSea,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMetricChip extends StatelessWidget {
  const _MiniMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: NavalgoColors.storm),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: NavalgoColors.deepSea,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _filterLabel(_AuditFilter filter) {
  return switch (filter) {
    _AuditFilter.all => 'Todos',
    _AuditFilter.incidents => 'Con incidencias',
    _AuditFilter.openShifts => 'Jornadas abiertas',
    _AuditFilter.pendingAdjustments => 'Ajustes pendientes',
    _AuditFilter.forcedClosures => 'Cierres forzados',
  };
}

Color _filterColor(_AuditFilter filter) {
  return switch (filter) {
    _AuditFilter.all => NavalgoColors.tide,
    _AuditFilter.incidents => NavalgoColors.harbor,
    _AuditFilter.openShifts => NavalgoColors.kelp,
    _AuditFilter.pendingAdjustments => NavalgoColors.sand,
    _AuditFilter.forcedClosures => NavalgoColors.coral,
  };
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

TimeEntry? _firstWhereOrNull(
  List<TimeEntry> entries,
  bool Function(TimeEntry) test,
) {
  for (final entry in entries) {
    if (test(entry)) {
      return entry;
    }
  }
  return null;
}

int _sumWorkedMinutes(
  List<TimeEntry> entries,
  bool Function(DateTime workDate) matchesDate,
) {
  final now = DateTime.now();
  var totalMinutes = 0;

  for (final entry in entries) {
    final clockIn = entry.clockIn.toLocal();
    if (!matchesDate(clockIn)) {
      continue;
    }

    final clockOut = entry.clockOut?.toLocal() ?? now;
    if (!clockOut.isAfter(clockIn)) {
      continue;
    }
    totalMinutes += clockOut.difference(clockIn).inMinutes;
  }

  return totalMinutes;
}

String _latestEntryLabel(WorkerProfile worker, TimeEntry entry) {
  final roleSite = entry.workSite == 'TRAVEL'
      ? 'Viaje'
      : worker.role == 'COMERCIAL'
      ? 'Oficina'
      : 'Taller';
  final clockOutLabel = entry.clockOut == null
      ? 'Abierta'
      : _formatHour(entry.clockOut!);
  return 'Última jornada: ${_formatDate(entry.clockIn)} · $roleSite · ${_formatHour(entry.clockIn)} - $clockOutLabel';
}
