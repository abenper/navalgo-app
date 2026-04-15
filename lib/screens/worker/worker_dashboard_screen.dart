import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leave_request.dart';
import '../../services/leave_service.dart';
import '../../services/time_tracking_service.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;

    if (token == null || workerId == null) {
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
      final leaveService = context.read<LeaveService>();
      final workOrdersVm = context.read<WorkOrdersViewModel>();
      final timeService = context.read<TimeTrackingService>();

      final balance = await leaveService.getLeaveBalance(token, workerId: workerId);
      await workOrdersVm.loadWorkOrders(workerId: workerId);
      final myWorkOrders = workOrdersVm.workOrders;

      final entries = await timeService.getByWorker(token, workerId: workerId);
      final now = DateTime.now();
      final todayEntries = entries.where((entry) {
        final d = entry.clockIn.toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();
      final totalToday = todayEntries.fold<Duration>(
        Duration.zero,
        (acc, entry) =>
            acc + ((entry.clockOut?.toLocal() ?? now).difference(entry.clockIn.toLocal())),
      );

      if (!mounted) return;

      setState(() {
        _balance = balance;
        _myTasks = myWorkOrders
            .where((item) => item.status == 'NEW' || item.status == 'IN_PROGRESS')
            .length;
        _urgentTasks = myWorkOrders.where((item) => item.priority == 'URGENT').length;
        _hoursToday = _formatDuration(totalToday);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerName = context.watch<SessionViewModel>().user?.name ?? '';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Hola, $workerName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Tu jornada de hoy',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No se pudo cargar dashboard: $_error'),
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxis = constraints.maxWidth > 500 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: crossAxis,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.05,
                        children: [
                          _buildStatCard(
                            'Mis Tareas',
                            '$_myTasks',
                            Icons.assignment_ind,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Urgentes',
                            '$_urgentTasks',
                            Icons.warning_amber_rounded,
                            Colors.red,
                          ),
                          _buildStatCard(
                            'Horas Hoy',
                            _hoursToday,
                            Icons.timer_outlined,
                            Colors.green,
                          ),
                          _buildVacCard(_balance),
                        ],
                      );
                    },
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacCard(LeaveBalance? balance) {
    final available = balance?.availableDays.round() ?? 0;
    final accrued = balance?.accruedDays.round() ?? 0;
    final consumed = balance?.consumedDays ?? 0;

    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.beach_access_rounded,
                size: 28, color: Colors.purple.shade700),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$available d',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '+$accrued  −$consumed',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple.shade600),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Vacaciones',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0h 00m';
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }
}
