import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../services/budget_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key, required this.onOpenBudgets});

  final VoidCallback onOpenBudgets;

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Budget> _budgets = const <Budget>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
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
      final budgets = await context.read<BudgetService>().getBudgets(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _budgets = budgets;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
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
    final firstName =
        context.watch<SessionViewModel>().user?.name.split(' ').first ?? '';
    final pendingBudgets = _budgets
        .where((budget) => budget.status == 'SENT')
        .toList(growable: false);
    final featuredBudget = pendingBudgets.isNotEmpty ? pendingBudgets.first : null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Text(
              firstName.isEmpty ? 'Hola' : 'Hola, $firstName',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              NavalgoPanel(
                child: Text('No se pudo cargar tu área cliente: $_error'),
              )
            else ...[
              if (featuredBudget != null)
                _PendingBudgetHero(
                  budget: featuredBudget,
                  pendingCount: pendingBudgets.length,
                  onOpenBudgets: widget.onOpenBudgets,
                )
              else
                NavalgoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Todo al día',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ahora mismo no tienes presupuestos pendientes de revisar.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 900 ? 3 : 1;
                  final childAspectRatio = crossAxisCount == 3 ? 1.75 : 2.8;
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
                      _MetricCard(
                        label: 'Presupuestos pendientes',
                        value: '${pendingBudgets.length}',
                        icon: Icons.pending_actions_outlined,
                        color: NavalgoColors.coral,
                      ),
                      _MetricCard(
                        label: 'Presupuestos aceptados',
                        value:
                            '${_budgets.where((item) => item.status == 'ACCEPTED').length}',
                        icon: Icons.task_alt_outlined,
                        color: NavalgoColors.kelp,
                      ),
                      _MetricCard(
                        label: 'Presupuestos totales',
                        value: '${_budgets.length}',
                        icon: Icons.request_quote_outlined,
                        color: NavalgoColors.tide,
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingBudgetHero extends StatelessWidget {
  const _PendingBudgetHero({
    required this.budget,
    required this.pendingCount,
    required this.onOpenBudgets,
  });

  final Budget budget;
  final int pendingCount;
  final VoidCallback onOpenBudgets;

  @override
  Widget build(BuildContext context) {
    final amountLabel = budget.amount == null
        ? 'Importe pendiente'
        : '${budget.amount!.toStringAsFixed(2)} ${budget.currency}';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0EA), Color(0xFFFFF8F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NavalgoColors.coral.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: NavalgoColors.coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pendingCount > 1
                  ? 'Tienes $pendingCount presupuestos pendientes de revisar'
                  : 'Tienes 1 presupuesto pendiente de revisar',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: NavalgoColors.coral,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            budget.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: NavalgoColors.deepSea,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${budget.vesselName} · $amountLabel',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Tu presupuesto ya está listo. Entra para revisarlo y responder desde tu área cliente.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpenBudgets,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Revisar presupuesto'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NavalgoMetricCard(
      label: label,
      value: value,
      icon: Icon(icon),
      accent: color,
    );
  }
}
