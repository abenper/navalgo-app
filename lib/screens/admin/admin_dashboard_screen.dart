import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_entry.dart';
import '../../services/leave_service.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../widgets/navalgo_ui.dart';
import '../../widgets/team_leaderboard_panel.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  int _pendingWorkOrders = 0;
  int _urgentWorkOrders = 0;
  int _workersClockedToday = 0;
  List<String> _workersClockedTodayNames = <String>[];
  int _pendingLeaves = 0;
  List<WorkerTimeTrackingStats> _topWorkers = const <WorkerTimeTrackingStats>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No hay sesión activa';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final workOrdersVm = context.read<WorkOrdersViewModel>();
      final leaveService = context.read<LeaveService>();
      final timeTrackingService = context.read<TimeTrackingService>();

      final loadWorkOrdersFuture = workOrdersVm.loadWorkOrders();
      final leavesFuture = leaveService.getLeaveRequests(token);
      final todaySummaryFuture = timeTrackingService.getTodaySummary(token);
      final workerStatsFuture = timeTrackingService.getWorkerStats(token);
      await Future.wait<dynamic>([
        loadWorkOrdersFuture,
        leavesFuture,
        todaySummaryFuture,
        workerStatsFuture,
      ]);
      final leaves = await leavesFuture;
      final todaySummary = await todaySummaryFuture;
      final workerStats = await workerStatsFuture;
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

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingWorkOrders = workOrdersVm.workOrders
            .where(
              (item) =>
                  (item.status == 'NEW' || item.status == 'IN_PROGRESS') &&
                  (item.signatureUrl == null || item.signatureUrl!.isEmpty),
            )
            .length;
        _urgentWorkOrders = workOrdersVm.workOrders
            .where((item) => item.priority == 'URGENT')
            .length;
        _workersClockedToday = todaySummary.clockedWorkersCount;
        _workersClockedTodayNames = todaySummary.workerNames;
        _pendingLeaves = leaves
            .where((item) => item.status == 'PENDING')
            .length;
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              NavalgoPanel(child: Text('No se pudo cargar el panel: $_error'))
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 980
                      ? 4
                      : (constraints.maxWidth >= 560 ? 2 : 1);
                  final childAspectRatio = crossAxisCount == 4
                      ? 1.56
                      : (crossAxisCount == 2 ? 1.65 : 1.45);
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    children: [
                      _buildStatCard(
                        'Partes pendientes',
                        '$_pendingWorkOrders',
                        const Icon(Icons.assignment_outlined),
                        NavalgoColors.sand,
                      ),
                      _buildStatCard(
                        'Partes urgentes',
                        '$_urgentWorkOrders',
                        const Icon(Icons.warning_amber_rounded),
                        NavalgoColors.coral,
                      ),
                      _buildStatCard(
                        'Personal activo hoy',
                        '$_workersClockedToday',
                        const Icon(Icons.engineering),
                        NavalgoColors.tide,
                        note: _workersClockedTodayNames.isEmpty
                            ? null
                            : _workersClockedTodayNames.join('\n'),
                      ),
                      _buildStatCard(
                        'Ausencias pendientes',
                        '$_pendingLeaves',
                        const Icon(Icons.event_busy),
                        NavalgoColors.harbor,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildLeaderboardCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    Widget icon,
    Color color, {
    String? note,
  }) {
    return NavalgoMetricCard(
      label: title,
      value: count,
      icon: icon,
      accent: color,
      note: note,
    );
  }

  Widget _buildLeaderboardCard() {
    final token = context.read<SessionViewModel>().token;

    return TeamLeaderboardPanel(
      entries: _topWorkers,
      token: token,
      title: 'Top 3 del equipo',
      subtitle:
          'Ranking conjunto entre comerciales y taller según la puntuación global de rendimiento.',
    );
  }
}
