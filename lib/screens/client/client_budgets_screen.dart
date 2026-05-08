import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/budget.dart';
import '../../services/budget_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class ClientBudgetsScreen extends StatefulWidget {
  const ClientBudgetsScreen({super.key});

  @override
  State<ClientBudgetsScreen> createState() => _ClientBudgetsScreenState();
}

class _ClientBudgetsScreenState extends State<ClientBudgetsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
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

  Future<void> _openPdf(String pdfUrl) async {
    final uri = Uri.tryParse(pdfUrl);
    if (uri == null) {
      AppToast.error(context, 'No se pudo abrir el presupuesto.');
      return;
    }
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      AppToast.error(context, 'No se pudo abrir el presupuesto.');
    }
  }

  Future<void> _respondToBudget(Budget budget, String status) async {
    final session = context.read<SessionViewModel>();
    final budgetService = context.read<BudgetService>();
    final observationsCtrl = TextEditingController(
      text: budget.clientObservations ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isAccept = status == 'ACCEPTED';
        return AlertDialog(
          title: Text(
            isAccept ? 'Aceptar presupuesto' : 'Rechazar presupuesto',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAccept
                      ? 'Puedes dejar una observación para el astillero antes de aceptar el presupuesto.'
                      : 'Cuéntanos el motivo para poder revisar o ajustar la propuesta.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: observationsCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    hintText: 'Escribe aquí cualquier comentario',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(isAccept ? 'Aceptar' : 'Rechazar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      observationsCtrl.dispose();
      return;
    }

    final token = session.token;
    if (token == null) {
      observationsCtrl.dispose();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await budgetService.updateBudgetStatus(
        token,
        budgetId: budget.id,
        status: status,
        clientObservations: observationsCtrl.text.trim().isEmpty
            ? null
            : observationsCtrl.text.trim(),
      );
      if (!mounted) {
        return;
      }
      await _loadData();
      if (!mounted) {
        return;
      }
      AppToast.success(
        context,
        status == 'ACCEPTED'
            ? 'Presupuesto aceptado correctamente.'
            : 'Presupuesto rechazado correctamente.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo responder al presupuesto: $error');
    } finally {
      observationsCtrl.dispose();
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingBudgets = _budgets
        .where((budget) => budget.status == 'SENT')
        .toList(growable: false);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              NavalgoPanel(
                child: Text('No se pudieron cargar tus presupuestos: $_error'),
              )
            else if (_budgets.isEmpty)
              NavalgoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aún no tienes presupuestos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cuando te enviemos uno, aparecerá aquí para que puedas revisarlo y responder.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              )
            else ...[
              if (pendingBudgets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: NavalgoPanel(
                    child: Text(
                      pendingBudgets.length == 1
                          ? 'Tienes 1 presupuesto pendiente de revisar.'
                          : 'Tienes ${pendingBudgets.length} presupuestos pendientes de revisar.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: NavalgoColors.coral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ..._budgets.map(
                (budget) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ClientBudgetCard(
                    budget: budget,
                    saving: _isSaving,
                    onOpenPdf: () => _openPdf(budget.pdfUrl),
                    onAccept: budget.status == 'SENT'
                        ? () => _respondToBudget(budget, 'ACCEPTED')
                        : null,
                    onReject: budget.status == 'SENT'
                        ? () => _respondToBudget(budget, 'REJECTED')
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClientBudgetCard extends StatelessWidget {
  const _ClientBudgetCard({
    required this.budget,
    required this.saving,
    required this.onOpenPdf,
    required this.onAccept,
    required this.onReject,
  });

  final Budget budget;
  final bool saving;
  final VoidCallback onOpenPdf;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final amountLabel = budget.amount == null
        ? 'Importe pendiente'
        : '${budget.amount!.toStringAsFixed(2)} ${budget.currency}';

    return NavalgoPanel(
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
                      budget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${budget.vesselName} · $amountLabel',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              _StatusChip(status: budget.status),
            ],
          ),
          if (budget.description != null && budget.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(budget.description!),
          ],
          if (budget.clientObservations != null &&
              budget.clientObservations!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NavalgoColors.foam,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NavalgoColors.border),
              ),
              child: Text(
                'Tus observaciones: ${budget.clientObservations!}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Ver presupuesto'),
              ),
              if (onAccept != null)
                FilledButton.icon(
                  onPressed: saving ? null : onAccept,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Aceptar'),
                ),
              if (onReject != null)
                OutlinedButton.icon(
                  onPressed: saving ? null : onReject,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Rechazar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'SENT' => (label: 'Pendiente', color: NavalgoColors.coral),
      'ACCEPTED' => (label: 'Aceptado', color: NavalgoColors.kelp),
      'REJECTED' => (label: 'Rechazado', color: NavalgoColors.deepSea),
      'CANCELLED' => (label: 'Cancelado', color: NavalgoColors.storm),
      _ => (label: 'Borrador', color: NavalgoColors.tide),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        config.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: config.color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
