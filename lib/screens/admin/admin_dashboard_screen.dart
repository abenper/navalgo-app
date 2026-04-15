import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/leave_service.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../viewmodels/workers_view_model.dart';

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
  int _activeWorkers = 0;
  int _totalWorkers = 0;
  int _pendingLeaves = 0;
  int _approvedLeavesToday = 0;

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
        _error = 'No hay sesion activa';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final workOrdersVm = context.read<WorkOrdersViewModel>();
      final workersVm = context.read<WorkersViewModel>();
      final leaveService = context.read<LeaveService>();

      await workOrdersVm.loadWorkOrders();
      await workersVm.loadWorkers();
      final leaves = await leaveService.getLeaveRequests(token);

      final now = DateTime.now();
      final approvedToday = leaves.where((item) {
        if (item.status != 'APPROVED') {
          return false;
        }
        return item.startDate.year == now.year &&
            item.startDate.month == now.month &&
            item.startDate.day == now.day;
      }).length;

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingWorkOrders = workOrdersVm.workOrders
            .where((item) => item.status == 'NEW' || item.status == 'IN_PROGRESS')
            .length;
        _urgentWorkOrders = workOrdersVm.workOrders
            .where((item) => item.priority == 'URGENT')
            .length;
        _activeWorkers = workersVm.workers.where((item) => item.active).length;
        _totalWorkers = workersVm.workers.length;
        _pendingLeaves = leaves.where((item) => item.status == 'PENDING').length;
        _approvedLeavesToday = approvedToday;
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Resumen General', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  _buildStatCard('Partes Pendientes', '$_pendingWorkOrders', Icons.assignment, Colors.orange),
                  _buildStatCard('Partes Urgentes', '$_urgentWorkOrders', Icons.warning, Colors.red),
                  _buildStatCard('Mecanicos Activos', '$_activeWorkers/$_totalWorkers', Icons.engineering, Colors.blue),
                  _buildStatCard('Ausencias Pendientes', '$_pendingLeaves', Icons.event_busy, Colors.purple),
                ],
              ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_available, color: Colors.green),
                title: const Text('Ausencias aprobadas hoy'),
                trailing: Text(
                  '$_approvedLeavesToday',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
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
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
