import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/leave_service.dart';
import '../../services/time_tracking_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../widgets/navalgo_ui.dart';

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

      await workOrdersVm.loadWorkOrders();
      final leaves = await leaveService.getLeaveRequests(token);
      final todaySummary = await timeTrackingService.getTodaySummary(token);

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
            .where(
              (item) => item.status == 'NEW' || item.status == 'IN_PROGRESS',
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
            const NavalgoPageIntro(
              eyebrow: 'RESUMEN OPERATIVO',
              title:
                  'Supervisa carga de trabajo, equipo y avisos desde un mismo panel.',
              subtitle:
                  'Consulta partes pendientes, fichajes del día y ausencias por revisar al inicio de la jornada.',
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              NavalgoPanel(child: Text('No se pudo cargar el panel: $_error'))
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 4
                      : (constraints.maxWidth > 520 ? 2 : 1);
                  final childAspectRatio = crossAxisCount == 1 ? 2.1 : 1.15;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStatCard(
                        'Partes Pendientes',
                        '$_pendingWorkOrders',
                        Icons.assignment_outlined,
                        NavalgoColors.sand,
                      ),
                      _buildStatCard(
                        'Partes Urgentes',
                        '$_urgentWorkOrders',
                        Icons.warning_amber_rounded,
                        NavalgoColors.coral,
                      ),
                      _buildStatCard(
                        'Mecánicos activos hoy',
                        '$_workersClockedToday',
                        Icons.engineering,
                        NavalgoColors.tide,
                        note: _workersClockedTodayNames.isEmpty
                            ? 'Sin fichajes registrados hoy.'
                            : _workersClockedTodayNames.join(', '),
                      ),
                      _buildStatCard(
                        'Ausencias Pendientes',
                        '$_pendingLeaves',
                        Icons.event_busy,
                        NavalgoColors.harbor,
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 18),
            NavalgoPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: NavalgoColors.foam,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.event_available,
                    color: NavalgoColors.kelp,
                  ),
                ),
                title: const Text('Ausencias aprobadas hoy'),
                subtitle: const Text(
                  'Visión rápida de asignaciones ya confirmadas.',
                ),
                trailing: Text(
                  '$_approvedLeavesToday',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
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
}
