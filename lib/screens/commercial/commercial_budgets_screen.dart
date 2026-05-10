import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../models/owner.dart';
import '../../models/vessel.dart';
import '../../services/budget_service.dart';
import '../../services/fleet_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/browser_file_download.dart' as browser_file;
import '../../viewmodels/session_view_model.dart';
import '../../widgets/budget_timeline.dart';
import '../../widgets/navalgo_ui.dart';
import '../../widgets/pdf_preview.dart';

class CommercialBudgetsScreen extends StatefulWidget {
  const CommercialBudgetsScreen({super.key});

  @override
  State<CommercialBudgetsScreen> createState() =>
      _CommercialBudgetsScreenState();
}

class _CommercialBudgetsScreenState extends State<CommercialBudgetsScreen> {
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Budget> _budgets = const <Budget>[];
  List<Owner> _owners = const <Owner>[];
  List<Vessel> _vessels = const <Vessel>[];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_handleSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_handleSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadData() async {
    final token = context.read<SessionViewModel>().token;
    final budgetService = context.read<BudgetService>();
    final fleetService = context.read<FleetService>();
    if (token == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final budgetsFuture = budgetService.getBudgets(token);
      final ownersFuture = fleetService.getOwners(token);
      final vesselsFuture = fleetService.getVessels(token);
      await Future.wait<dynamic>([budgetsFuture, ownersFuture, vesselsFuture]);
      final budgets = await budgetsFuture;
      final owners = await ownersFuture;
      final vessels = await vesselsFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _budgets = budgets;
        _owners = owners;
        _vessels = vessels;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _createBudget() async {
    final draft = await showDialog<_BudgetDraft>(
      context: context,
      builder: (_) => _CreateBudgetDialog(owners: _owners, vessels: _vessels),
    );
    if (!mounted || draft == null) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    final budgetService = context.read<BudgetService>();
    if (token == null) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final uploaded = await budgetService.uploadBudgetPdf(
        token,
        ownerId: draft.ownerId,
        vesselId: draft.vesselId,
        ownerName: draft.newClientName,
        vesselName: draft.newVesselName,
        fileName: draft.fileName!,
        bytes: draft.fileBytes!,
      );
      await budgetService.createBudget(
        token,
        ownerId: draft.ownerId,
        vesselId: draft.vesselId,
        contactEmail: draft.contactEmail,
        newClientName: draft.newClientName,
        newVesselName: draft.newVesselName,
        title: draft.title,
        description: draft.description,
        amount: draft.amount,
        currency: draft.currency,
        pdfUrl: uploaded.fileUrl,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Presupuesto creado en borrador y listo para enviar al cliente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el presupuesto: $error')),
      );
      setState(() {
        _isCreating = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isCreating = false;
    });
  }

  Future<void> _reissueBudget(Budget budget) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    try {
      final created = await context.read<BudgetService>().reissueBudget(
        token,
        budgetId: budget.id,
      );
      if (!mounted) {
        return;
      }
      await _editBudget(created);
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se ha creado una nueva oferta en borrador a partir del rechazo.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo rehacer la oferta en este momento.'),
        ),
      );
    }
  }

  Future<void> _editBudget(Budget budget) async {
    final draft = await showDialog<_BudgetDraft>(
      context: context,
      builder: (_) => _CreateBudgetDialog(
        owners: _owners,
        vessels: _vessels,
        initialBudget: budget,
        titleText: 'Editar borrador',
        submitLabel: 'Guardar cambios',
      ),
    );
    if (!mounted || draft == null) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    final budgetService = context.read<BudgetService>();
    if (token == null) {
      return;
    }

    try {
      var pdfUrl = draft.existingPdfUrl ?? budget.pdfUrl;
      if (draft.fileBytes != null &&
          draft.fileBytes!.isNotEmpty &&
          draft.fileName != null) {
        final uploaded = await budgetService.uploadBudgetPdf(
          token,
          ownerId: draft.ownerId,
          ownerName: draft.newClientName,
          fileName: draft.fileName!,
          bytes: draft.fileBytes!,
        );
        pdfUrl = uploaded.fileUrl;
      }

      await budgetService.updateBudgetDraft(
        token,
        budgetId: budget.id,
        ownerId: draft.ownerId,
        contactEmail: draft.contactEmail,
        newClientName: draft.newClientName,
        title: draft.title,
        description: draft.description,
        amount: draft.amount,
        currency: draft.currency,
        pdfUrl: pdfUrl,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Borrador actualizado. Ya puedes revisarlo o enviarlo.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el borrador. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  Future<void> _sendBudget(Budget budget) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    try {
      await context.read<BudgetService>().updateBudgetStatus(
        token,
        budgetId: budget.id,
        status: 'SENT',
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            budget.ownerEmail == null || budget.ownerEmail!.isEmpty
                ? 'El cliente no tiene correo para recibir el presupuesto.'
                : budget.clientHasAccount
                ? 'Presupuesto enviado al cliente por correo.'
                : 'Presupuesto enviado. El cliente recibirá también la invitación para darse de alta.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el presupuesto: $error')),
      );
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar presupuesto'),
          content: Text(
            '¿Seguro que quieres eliminar el presupuesto "${budget.title}"? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    try {
      await context.read<BudgetService>().deleteBudget(
        token,
        budgetId: budget.id,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Presupuesto eliminado.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el presupuesto: $error')),
      );
    }
  }

  Future<void> _showPdfPreview(
    String objectUrl,
    Uint8List bytes,
    String title,
  ) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        final dialogWidth = math.min(
          MediaQuery.of(context).size.width * 0.92,
          900.0,
        );
        return AlertDialog(
          title: const Text('Vista previa de PDF'),
          content: SizedBox(
            width: dialogWidth,
            height: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PdfPreviewWidget(pdfUrl: objectUrl),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () async {
                await browser_file.downloadFileBytes(
                  bytes,
                  fileName: '$title.pdf',
                  mimeType: 'application/pdf',
                );
              },
              child: const Text('Descargar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPdf(Budget budget) async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    if (token == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await context.read<BudgetService>().downloadBudgetPdf(
        token,
        budget.pdfUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      final objectUrl = browser_file.createObjectUrlFromBytes(
        bytes,
        mimeType: 'application/pdf',
      );
      if (objectUrl == null) {
        throw Exception('No se pudo generar la vista previa del PDF');
      }

      try {
        await _showPdfPreview(objectUrl, bytes, budget.title);
      } finally {
        browser_file.revokeObjectUrl(objectUrl);
      }
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading if error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar el PDF: $error')));
    }
  }

  Iterable<Budget> _filterBudgets(Iterable<Budget> budgets) {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      return budgets;
    }

    String normalize(String? value) => value?.trim().toLowerCase() ?? '';

    return budgets.where((budget) {
      final matchingOwners = _owners.where((item) => item.id == budget.ownerId);
      final owner = matchingOwners.isEmpty ? null : matchingOwners.first;
      final terms = <String>[
        normalize(budget.title),
        normalize(budget.description),
        normalize(budget.ownerName),
        normalize(budget.ownerEmail),
        normalize(budget.vesselName),
        normalize(budget.status),
        normalize(owner?.email),
        normalize(owner?.phone),
        normalize(owner?.documentId),
        budget.amount?.toStringAsFixed(2).toLowerCase() ?? '',
      ];
      return terms.any((term) => term.contains(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleBudgets = _filterBudgets(_budgets).toList(growable: false);
    final sentCount = visibleBudgets
        .where((budget) => budget.status == 'SENT')
        .length;
    final draftCount = visibleBudgets
        .where((budget) => budget.status == 'DRAFT')
        .length;
    final answeredCount = visibleBudgets
        .where(
          (budget) =>
              budget.status == 'ACCEPTED' || budget.status == 'REJECTED',
        )
        .length;
    final draftBudgets = visibleBudgets
        .where((budget) => budget.status == 'DRAFT')
        .toList(growable: false);
    final otherBudgets = visibleBudgets
        .where((budget) => budget.status != 'DRAFT')
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NavalgoPageBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Presupuestos',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    NavalgoGradientButton(
                      label: _isCreating ? 'Creando...' : 'Nuevo presupuesto',
                      icon: _isCreating ? null : Icons.add_circle_outline,
                      onPressed: _isCreating ? null : _createBudget,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 900 ? 3 : 1;
                    final childAspectRatio = crossAxisCount == 3 ? 1.75 : 2.6;
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
                        NavalgoMetricCard(
                          label: 'Borradores',
                          value: '$draftCount',
                          icon: const Icon(Icons.edit_note_outlined),
                          accent: NavalgoColors.tide,
                          note: 'Listos para revisar antes de enviar.',
                        ),
                        NavalgoMetricCard(
                          label: 'Enviados',
                          value: '$sentCount',
                          icon: const Icon(Icons.mark_email_read_outlined),
                          accent: NavalgoColors.sand,
                          note: 'Pendientes de respuesta del cliente.',
                        ),
                        NavalgoMetricCard(
                          label: 'Respondidos',
                          value: '$answeredCount',
                          icon: const Icon(Icons.rule_folder_outlined),
                          accent: NavalgoColors.kelp,
                          note: 'Aceptados o rechazados por el cliente.',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Buscar presupuesto',
                    hintText:
                        'Cliente, teléfono, correo, embarcación, título...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Limpiar búsqueda',
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                NavalgoSectionHeader(
                  title: 'Listado',
                  subtitle: draftCount > 0
                      ? 'Los borradores se muestran separados para que no se queden sin enviar por error.'
                      : 'Desde aqu\u00ED controlas el estado del presupuesto y abres el PDF cuando lo necesites.',
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  NavalgoPanel(child: Text(_error!))
                else if (_budgets.isEmpty)
                  const NavalgoPanel(
                    child: Text(
                      'A\u00FAn no hay presupuestos creados. Usa el bot\u00F3n de arriba para preparar el primero.',
                    ),
                  )
                else if (visibleBudgets.isEmpty)
                  NavalgoPanel(
                    child: Text(
                      'No hemos encontrado presupuestos que coincidan con "${_searchCtrl.text.trim()}".',
                    ),
                  )
                else ...[
                  if (draftBudgets.isNotEmpty) ...[
                    NavalgoPanel(
                      tint: NavalgoColors.sand.withValues(alpha: 0.16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: NavalgoColors.sand.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.edit_document,
                              color: NavalgoColors.deepSea,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draftCount == 1
                                      ? 'Tienes 1 borrador pendiente de enviar'
                                      : 'Tienes $draftCount borradores pendientes de enviar',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: NavalgoColors.deepSea,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Revísalos, cambia el PDF o el correo si hace falta y envíalos solo cuando estén listos.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: NavalgoColors.deepSea),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const NavalgoSectionHeader(
                      title: 'Borradores pendientes',
                      subtitle:
                          'Estos presupuestos todavía no han salido al cliente.',
                    ),
                    const SizedBox(height: 12),
                    ...draftBudgets.map(
                      (budget) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BudgetCard(
                          budget: budget,
                          onOpenPdf: () => _openPdf(budget),
                          onEdit: () => _editBudget(budget),
                          onSend: () => _sendBudget(budget),
                          onDelete: () => _deleteBudget(budget),
                        ),
                      ),
                    ),
                  ],
                  if (otherBudgets.isNotEmpty) ...[
                    if (draftBudgets.isNotEmpty) const SizedBox(height: 8),
                    const NavalgoSectionHeader(
                      title: 'Enviados y resueltos',
                      subtitle:
                          'Aqu\u00ED se quedan los presupuestos que ya salieron al cliente o que ya recibieron respuesta.',
                    ),
                    const SizedBox(height: 12),
                    ...otherBudgets.map(
                      (budget) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BudgetCard(
                          budget: budget,
                          onOpenPdf: () => _openPdf(budget),
                          onReissue: budget.status == 'REJECTED'
                              ? () => _reissueBudget(budget)
                              : null,
                          onDelete: () => _deleteBudget(budget),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.onOpenPdf,
    this.onEdit,
    this.onReissue,
    this.onSend,
    this.onDelete,
  });

  final Budget budget;
  final VoidCallback onOpenPdf;
  final VoidCallback? onEdit;
  final VoidCallback? onReissue;
  final VoidCallback? onSend;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final amountLabel = budget.amount == null
        ? 'Importe pendiente'
        : '${budget.amount!.toStringAsFixed(2)} ${budget.currency}';
    final isDraft = budget.status == 'DRAFT';

    return NavalgoPanel(
      tint: isDraft ? NavalgoColors.sand.withValues(alpha: 0.12) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDraft) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: NavalgoColors.deepSea,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Borrador no enviado. Aún puedes cambiar el PDF, el correo y revisar el contenido antes de mandarlo.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: NavalgoColors.deepSea,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${budget.ownerName} - ${budget.vesselName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NavalgoColors.storm,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: budget.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amountLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (budget.description != null && budget.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(budget.description!),
          ],
          if (budget.originBudgetId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Esta oferta rehace un presupuesto rechazado anteriormente.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavalgoColors.harbor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!budget.clientHasAccount) ...[
            const SizedBox(height: 8),
            Text(
              'Este cliente aún no tiene cuenta. Al enviarlo, recibirá un correo para darse de alta con este mismo email.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavalgoColors.coral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (budget.vesselName.trim().toLowerCase() ==
              'embarcacion pendiente de registrar') ...[
            const SizedBox(height: 8),
            Text(
              'La embarcación real quedará vinculada cuando el cliente entre y la seleccione o la registre.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NavalgoColors.sand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Ver PDF'),
              ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar borrador'),
                ),
              if (onSend != null)
                FilledButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar al cliente'),
                ),
              if (onReissue != null)
                OutlinedButton.icon(
                  onPressed: onReissue,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('Rehacer oferta'),
                ),
              if (onDelete != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NavalgoColors.coral,
                  ),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Eliminar'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Historial',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          BudgetTimeline(events: budget.timeline),
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
    final (label, color) = switch (status) {
      'SENT' => ('Enviado', NavalgoColors.sand),
      'ACCEPTED' => ('Aceptado', NavalgoColors.kelp),
      'REJECTED' => ('Rechazado', Colors.redAccent),
      'CANCELLED' => ('Cancelado', NavalgoColors.storm),
      _ => ('Borrador', NavalgoColors.tide),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CreateBudgetDialog extends StatefulWidget {
  const _CreateBudgetDialog({
    required this.owners,
    required this.vessels,
    this.initialBudget,
    this.titleText = 'Nuevo presupuesto',
    this.submitLabel = 'Crear borrador',
  });

  final List<Owner> owners;
  final List<Vessel> vessels;
  final Budget? initialBudget;
  final String titleText;
  final String submitLabel;

  @override
  State<_CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends State<_CreateBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _newClientNameCtrl = TextEditingController();

  int? _ownerId;
  PlatformFile? _pickedFile;
  List<int>? _pickedFileBytes;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.initialBudget?.ownerId;
    _titleCtrl.text = widget.initialBudget?.title ?? '';
    _descriptionCtrl.text = widget.initialBudget?.description ?? '';
    _contactEmailCtrl.text = widget.initialBudget?.ownerEmail ?? '';
    _searchCtrl.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_handleSearchChanged);
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _contactEmailCtrl.dispose();
    _newClientNameCtrl.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      // Fuerza reconstruccion para aplicar el filtro del combo opcional.
    });
  }

  List<Owner> get _filteredOwners {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.owners;
    }
    return widget.owners.where((owner) {
      final haystacks = <String>[
        owner.displayName,
        owner.email ?? '',
        owner.phone ?? '',
        owner.documentId,
      ];
      return haystacks.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withReadStream: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    if (file.readStream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo PDF.')),
      );
      return;
    }

    // Leer los bytes del stream
    final bytes = <int>[];
    await for (final chunk in file.readStream!) {
      bytes.addAll(chunk);
    }

    setState(() {
      _pickedFile = file;
      // Guardar los bytes leídos en una propiedad adicional
      _pickedFileBytes = bytes;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final fileBytes = _pickedFileBytes;
    if (widget.initialBudget == null &&
        (_pickedFile == null || fileBytes == null || fileBytes.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta un PDF para el presupuesto.')),
      );
      return;
    }
    final contactEmail = _contactEmailCtrl.text.trim();
    if (contactEmail.isEmpty || !contactEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indica un correo electrónico válido para enviar el presupuesto.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _BudgetDraft(
        ownerId: _ownerId,
        vesselId: null,
        contactEmail: contactEmail,
        newClientName:
            _ownerId == null && _newClientNameCtrl.text.trim().isNotEmpty
            ? _newClientNameCtrl.text.trim()
            : null,
        newVesselName: null,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        amount: null,
        currency: 'EUR',
        fileName: _pickedFile?.name,
        fileBytes: fileBytes,
        existingPdfUrl: widget.initialBudget?.pdfUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOwners = _filteredOwners;
    final selectedOwnerId = filteredOwners.any((owner) => owner.id == _ownerId)
        ? _ownerId
        : null;
    final screenSize = MediaQuery.of(context).size;
    final maxDialogWidth = screenSize.width * 0.92;
    final contentMaxHeight = screenSize.height - 140;

    return AlertDialog(
      title: Text(widget.titleText),
      content: SizedBox(
        width: maxDialogWidth > 560 ? 560 : maxDialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: contentMaxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar cliente',
                      hintText: 'Nombre, correo, tel\u00e9fono o documento',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  if (_ownerId != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _ownerId = null;
                            _searchCtrl.clear();
                          });
                        },
                        icon: const Icon(Icons.alternate_email_outlined),
                        label: const Text('Usar solo correo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'owner-${selectedOwnerId ?? 'none'}-${filteredOwners.length}',
                    ),
                    initialValue: selectedOwnerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cliente',
                      hintText: 'Opcional: selecciona un cliente existente',
                    ),
                    items: filteredOwners
                        .map(
                          (owner) => DropdownMenuItem<int>(
                            value: owner.id,
                            child: Text(
                              owner.email == null || owner.email!.isEmpty
                                  ? owner.displayName
                                  : '${owner.displayName} - ${owner.email}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _ownerId = value;
                        if (value == null) {
                          return;
                        }
                        final selectedOwner = widget.owners.where(
                          (owner) => owner.id == value,
                        );
                        final owner = selectedOwner.isEmpty
                            ? null
                            : selectedOwner.first;
                        _contactEmailCtrl.text = owner?.email ?? '';
                      });
                    },
                  ),
                  if (_ownerId != null) ...[
                    const SizedBox(height: 12),
                    NavalgoPanel(
                      child: Text(
                        'La embarcación no se asigna desde comercial. El cliente la elegirá o la registrará al entrar en NavalGO antes de abrir el presupuesto.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NavalgoColors.deepSea,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newClientNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del cliente',
                        hintText:
                            'Opcional: si no existe aún, se tomará del correo',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo del cliente',
                      hintText: 'Se usar\u00e1 para enviar el presupuesto',
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Indica un correo electr\u00f3nico';
                      }
                      if (!trimmed.contains('@')) {
                        return 'Introduce un correo electr\u00f3nico v\u00e1lido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'T\u00edtulo'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Introduce un t\u00edtulo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripci\u00f3n',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: SizedBox(
                      width: 240,
                      child: Text(
                        _pickedFile == null
                            ? widget.initialBudget == null
                                  ? 'Adjuntar PDF'
                                  : 'Sustituir PDF'
                            : _pickedFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (widget.initialBudget != null && _pickedFile == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Si no adjuntas un PDF nuevo, se mantendrá el documento actual del borrador.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NavalgoColors.storm,
                      ),
                    ),
                  ],
                  if (filteredOwners.isEmpty &&
                      _searchCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'No hemos encontrado ese cliente. Puedes seguir solo con el correo y el sistema resolverá la cuenta automáticamente. La embarcación la registrará el cliente al entrar.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NavalgoColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

class _BudgetDraft {
  const _BudgetDraft({
    this.ownerId,
    this.vesselId,
    required this.contactEmail,
    this.newClientName,
    this.newVesselName,
    required this.title,
    this.description,
    this.amount,
    required this.currency,
    this.fileName,
    this.fileBytes,
    this.existingPdfUrl,
  });

  final int? ownerId;
  final int? vesselId;
  final String contactEmail;
  final String? newClientName;
  final String? newVesselName;
  final String title;
  final String? description;
  final double? amount;
  final String currency;
  final String? fileName;
  final List<int>? fileBytes;
  final String? existingPdfUrl;
}
