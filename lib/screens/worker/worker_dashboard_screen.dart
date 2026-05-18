import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../models/leave_request.dart';
import '../../models/time_entry.dart';
import '../../services/budget_service.dart';
import '../../services/leave_service.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../widgets/navalgo_ui.dart';
import '../../widgets/team_leaderboard_panel.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  LeaveBalance? _balance;
  bool _isLoading = true;
  String? _error;
  int _myTasks = 0;
  int _urgentTasks = 0;
  String _hoursToday = '0h 00m';
  int _totalBudgets = 0;
  int _pendingBudgetResponses = 0;
  List<String> _recentBudgetLabels = <String>[];
  List<WorkerTimeTrackingStats> _topWorkers = const <WorkerTimeTrackingStats>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;
    final role = session.user?.role;
    final canSeeParts = role == 'ADMIN' || role == 'WORKER';
    final isCommercial = role == 'COMERCIAL';

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
      final leaveService = context.read<LeaveService>();
      final timeService = context.read<TimeTrackingService>();
      final workOrdersVm = context.read<WorkOrdersViewModel>();
      final budgetService = context.read<BudgetService>();

      final balanceFuture = leaveService.getLeaveBalance(
        token,
        workerId: workerId,
      );
      final entriesFuture = timeService.getByWorker(token, workerId: workerId);
      final workOrdersFuture = canSeeParts
          ? workOrdersVm.loadWorkOrders(workerId: workerId)
          : Future<void>.value();
      final budgetsFuture = isCommercial
          ? budgetService.getBudgets(token)
          : Future<List<Budget>>.value(const <Budget>[]);
      final workerStatsFuture = timeService.getWorkerStats(token);
      await Future.wait<dynamic>([
        balanceFuture,
        entriesFuture,
        workOrdersFuture,
        budgetsFuture,
        workerStatsFuture,
      ]);
      final balance = await balanceFuture;
      final workerStats = await workerStatsFuture;

      var myTasks = 0;
      var urgentTasks = 0;
      if (canSeeParts) {
        final myWorkOrders = workOrdersVm.workOrders;
        myTasks = myWorkOrders
            .where(
              (item) =>
                  (item.status == 'NEW' || item.status == 'IN_PROGRESS') &&
                  (item.signatureUrl == null || item.signatureUrl!.isEmpty),
            )
            .length;
        urgentTasks = myWorkOrders
            .where(
              (item) =>
                  item.priority == 'URGENT' &&
                  (item.signatureUrl == null || item.signatureUrl!.isEmpty),
            )
            .length;
      }

      var totalBudgets = 0;
      var pendingBudgetResponses = 0;
      var recentBudgetLabels = <String>[];
      if (isCommercial) {
        final budgets = await budgetsFuture;
        totalBudgets = budgets.length;
        pendingBudgetResponses = budgets
            .where((budget) => budget.status == 'SENT')
            .length;
        recentBudgetLabels = budgets
            .take(4)
            .map(_formatBudgetLabel)
            .toList(growable: false);
      }

      final entries = await entriesFuture;
      final now = DateTime.now();
      final todayEntries = entries.where((entry) {
        final d = entry.clockIn.toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      final totalToday = todayEntries.fold<Duration>(
        Duration.zero,
        (acc, entry) =>
            acc +
            ((entry.clockOut?.toLocal() ?? now).difference(
              entry.clockIn.toLocal(),
            )),
      );

      if (!mounted) {
        return;
      }

      final topWorkers = workerStats.toList()
        ..sort((a, b) {
          final scoreCompare = b.qualityScore.compareTo(a.qualityScore);
          if (scoreCompare != 0) {
            return scoreCompare;
          }
          return a.workerName.toLowerCase().compareTo(
            b.workerName.toLowerCase(),
          );
        });

      setState(() {
        _balance = balance;
        _myTasks = myTasks;
        _urgentTasks = urgentTasks;
        _hoursToday = _formatDuration(totalToday);
        _totalBudgets = totalBudgets;
        _pendingBudgetResponses = pendingBudgetResponses;
        _recentBudgetLabels = recentBudgetLabels;
        _topWorkers = topWorkers.take(3).toList(growable: false);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerName = context.watch<SessionViewModel>().user?.name ?? '';
    final role = context.watch<SessionViewModel>().user?.role;
    final canSeeParts = role == 'ADMIN' || role == 'WORKER';
    final isCommercial = role == 'COMERCIAL';
    final firstName = workerName.split(' ').first;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  firstName.isEmpty ? 'Hola' : 'Hola, $firstName',
                  style: textTheme.headlineMedium,
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: NavalgoPanel(
                    child: Text('No se pudo cargar el resumen: $_error'),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = isCommercial
                          ? _buildCommercialCards()
                          : _buildWorkerCards(canSeeParts: canSeeParts);
                      final wideColumns = isCommercial ? 3 : 4;
                      final crossAxisCount = constraints.maxWidth >= 980
                          ? wideColumns
                          : (constraints.maxWidth >= 560 ? 2 : 1);
                      final childAspectRatio = crossAxisCount == 4
                          ? 1.58
                          : (crossAxisCount == 3
                                ? 1.72
                                : (crossAxisCount == 2 ? 1.7 : 1.45));

                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: childAspectRatio,
                        ),
                        children: cards,
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: TeamLeaderboardPanel(
                    entries: _topWorkers,
                    token: context.read<SessionViewModel>().token,
                    title: 'Top 3 del equipo',
                    subtitle:
                        'Compites con todo el equipo, incluyendo comerciales y taller.',
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWorkerCards({required bool canSeeParts}) {
    return <Widget>[
      if (canSeeParts)
        _buildStatCard(
          'Mis partes',
          '$_myTasks',
          const Icon(Icons.assignment_ind),
          NavalgoColors.tide,
        ),
      if (canSeeParts)
        _buildStatCard(
          'Urgentes',
          '$_urgentTasks',
          const Icon(Icons.warning_amber_rounded),
          NavalgoColors.coral,
        ),
      _buildStatCard(
        'Horas de hoy',
        _hoursToday,
        const Icon(Icons.timer_outlined),
        NavalgoColors.kelp,
      ),
      _buildVacCard(_balance),
    ];
  }

  List<Widget> _buildCommercialCards() {
    return <Widget>[
      _buildStatCard(
        'Presupuestos totales',
        '$_totalBudgets',
        const Icon(Icons.request_quote_outlined),
        NavalgoColors.sand,
      ),
      _buildStatCard(
        'Pendientes de respuesta',
        '$_pendingBudgetResponses',
        const Icon(Icons.mark_email_unread_outlined),
        NavalgoColors.coral,
      ),
      _buildStatCard(
        'Últimos presupuestos',
        '${_recentBudgetLabels.length}',
        const Icon(Icons.history_toggle_off_rounded),
        NavalgoColors.tide,
        note: _recentBudgetLabels.isEmpty
            ? 'Aún no hay presupuestos creados.'
            : _recentBudgetLabels.join('\n'),
      ),
      _buildStatCard(
        'Horas de hoy',
        _hoursToday,
        const Icon(Icons.timer_outlined),
        NavalgoColors.kelp,
      ),
      _buildVacCard(_balance),
    ];
  }

  Widget _buildStatCard(
    String title,
    String value,
    Widget icon,
    Color color, {
    String? note,
  }) {
    return NavalgoMetricCard(
      label: title,
      value: value,
      icon: icon,
      accent: color,
      note: note,
    );
  }

  Widget _buildVacCard(LeaveBalance? balance) {
    final available = balance?.availableDays ?? 0;
    final bonus = balance?.bonusDays ?? 0;

    return _buildStatCard(
      'Vacaciones',
      '$available d',
      const Icon(Icons.beach_access_rounded),
      NavalgoColors.harbor,
      note: bonus > 0 ? '+$bonus días extra por viaje' : null,
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '0h 00m';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  String _formatBudgetLabel(Budget budget) {
    final status = switch (budget.status) {
      'SENT' => 'Enviado',
      'ACCEPTED' => 'Aceptado',
      'REJECTED' => 'Rechazado',
      'CANCELLED' => 'Cancelado',
      _ => 'Borrador',
    };
    return '${budget.vesselName} · $status';
  }
}
