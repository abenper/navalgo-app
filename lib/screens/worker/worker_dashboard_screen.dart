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
        (acc, entry) => acc + ((entry.clockOut?.toLocal() ?? now).difference(entry.clockIn.toLocal())),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _balance = balance;
        _myTasks = myWorkOrders.where((item) => item.status == 'NEW' || item.status == 'IN_PROGRESS').length;
        _urgentTasks = myWorkOrders.where((item) => item.priority == 'URGENT').length;
        _hoursToday = _formatDuration(totalToday);
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

  @override
  Widget build(BuildContext context) {
    final roundedVacationDays = (_balance?.availableDays ?? 0).round();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tu jornada de hoy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No se pudo cargar dashboard: $_error'),
                ),
              )
            else
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard('Mis Tareas Hoy', '$_myTasks', Icons.assignment_ind, Colors.blue),
                  _buildStatCard('Urgentes', '$_urgentTasks', Icons.warning, Colors.red),
                  _buildStatCard('Horas Fichadas', _hoursToday, Icons.timer, Colors.green),
                  _buildStatCard('Prox. Ausencia', '$roundedVacationDays dias', Icons.event_available, Colors.purple),
                ],
              ),
            if (_balance != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.lightBlue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Devengados: ${_balance!.accruedDays.toStringAsFixed(1)} • Consumidos: ${_balance!.consumedDays}',
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
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
}
