import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leave_request.dart';
import '../../services/leave_service.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../widgets/navalgo_ui.dart';

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
      final workOrdersVm = context.read<WorkOrdersViewModel>();
      final timeService = context.read<TimeTrackingService>();

      final balance = await leaveService.getLeaveBalance(
        token,
        workerId: workerId,
      );
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
            acc +
            ((entry.clockOut?.toLocal() ?? now).difference(
              entry.clockIn.toLocal(),
            )),
      );

      if (!mounted) return;

      setState(() {
        _balance = balance;
        _myTasks = myWorkOrders
            .where(
              (item) =>
                  (item.status == 'NEW' || item.status == 'IN_PROGRESS') &&
                  (item.signatureUrl == null || item.signatureUrl!.isEmpty),
            )
            .length;
        _urgentTasks = myWorkOrders
            .where(
              (item) =>
                  item.priority == 'URGENT' &&
                  (item.signatureUrl == null || item.signatureUrl!.isEmpty),
            )
            .length;
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
    final firstName = workerName.split(' ').first;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
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
                      final crossAxisCount = constraints.maxWidth >= 980
                          ? 4
                          : (constraints.maxWidth >= 560 ? 2 : 1);
                      final childAspectRatio = crossAxisCount == 4
                          ? 1.58
                          : (crossAxisCount == 2 ? 1.95 : 2.5);
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: childAspectRatio,
                        ),
                        children: [
                          _buildStatCard(
                            'Mis partes',
                            '$_myTasks',
                            const Icon(Icons.assignment_ind),
                            NavalgoColors.tide,
                          ),
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
    if (duration.isNegative) return '0h 00m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }
}
