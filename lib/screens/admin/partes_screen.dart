import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/owner.dart';
import '../../models/vessel.dart';
import '../../models/worker_profile.dart';
import '../../models/work_order.dart';
import '../../services/material_checklist_template_service.dart';
import '../../services/work_order_material_draft_store.dart';
import '../../services/work_order_material_service.dart';
import '../../services/work_order_media_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/media_url.dart';
import '../../services/work_order_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/fleet_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../viewmodels/workers_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class PartesScreen extends StatefulWidget {
  const PartesScreen({super.key});

  @override
  State<PartesScreen> createState() => _PartesScreenState();
}

class _PartesScreenState extends State<PartesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<SessionViewModel>();
      final fleetViewModel = context.read<FleetViewModel>();
      final workersViewModel = context.read<WorkersViewModel>();
      final workOrdersViewModel = context.read<WorkOrdersViewModel>();
      final user = session.user;
      if (user == null) {
        return;
      }

      try {
        await fleetViewModel.loadFleet();
      } catch (_) {}

      if (user.role == 'ADMIN' || user.canEditWorkOrders) {
        try {
          await workersViewModel.loadWorkers();
        } catch (_) {}
      }

      await workOrdersViewModel.loadWorkOrders(
        workerId: user.role == 'ADMIN' ? null : user.id,
      );
    });
  }

  Future<void> _openCreateDialog() async {
    final fleetVm = context.read<FleetViewModel>();
    final workersVm = context.read<WorkersViewModel>();
    final session = context.read<SessionViewModel>();
    final workOrderService = context.read<WorkOrderService>();
    final workOrdersViewModel = context.read<WorkOrdersViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final token = session.token;
    if (token == null) {
      return;
    }

    if (fleetVm.owners.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Crea un propietario antes de crear partes'),
        ),
      );
      return;
    }

    final input = await showDialog<_CreatePartInput>(
      context: context,
      builder: (_) => _CreatePartDialog(
        owners: fleetVm.owners,
        vessels: fleetVm.vessels,
        workers: workersVm.workers,
      ),
    );

    if (!mounted || input == null) {
      return;
    }

    try {
      await workOrderService.createWorkOrder(
        token,
        title: input.title,
        description: input.description,
        ownerId: input.ownerId,
        vesselId: input.vesselId,
        workerIds: input.workerIds,
        closeDueDate: input.closeDueDate,
        laborHours: input.laborHours,
        materialTemplateId: input.materialTemplateId,
        engineHours: input.engineHours
            .map(
              (item) => <String, dynamic>{
                'engineLabel': item.engineLabel,
                'hours': item.hours,
              },
            )
            .toList(),
        attachmentUrls: input.attachments.map((item) => item.fileUrl).toList(),
        attachments: input.attachments,
        priority: input.priority,
      );

      await workOrdersViewModel.loadWorkOrders(
        workerId: session.user?.role == 'ADMIN' ? null : session.user?.id,
      );
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Parte creado correctamente');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo crear el parte: $e');
    }
  }

  Future<void> _openPartDetails(WorkOrder parte) async {
    final signed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WorkOrderDetailsSheet(initialWorkOrder: parte),
    );

    if (!mounted) {
      return;
    }

    final session = context.read<SessionViewModel>();
    await context.read<WorkOrdersViewModel>().loadWorkOrders(
      workerId: session.user?.role == 'ADMIN' ? null : session.user?.id,
    );

    if (signed == true && mounted) {
      AppToast.success(context, 'Parte firmado correctamente.');
    }
  }

  Future<void> _deleteWorkOrderFromList(WorkOrder parte) async {
    final token = context.read<SessionViewModel>().token;
    final session = context.read<SessionViewModel>();
    final workOrderService = context.read<WorkOrderService>();
    final workOrdersViewModel = context.read<WorkOrdersViewModel>();
    if (token == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar parte'),
        content: Text(
          '¿Seguro que quieres borrar "${parte.title}"? Se eliminarán también firma y adjuntos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    try {
      await workOrderService.deleteWorkOrder(token, workOrderId: parte.id);
      await workOrdersViewModel.loadWorkOrders(
        workerId: session.user?.role == 'ADMIN' ? null : session.user?.id,
      );
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Parte eliminado.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo borrar el parte: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkOrdersViewModel>();
    final isAdmin = context.select<SessionViewModel, bool>(
      (session) => session.user?.role == 'ADMIN',
    );
    final workOrders = vm.workOrders;
    var signedCount = 0;
    var pendingSignatureCount = 0;
    var highPriorityCount = 0;
    for (final item in workOrders) {
      final isSigned = item.signatureUrl?.isNotEmpty ?? false;
      if (isSigned) {
        signedCount += 1;
      } else {
        pendingSignatureCount += 1;
      }
      if (_isHighPriority(item.priority)) {
        highPriorityCount += 1;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NavalgoPageBackground(
        child: vm.isLoading
            ? const SafeArea(child: Center(child: CircularProgressIndicator()))
            : vm.error != null
            ? SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: NavalgoPanel(
                        child: Text(
                          vm.error!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final session = context.read<SessionViewModel>();
                    await vm.loadWorkOrders(
                      workerId: session.user?.role == 'ADMIN'
                          ? null
                          : session.user?.id,
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    itemCount: workOrders.isEmpty ? 1 : workOrders.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1240),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NavalgoPageIntro(
                                  eyebrow: 'OPERACIONES',
                                  title: 'Cuaderno de Taller Naval',
                                  subtitle:
                                      'Gestiona partes, firmas y evidencias con una vista alineada con el resto de formularios del sistema.',
                                  footer: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 720;
                                      final metricWidth = compact
                                          ? constraints.maxWidth
                                          : (constraints.maxWidth - 28) / 3;

                                      return Wrap(
                                        spacing: 14,
                                        runSpacing: 14,
                                        children: [
                                          SizedBox(
                                            width: metricWidth,
                                            child: NavalgoMetricCard(
                                              label: 'Firmados',
                                              value: '$signedCount',
                                              icon: Icons.verified_outlined,
                                              accent: const Color(0xFF3BAA6E),
                                            ),
                                          ),
                                          SizedBox(
                                            width: metricWidth,
                                            child: NavalgoMetricCard(
                                              label: 'Pendientes de firma',
                                              value: '$pendingSignatureCount',
                                              icon: Icons.draw_outlined,
                                              accent: const Color(0xFFD55A4E),
                                            ),
                                          ),
                                          SizedBox(
                                            width: metricWidth,
                                            child: NavalgoMetricCard(
                                              label: 'Prioridad alta',
                                              value: '$highPriorityCount',
                                              icon: Icons.priority_high_rounded,
                                              accent: const Color(0xFFD5A021),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 26),
                                const NavalgoSectionHeader(
                                  title: 'Partes activos',
                                  subtitle:
                                      'Verde para firmados, rojo para pendientes de firma y amarillo para prioridad alta.',
                                ),
                                const SizedBox(height: 18),
                                if (workOrders.isEmpty)
                                  const NavalgoPanel(
                                    child: Text(
                                      'No hay partes para mostrar. Crea un nuevo parte para comenzar.',
                                      style: TextStyle(
                                        color: Color(0xFF48626D),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }

                      final parte = workOrders[index - 1];
                      final isSigned = parte.signatureUrl?.isNotEmpty ?? false;
                      final isHighPriority = _isHighPriority(parte.priority);
                      final accentColor = isSigned
                          ? const Color(0xFF3BAA6E)
                          : const Color(0xFFD55A4E);
                      final surfaceColor = isSigned
                          ? const Color(0xFFF2FBF6)
                          : const Color(0xFFFFF4F3);

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1240),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => _openPartDetails(parte),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: accentColor.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 8,
                                          decoration: BoxDecoration(
                                            color: accentColor,
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                                  left: Radius.circular(24),
                                                ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            22,
                                            20,
                                            22,
                                            20,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          parte.title,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: Color(
                                                                  0xFF0F2530,
                                                                ),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          parte.ownerName,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFF40606C,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isAdmin)
                                                    IconButton(
                                                      tooltip: 'Borrar parte',
                                                      onPressed: () =>
                                                          _deleteWorkOrderFromList(
                                                            parte,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                      ),
                                                      color: const Color(
                                                        0xFF9B2C20,
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.arrow_forward_ios,
                                                    size: 16,
                                                    color: Color(0xFF64808B),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _PartBadge(
                                                    label: isSigned
                                                        ? 'Firmado'
                                                        : 'Pendiente de firma',
                                                    textColor: accentColor,
                                                    backgroundColor: accentColor
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                  ),
                                                  if (isHighPriority)
                                                    const _PartBadge(
                                                      label: 'Prioridad alta',
                                                      textColor: Color(
                                                        0xFF8A6200,
                                                      ),
                                                      backgroundColor: Color(
                                                        0xFFFFF2CC,
                                                      ),
                                                    ),
                                                  if (parte.vesselName !=
                                                          null &&
                                                      parte.vesselName!
                                                          .trim()
                                                          .isNotEmpty)
                                                    _PartBadge(
                                                      label: parte.vesselName!,
                                                      textColor: const Color(
                                                        0xFF1E5166,
                                                      ),
                                                      backgroundColor:
                                                          const Color(
                                                            0xFFDDF0F6,
                                                          ),
                                                    ),
                                                  if (_isOverdueWorkOrder(
                                                    parte,
                                                  ))
                                                    const _PartBadge(
                                                      label: 'Cierre vencido',
                                                      textColor: Color(
                                                        0xFF9B1C1C,
                                                      ),
                                                      backgroundColor: Color(
                                                        0xFFFDE8E8,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                'Mecánicos: ${parte.workerNames.isEmpty ? 'Sin asignar' : parte.workerNames.join(', ')}',
                                                style: const TextStyle(
                                                  color: Color(0xFF4F6771),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Creado: ${_formatDateTime(parte.createdAt)}',
                                                style: const TextStyle(
                                                  color: Color(0xFF738892),
                                                ),
                                              ),
                                              if (parte.closeDueDate != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Cierre: ${_formatCalendarDate(parte.closeDueDate!)}',
                                                  style: TextStyle(
                                                    color: _isOverdueWorkOrder(
                                                          parte,
                                                        )
                                                        ? const Color(
                                                            0xFF9B1C1C,
                                                          )
                                                        : const Color(
                                                            0xFF738892,
                                                          ),
                                                    fontWeight:
                                                        _isOverdueWorkOrder(
                                                          parte,
                                                        )
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
      bottomNavigationBar: isAdmin
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: NavalgoGradientButton(
                        label: 'Nuevo parte',
                        onPressed: _openCreateDialog,
                        icon: Icons.note_add_outlined,
                        expand: true,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  bool _isHighPriority(String priority) {
    return priority == 'HIGH' || priority == 'URGENT';
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year · $hour:$minute';
  }

  bool _isOverdueWorkOrder(WorkOrder workOrder) {
    if (workOrder.closeDueDate == null) {
      return false;
    }
    if (workOrder.status == 'DONE' || workOrder.status == 'CANCELLED') {
      return false;
    }

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final dueDate = workOrder.closeDueDate!;
    final normalizedDueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return normalizedDueDate.isBefore(normalizedToday);
  }
}

String _formatCalendarDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  return '$day/$month/$year';
}

class _WorkOrderDetailsSheet extends StatefulWidget {
  const _WorkOrderDetailsSheet({required this.initialWorkOrder});

  final WorkOrder initialWorkOrder;

  @override
  State<_WorkOrderDetailsSheet> createState() => _WorkOrderDetailsSheetState();
}

class _WorkOrderDetailsSheetState extends State<_WorkOrderDetailsSheet>
    with SingleTickerProviderStateMixin {
  late WorkOrder _workOrder;
  late List<WorkOrderAttachmentItem> _attachments;
  bool _busy = false;
  bool _materialBusy = false;
  bool _signing = false;
  bool _hasMaterialDraft = false;
  late final SignatureController _sigController;
  late final TabController _detailsTabController;
  final GlobalKey _signaturePadKey = GlobalKey();
  final WorkOrderMaterialDraftStore _materialDraftStore =
      WorkOrderMaterialDraftStore();
  late final TextEditingController _observationsCtrl;
  late final TextEditingController _laborHoursCtrl;
  final Map<String, TextEditingController> _engineHoursControllers =
      <String, TextEditingController>{};
  Map<int, bool> _materialChecks = <int, bool>{};
  Timer? _workOrderRefreshTimer;
  bool _workOrderRefreshInFlight = false;

  @override
  void initState() {
    super.initState();
    _workOrder = widget.initialWorkOrder;
    _attachments = _resolveAttachments(_workOrder);
    _sigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _detailsTabController = TabController(length: 2, vsync: this);
    _detailsTabController.addListener(_handleDetailsTabChanged);
    _observationsCtrl = TextEditingController();
    _laborHoursCtrl = TextEditingController();
    _syncWorkInputsFromWorkOrder();
    _syncMaterialChecklistInputsFromWorkOrder();
    _startWorkOrderRealtimeSync();
    Future<void>.microtask(_restoreMaterialChecklistDraft);
  }

  @override
  void dispose() {
    _workOrderRefreshTimer?.cancel();
    _sigController.dispose();
    _detailsTabController.dispose();
    _observationsCtrl.dispose();
    _laborHoursCtrl.dispose();
    for (final controller in _engineHoursControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isAdmin => context.read<SessionViewModel>().user?.role == 'ADMIN';
  bool get _isWorker => context.read<SessionViewModel>().user?.role == 'WORKER';
  bool get _hasEditPermission =>
      context.read<SessionViewModel>().user?.canEditWorkOrders ?? false;
  bool get _canEditPart => _isAdmin || (_isWorker && _hasEditPermission);
  bool get _canUpdateWorkLog => _isAdmin || _isWorker;
  bool get _canReviewMaterial => _isAdmin || _isWorker;
  bool get _isSigned =>
      _workOrder.signatureUrl != null && _workOrder.signatureUrl!.isNotEmpty;
  bool get _canSign => (_isWorker || _isAdmin) && !_isSigned;

  bool get _canDeleteMedia {
    if (_isAdmin || _canEditPart) {
      return true;
    }
    return !_isSigned;
  }

  void _handleDetailsTabChanged() {
    if (_detailsTabController.indexIsChanging ||
        _detailsTabController.index != 1) {
      return;
    }
    _refreshWorkOrderRealtime();
  }

  void _startWorkOrderRealtimeSync() {
    _workOrderRefreshTimer?.cancel();
    _workOrderRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _refreshWorkOrderRealtime();
    });
  }

  Future<void> _refreshWorkOrderRealtime() async {
    if (!mounted ||
        _workOrderRefreshInFlight ||
        _busy ||
        _materialBusy ||
        _signing) {
      return;
    }

    if (_hasMaterialDraft) {
      await _syncPendingMaterialChecklistItems(showErrorToast: false);
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    _workOrderRefreshInFlight = true;
    try {
      final refreshed = await context.read<WorkOrderService>().getWorkOrder(
        token,
        workOrderId: _workOrder.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(refreshed, syncInputs: false);
      });
    } catch (_) {
      // Keep the sheet usable when the periodic refresh fails transiently.
    } finally {
      _workOrderRefreshInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _workOrder.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isHighPriority(_workOrder.priority))
                  const Chip(label: Text('Prioridad alta')),
                if (_isSigned) const Chip(label: Text('Firmado')),
                if (_workOrder.materialChecklist != null)
                  const Chip(label: Text('Revisión de material activa')),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _detailsTabController,
              labelColor: NavalgoColors.deepSea,
              indicatorColor: NavalgoColors.harbor,
              tabs: const [
                Tab(text: 'Trabajo'),
                Tab(text: 'Revisión de material'),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _detailsTabController,
                children: [_buildWorkOverviewTab(), _buildMaterialReviewTab()],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_canEditPart)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _openEditDialog,
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar parte'),
                    ),
                  ),
                if (_isAdmin) ...[
                  if (_canEditPart) const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _deleteWorkOrder,
                    icon: Icon(
                      Icons.delete_forever,
                      color: Colors.red.shade700,
                    ),
                    label: Text(
                      'Borrar parte',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkOverviewTab() {
    return ListView(
      children: [
        _DetailRow(label: 'Propietario', value: _workOrder.ownerName),
        _DetailRow(
          label: 'Embarcación',
          value: _workOrder.vesselName ?? 'Sin embarcación',
        ),
        _DetailRow(
          label: 'Asignados',
          value: _workOrder.workerNames.isEmpty
              ? 'Sin asignar'
              : _workOrder.workerNames.join(', '),
        ),
        _DetailRow(
          label: 'Fecha de cierre',
          value: _workOrder.closeDueDate == null
              ? 'Sin definir'
              : _formatCalendarDate(_workOrder.closeDueDate!),
        ),
        _DetailRow(
          label: 'Creado',
          value: _workOrder.createdAt.toLocal().toString(),
        ),
        _DetailRow(
          label: 'Horas de trabajo',
          value: _formatLaborHoursLabel(_workOrder.laborHours),
        ),
        const SizedBox(height: 16),
        _buildWorkLogSection(),
        const SizedBox(height: 14),
        _buildSignatureSection(),
      ],
    );
  }

  Widget _buildMaterialReviewTab() {
    final checklist = _workOrder.materialChecklist;
    if (checklist == null) {
      return ListView(
        children: [
          _buildSectionCard(
            title: 'Revisión de material',
            subtitle:
                'Asigna una plantilla de material al parte para que el trabajador pueda revisar la caja antes de salir al puerto.',
            action: _isAdmin
                ? FilledButton.icon(
                    onPressed: _busy ? null : _openEditDialog,
                    icon: const Icon(Icons.playlist_add_check_circle_outlined),
                    label: const Text('Asignar plantilla'),
                  )
                : null,
            child: Text(
              _isAdmin
                  ? 'Este parte todavía no tiene plantilla de material. Puedes adjuntarla desde la edición del parte.'
                  : 'Todavía no hay una plantilla de material asignada a este parte.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    final checkedCount = checklist.items
        .where((item) => _materialChecks[item.id] ?? item.checked)
        .length;
    final pendingRequests = _workOrder.materialRevisionRequests
        .where((item) => item.isPending)
        .length;

    return ListView(
      children: [
        _buildSectionCard(
          title: 'Revisión de material',
          subtitle:
              'Marca el material mientras preparas la caja. Cada cambio se intenta guardar al momento y, si no hay cobertura, se reintenta automáticamente.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NavalgoPanel(
                tint: NavalgoColors.foam,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CompactMetricPill(
                      label: 'Plantilla',
                      value: checklist.sourceTemplateName,
                      color: NavalgoColors.harbor,
                    ),
                    _CompactMetricPill(
                      label: 'Completados',
                      value: '$checkedCount/${checklist.items.length}',
                      color: NavalgoColors.kelp,
                    ),
                    _CompactMetricPill(
                      label: 'Incidencias',
                      value: '$pendingRequests pendientes',
                      color: NavalgoColors.coral,
                    ),
                  ],
                ),
              ),
              if (_hasMaterialDraft) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NavalgoColors.sand.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: NavalgoColors.sand.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    'Hay cambios pendientes guardados localmente para este checklist. Se volverán a intentar automáticamente cuando haya conexión.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NavalgoColors.deepSea,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...checklist.items.map((item) {
                final pendingForItem = _workOrder.materialRevisionRequests
                    .where(
                      (request) =>
                          request.checklistItemSnapshotId == item.id &&
                          request.isPending,
                    )
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MaterialChecklistItemCard(
                    item: item,
                    checked: _materialChecks[item.id] ?? item.checked,
                    pendingRequests: pendingForItem,
                    busy: _materialBusy,
                    onChanged: _canReviewMaterial
                        ? (value) => _toggleMaterialChecklistItem(item, value)
                        : null,
                    onRequestRevision: _canReviewMaterial
                        ? () => _createMaterialRevisionRequest(item)
                        : null,
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Solicitudes de revisión',
          subtitle:
              'Trazabilidad de cambios y errores detectados por los técnicos en esta plantilla.',
          child: _workOrder.materialRevisionRequests.isEmpty
              ? Text(
                  'Todavía no hay solicitudes de revisión para este parte.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : Column(
                  children: _workOrder.materialRevisionRequests.map((request) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MaterialRevisionRequestCard(
                        request: request,
                        busy: _materialBusy,
                        canModerate: _isAdmin && request.isPending,
                        onApprove: _isAdmin && request.isPending
                            ? () => _updateMaterialRevisionStatus(
                                request,
                                'APPROVED',
                              )
                            : null,
                        onReject: _isAdmin && request.isPending
                            ? () => _updateMaterialRevisionStatus(
                                request,
                                'REJECTED',
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    Widget? action,
    required Widget child,
  }) {
    return NavalgoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoSectionHeader(
            title: title,
            subtitle: subtitle,
            action: action,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildWorkLogSection() {
    return _buildSectionCard(
      title: 'Avance del trabajo',
      subtitle:
          'Actualiza observaciones, horas imputables, horas de motor y fotos de avance antes de cerrar o firmar el parte.',
      action: _canUpdateWorkLog
          ? FilledButton.icon(
              onPressed: _busy ? null : _saveWorkLogChanges,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar avance'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkLogFieldCard(
            icon: Icons.notes_outlined,
            title: 'Descripción del trabajo',
            caption: 'Resume el avance real, incidencias y material pendiente.',
            child: TextField(
              controller: _observationsCtrl,
              readOnly: !_canUpdateWorkLog || _busy,
              maxLines: 4,
              decoration: NavalgoFormStyles.inputDecoration(
                context,
                label: 'Observaciones del trabajo',
                hint: 'Añadir observaciones del trabajo',
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _WorkLogFieldCard(
            icon: Icons.schedule_outlined,
            title: 'Horas de trabajo',
            caption:
                'Tiempo total dedicado por los técnicos a esta intervención. Admite valores decimales.',
            child: TextField(
              controller: _laborHoursCtrl,
              readOnly: !_canUpdateWorkLog || _busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: NavalgoFormStyles.inputDecoration(
                context,
                label: 'Horas de trabajo',
                hint: 'Ej. 3.5',
                prefixIcon: const Icon(Icons.schedule_outlined),
              ).copyWith(suffixText: 'h'),
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Horas de motor',
            caption:
                'Cada bloque identifica el motor al que se le imputan las horas: babor, estribor, auxiliar, central u otro.',
            child: _engineHoursControllers.isEmpty
                ? Text(
                    'Sin motores disponibles para este parte.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    children: _engineHoursControllers.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EngineHourInputCard(
                          engineLabel: entry.key,
                          controller: entry.value,
                          readOnly: !_canUpdateWorkLog || _busy,
                        ),
                      );
                    }).toList(),
                  ),
          ),
          if (_workOrder.laborHours != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Últimas horas guardadas',
              value: _formatLaborHoursLabel(_workOrder.laborHours),
            ),
          ],
          if (_workOrder.engineHours.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Último registro guardado',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: NavalgoColors.storm),
            ),
            const SizedBox(height: 6),
            ..._workOrder.engineHours.map(
              (item) => _DetailRow(
                label: _formatEngineLabel(item.engineLabel),
                value: '${item.hours} h',
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildWorkProgressAttachmentsPanel(),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    if (_isSigned) {
      return _buildSectionCard(
        title: 'Firma del parte',
        subtitle:
            'El parte ya está cerrado. Puedes revisar la firma registrada y, si tienes permisos, eliminarla.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firmado por: ${_workOrder.signedByWorkerName ?? 'Usuario no disponible'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (_workOrder.signedAt != null)
              Text('Firmado el: ${_workOrder.signedAt!.toLocal()}'),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 3.4,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  resolveMediaUrl(_workOrder.signatureUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Text('No se pudo cargar la firma')),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openExternal(_workOrder.signatureUrl!),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir firma'),
                ),
                if (_canEditPart)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _clearSignature,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar firma'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NavalgoColors.coral,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (!_canSign) {
      return _buildSectionCard(
        title: 'Firma del parte',
        subtitle: 'Este parte todavía no tiene firma registrada.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solo un trabajador o un administrador pueden firmar el parte cuando esté pendiente de cierre.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return _buildSectionCard(
      title: 'Firma y cierre',
      subtitle:
          'Dibuja la firma para cerrar el parte cuando el avance del trabajo ya esté actualizado.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: _signaturePadKey,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Signature(
                controller: _sigController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _busy || _signing ? null : _sigController.clear,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Borrar trazo'),
            ),
          ),
          const SizedBox(height: 16),
          NavalgoGradientButton(
            label: _signing ? 'Cerrando parte...' : 'Firmar y cerrar parte',
            icon: _signing ? null : Icons.draw_outlined,
            onPressed: _busy || _signing ? null : _submitInlineSignature,
            expand: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkProgressAttachmentsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NavalgoColors.foam,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NavalgoColors.border),
      ),
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
                      'Avances del trabajo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Las fotos de avance se capturan desde la cámara del móvil y se guardan con ubicación y marca de agua.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (_canDeleteMedia && !kIsWeb) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy || _signing
                      ? null
                      : _captureWorkProgressPhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Hacer foto'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Las fotos de avance solo pueden capturarse desde la app móvil para evitar adjuntos externos.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: NavalgoColors.storm),
              ),
            ),
          if (_attachments.isEmpty)
            Text(
              'Todavía no hay avances adjuntos en este parte.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              children: _attachments
                  .map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: NavalgoColors.mist,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.fileType == 'VIDEO'
                                ? Icons.videocam
                                : Icons.image,
                            color: NavalgoColors.harbor,
                          ),
                        ),
                        title: Text(item.originalFileName ?? 'Avance adjunto'),
                        subtitle: Text(_formatAttachmentDetails(item)),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: () => _openExternal(item.fileUrl),
                              icon: const Icon(Icons.open_in_new),
                            ),
                            if (_canDeleteMedia)
                              IconButton(
                                onPressed: _busy
                                    ? null
                                    : () => _deleteAttachment(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final resolvedUrl = resolveMediaUrl(url);
    final opened = await launchUrl(
      Uri.parse(resolvedUrl.isEmpty ? url : resolvedUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      AppToast.error(context, 'No se pudo abrir el archivo.');
    }
  }

  String _formatAttachmentDetails(WorkOrderAttachmentItem item) {
    final parts = <String>[];
    if (item.capturedAt != null) {
      parts.add('Captura: ${item.capturedAt!.toLocal()}');
    }
    if (item.latitude != null && item.longitude != null) {
      parts.add(
        'GPS: ${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
      );
    }
    if (item.watermarked) {
      parts.add('Con marca de agua');
    }
    if (parts.isEmpty) {
      return item.fileUrl;
    }
    return parts.join(' • ');
  }

  Future<void> _saveWorkLogChanges() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final laborHours = _parseLaborHours(_laborHoursCtrl.text);
    if (_laborHoursCtrl.text.trim().isNotEmpty && laborHours == null) {
      AppToast.warning(
        context,
        'Las horas de trabajo deben ser un numero valido, por ejemplo 4 o 4.5.',
      );
      return;
    }

    final engineHours = <Map<String, dynamic>>[];
    for (final entry in _engineHoursControllers.entries) {
      final parsed = int.tryParse(entry.value.text.trim());
      if (parsed == null) {
        AppToast.warning(
          context,
          'Todas las horas de motor deben ser números enteros.',
        );
        return;
      }
      engineHours.add({'engineLabel': entry.key, 'hours': parsed});
    }
    final engineHoursPayload = _engineHoursControllers.isEmpty
        ? null
        : engineHours;

    setState(() => _busy = true);
    try {
      final updated = await context.read<WorkOrderService>().updateWorkOrder(
        token,
        workOrderId: _workOrder.id,
        description: _observationsCtrl.text.trim(),
        laborHours: laborHours,
        engineHours: engineHoursPayload,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(updated, syncInputs: true);
      });
      AppToast.success(context, 'Horas y observaciones actualizadas.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo guardar el avance: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleMaterialChecklistItem(
    WorkOrderMaterialChecklistItem item,
    bool value,
  ) async {
    setState(() {
      _materialChecks[item.id] = value;
      _hasMaterialDraft = _buildPendingMaterialChecklistPayload().isNotEmpty;
    });
    await _persistMaterialChecklistDraft();

    await _syncPendingMaterialChecklistItems();
  }

  Future<void> _syncPendingMaterialChecklistItems({
    bool showSuccessToast = false,
    bool showErrorToast = true,
  }) async {
    final items = _buildPendingMaterialChecklistPayload();
    if (items.isEmpty) {
      await _materialDraftStore.clear(_workOrder.id);
      if (mounted && _hasMaterialDraft) {
        setState(() => _hasMaterialDraft = false);
      }
      return;
    }

    await _syncMaterialChecklistItems(
      items,
      showSuccessToast: showSuccessToast,
      showErrorToast: showErrorToast,
    );
  }

  Future<void> _syncMaterialChecklistItems(
    List<Map<String, dynamic>> items, {
    bool showSuccessToast = false,
    bool showErrorToast = true,
  }) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || items.isEmpty) {
      return;
    }

    setState(() => _materialBusy = true);
    try {
      final updated = await context
          .read<WorkOrderMaterialService>()
          .updateChecklist(token, workOrderId: _workOrder.id, items: items);
      await _materialDraftStore.clear(_workOrder.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasMaterialDraft = false;
        _updateWorkOrder(updated, syncInputs: false);
      });
      if (showSuccessToast) {
        AppToast.success(context, 'Checklist de material sincronizado.');
      }
    } catch (_) {
      await _persistMaterialChecklistDraft();
      if (!mounted) {
        return;
      }
      if (showErrorToast) {
        AppToast.warning(
          context,
          'No se pudo guardar ahora. El cambio queda localmente y se reintentará automáticamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _materialBusy = false);
      }
    }
  }

  Future<void> _createMaterialRevisionRequest(
    WorkOrderMaterialChecklistItem item,
  ) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final observationsController = TextEditingController();
    String? errorText;
    final observations = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return NavalgoFormDialog(
              eyebrow: 'MATERIAL',
              title: 'Solicitud de revisión',
              subtitle:
                  'Explica al admin qué artículo o referencia no encaja con la embarcación o la reparación.',
              maxWidth: 640,
              actions: [
                NavalgoGhostButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                NavalgoGradientButton(
                  label: 'Enviar solicitud',
                  icon: Icons.send_outlined,
                  onPressed: () {
                    final trimmed = observationsController.text.trim();
                    if (trimmed.isEmpty) {
                      setDialogState(() {
                        errorText = 'Las observaciones son obligatorias.';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, trimmed);
                  },
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  NavalgoPanel(
                    tint: Colors.white.withValues(alpha: 0.96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'Artículo', value: item.articleName),
                        _DetailRow(label: 'Referencia', value: item.reference),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  NavalgoFormFieldBlock(
                    label: 'Observaciones',
                    caption:
                        'Describe el error, el cambio de pieza o cualquier corrección necesaria.',
                    child: TextField(
                      controller: observationsController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: NavalgoFormStyles.inputDecoration(
                        dialogContext,
                        label: 'Observaciones',
                        hint:
                            'Ej. El filtro indicado no corresponde a este Yamaha 150.',
                        prefixIcon: const Icon(Icons.rate_review_outlined),
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
    observationsController.dispose();

    if (!mounted || observations == null) {
      return;
    }

    setState(() => _materialBusy = true);
    try {
      final updated = await context
          .read<WorkOrderMaterialService>()
          .createRevisionRequest(
            token,
            workOrderId: _workOrder.id,
            checklistItemId: item.id,
            observations: observations,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(updated, syncInputs: true);
      });
      AppToast.success(context, 'Solicitud enviada al administrador.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo crear la solicitud: $e');
    } finally {
      if (mounted) {
        setState(() => _materialBusy = false);
      }
    }
  }

  Future<void> _updateMaterialRevisionStatus(
    MaterialRevisionRequest request,
    String status,
  ) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final noteController = TextEditingController(
      text: request.resolutionNote ?? '',
    );
    final resolutionNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return NavalgoFormDialog(
          eyebrow: 'MATERIAL',
          title: status == 'APPROVED'
              ? 'Aprobar incidencia'
              : 'Rechazar incidencia',
          subtitle:
              'Puedes añadir una nota opcional para dejar trazabilidad del motivo de la decisión.',
          maxWidth: 620,
          actions: [
            NavalgoGhostButton(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(dialogContext),
            ),
            NavalgoGradientButton(
              label: status == 'APPROVED' ? 'Aprobar' : 'Rechazar',
              icon: status == 'APPROVED'
                  ? Icons.check_circle_outline
                  : Icons.block_outlined,
              onPressed: () =>
                  Navigator.pop(dialogContext, noteController.text.trim()),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              NavalgoPanel(
                tint: Colors.white.withValues(alpha: 0.96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Artículo', value: request.articleName),
                    _DetailRow(label: 'Referencia', value: request.reference),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              NavalgoFormFieldBlock(
                label: 'Nota de resolución',
                caption: 'Opcional. Quedará asociada a la solicitud.',
                child: TextField(
                  controller: noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: NavalgoFormStyles.inputDecoration(
                    dialogContext,
                    label: 'Nota de resolución',
                    hint: 'Añadir contexto para la decisión tomada.',
                    prefixIcon: const Icon(Icons.fact_check_outlined),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    noteController.dispose();

    if (!mounted || resolutionNote == null) {
      return;
    }

    setState(() => _materialBusy = true);
    try {
      final updated = await context
          .read<WorkOrderMaterialService>()
          .updateRevisionRequestStatus(
            token,
            workOrderId: _workOrder.id,
            requestId: request.id,
            status: status,
            resolutionNote: resolutionNote,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(updated, syncInputs: true);
      });
      AppToast.success(context, 'Estado de la incidencia actualizado.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo actualizar la incidencia: $e');
    } finally {
      if (mounted) {
        setState(() => _materialBusy = false);
      }
    }
  }

  Future<void> _restoreMaterialChecklistDraft() async {
    final draft = await _materialDraftStore.load(_workOrder.id);
    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _materialChecks = {
        for (final item
            in _workOrder.materialChecklist?.items ??
                const <WorkOrderMaterialChecklistItem>[])
          item.id: draft.items[item.id] ?? item.checked,
      };
      _hasMaterialDraft = draft.items.isNotEmpty;
    });
  }

  Future<void> _persistMaterialChecklistDraft() async {
    final pendingItems = {
      for (final item
          in _workOrder.materialChecklist?.items ??
              const <WorkOrderMaterialChecklistItem>[])
        if ((_materialChecks[item.id] ?? item.checked) != item.checked)
          item.id: _materialChecks[item.id] ?? item.checked,
    };

    if (pendingItems.isEmpty) {
      await _materialDraftStore.clear(_workOrder.id);
      return;
    }

    await _materialDraftStore.save(
      WorkOrderMaterialDraft(
        workOrderId: _workOrder.id,
        items: pendingItems,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  List<Map<String, dynamic>> _buildPendingMaterialChecklistPayload() {
    return [
      for (final item
          in _workOrder.materialChecklist?.items ??
              const <WorkOrderMaterialChecklistItem>[])
        if ((_materialChecks[item.id] ?? item.checked) != item.checked)
          <String, dynamic>{
            'itemId': item.id,
            'checked': _materialChecks[item.id] ?? item.checked,
          },
    ];
  }

  Future<void> _captureWorkProgressPhoto() async {
    if (kIsWeb) {
      AppToast.warning(
        context,
        'Las fotos de avance solo se pueden capturar desde la app móvil.',
      );
      return;
    }

    final token = context.read<SessionViewModel>().token;
    final mediaService = context.read<WorkOrderMediaService>();
    if (token == null) {
      return;
    }

    final position = await _getRequiredAttachmentPosition();
    if (position == null) {
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 92,
    );
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? _guessMimeType(picked.name);
    final capturedAt = DateTime.now().toUtc();

    setState(() => _busy = true);
    try {
      final updated = await mediaService.attachToWorkOrder(
        token,
        workOrderId: _workOrder.id,
        fileName: picked.name.isEmpty
            ? 'avance_${_workOrder.id}_${capturedAt.millisecondsSinceEpoch}.jpg'
            : picked.name,
        bytes: bytes,
        mimeType: mime,
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: capturedAt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(updated, syncInputs: false);
      });
      AppToast.success(context, 'Foto de avance guardada.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo subir la foto de avance: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<Position?> _getRequiredAttachmentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppToast.warning(
            context,
            'Activa la ubicación del dispositivo para adjuntar fotos de avance.',
          );
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        if (mounted) {
          AppToast.warning(
            context,
            'La ubicación es obligatoria para guardar fotos de avance con metadatos y marca de agua.',
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (_) {
      if (mounted) {
        AppToast.warning(
          context,
          'No se pudo obtener la ubicación actual para adjuntar la foto.',
        );
      }
      return null;
    }
  }

  Future<void> _submitInlineSignature() async {
    if (!_sigController.isNotEmpty) {
      AppToast.warning(context, 'Dibuja tu firma antes de enviar.');
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() => _signing = true);

    final mediaService = context.read<WorkOrderMediaService>();
    try {
      final renderObject = _signaturePadKey.currentContext?.findRenderObject();
      final signatureSize = renderObject is RenderBox
          ? renderObject.size
          : null;
      final exportScale = MediaQuery.of(
        context,
      ).devicePixelRatio.clamp(2.5, 4.0);
      final exportWidth = signatureSize == null
          ? 1600
          : (signatureSize.width * exportScale).round();
      final exportHeight = signatureSize == null
          ? 720
          : (signatureSize.height * exportScale).round();
      final signatureBytes = await _sigController.toPngBytes(
        width: exportWidth,
        height: exportHeight,
      );
      if (signatureBytes == null) {
        throw Exception('No se pudo exportar la firma');
      }

      Position? position;
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {}

      await mediaService.signWorkOrder(
        token,
        workOrderId: _workOrder.id,
        signatureFileName: 'firma_parte_${_workOrder.id}.png',
        signatureBytes: signatureBytes,
        signatureMimeType: 'image/png',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'Error al firmar: $e');
    } finally {
      if (mounted) {
        setState(() => _signing = false);
      }
    }
  }

  Future<void> _openEditDialog() async {
    final session = context.read<SessionViewModel>();
    final workOrderService = context.read<WorkOrderService>();
    final fleetVm = context.read<FleetViewModel>();
    final workersVm = context.read<WorkersViewModel>();
    if (fleetVm.owners.isEmpty) {
      AppToast.warning(context, 'No hay propietarios cargados.');
      return;
    }

    final result = await showDialog<_EditPartInput>(
      context: context,
      builder: (_) => _EditPartDialog(
        workOrder: _workOrder,
        owners: fleetVm.owners,
        vessels: fleetVm.vessels,
        workers: workersVm.workers,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final token = session.token;
    if (token == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await workOrderService.updateWorkOrder(
        token,
        workOrderId: _workOrder.id,
        ownerId: result.ownerId,
        vesselId: result.vesselId,
        workerIds: result.workerIds,
        priority: result.highPriority ? 'HIGH' : 'NORMAL',
        closeDueDate: result.closeDueDate,
        materialTemplateId: result.materialTemplateId,
        clearMaterialChecklist: result.clearMaterialChecklist,
      );
      await _materialDraftStore.clear(_workOrder.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasMaterialDraft = false;
        _updateWorkOrder(updated, syncInputs: true);
      });
      AppToast.success(context, 'Parte actualizado.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo actualizar: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteWorkOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar parte'),
        content: Text(
          '¿Seguro que quieres eliminar "${_workOrder.title}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<WorkOrderService>().deleteWorkOrder(
        token,
        workOrderId: _workOrder.id,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
      AppToast.success(context, 'Parte eliminado.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo eliminar el parte: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _clearSignature() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await context.read<WorkOrderService>().updateWorkOrder(
        token,
        workOrderId: _workOrder.id,
        clearSignature: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(updated, syncInputs: true);
      });
      AppToast.success(context, 'Firma eliminada.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo borrar la firma: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteAttachment(WorkOrderAttachmentItem item) async {
    if (item.id == null) {
      AppToast.warning(context, 'Este adjunto no soporta borrado individual.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar adjunto'),
        content: const Text('Esta acción no se puede deshacer. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await context.read<WorkOrderService>().deleteAttachment(
        token,
        workOrderId: _workOrder.id,
        attachmentId: item.id!,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(updated, syncInputs: true);
      });
      AppToast.success(context, 'Adjunto eliminado.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo borrar el adjunto: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _syncWorkInputsFromWorkOrder() {
    _observationsCtrl.text = _workOrder.description ?? '';
    _laborHoursCtrl.text = _formatLaborHoursInput(_workOrder.laborHours);

    final existingValues = <String, String>{
      for (final entry in _engineHoursControllers.entries)
        entry.key: entry.value.text,
    };
    for (final controller in _engineHoursControllers.values) {
      controller.dispose();
    }
    _engineHoursControllers.clear();

    final labels = _resolveEngineLabelsFromWorkOrder();
    if (labels.isNotEmpty) {
      for (final label in labels) {
        final current = _workOrder.engineHours
            .where((item) => item.engineLabel == label)
            .map((item) => item.hours.toString())
            .firstOrNull;
        _engineHoursControllers[label] = TextEditingController(
          text: existingValues[label] ?? current ?? '',
        );
      }
      return;
    }

    for (final log in _workOrder.engineHours) {
      _engineHoursControllers[log.engineLabel] = TextEditingController(
        text: existingValues[log.engineLabel] ?? log.hours.toString(),
      );
    }
  }

  void _syncMaterialChecklistInputsFromWorkOrder() {
    _materialChecks = {
      for (final item
          in _workOrder.materialChecklist?.items ??
              const <WorkOrderMaterialChecklistItem>[])
        item.id: item.checked,
    };
  }

  void _updateWorkOrder(WorkOrder updated, {bool syncInputs = false}) {
    _workOrder = updated;
    _attachments = _resolveAttachments(updated);
    _syncMaterialChecklistInputsFromWorkOrder();
    if (syncInputs) {
      _syncWorkInputsFromWorkOrder();
    }
  }

  List<WorkOrderAttachmentItem> _resolveAttachments(WorkOrder workOrder) {
    if (workOrder.attachments.isNotEmpty) {
      return workOrder.attachments;
    }

    return workOrder.attachmentUrls
        .map(
          (url) => WorkOrderAttachmentItem(
            id: null,
            fileUrl: url,
            fileType: url.toLowerCase().endsWith('.mp4') ? 'VIDEO' : 'IMAGE',
            originalFileName: null,
            capturedAt: null,
            latitude: null,
            longitude: null,
            watermarked: false,
            audioRemoved: false,
          ),
        )
        .toList();
  }

  bool _isHighPriority(String priority) {
    return priority == 'HIGH' || priority == 'URGENT';
  }

  List<String> _resolveEngineLabelsFromWorkOrder() {
    final fleetVm = context.read<FleetViewModel>();
    final vessel = fleetVm.vessels
        .where((item) => item.id == _workOrder.vesselId)
        .firstOrNull;
    if (vessel == null) {
      return _workOrder.engineHours.map((item) => item.engineLabel).toList();
    }
    if (vessel.engineLabels.isNotEmpty) {
      return vessel.engineLabels;
    }
    final count = vessel.engineCount ?? 0;
    if (count > 0) {
      return List<String>.generate(count, (index) => 'Motor ${index + 1}');
    }
    return _workOrder.engineHours.map((item) => item.engineLabel).toList();
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mov':
        return 'video/quicktime';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

String _formatEngineLabel(String rawLabel) {
  final label = rawLabel.trim();
  if (label.isEmpty) {
    return 'Motor sin identificar';
  }
  return 'Motor: $label';
}

IconData _engineIconForLabel(String rawLabel) {
  final label = rawLabel.toLowerCase();
  if (label.contains('fuera borda') || label.contains('outboard')) {
    return Icons.shortcut;
  }
  if (label.contains('babor') || label.contains('port')) {
    return Icons.keyboard_double_arrow_left_rounded;
  }
  if (label.contains('estribor') || label.contains('starboard')) {
    return Icons.keyboard_double_arrow_right_rounded;
  }
  if (label.contains('central') || label.contains('main')) {
    return Icons.adjust;
  }
  if (label.contains('aux')) {
    return Icons.power_outlined;
  }
  if (label.contains('proa')) {
    return Icons.north_rounded;
  }
  if (label.contains('popa')) {
    return Icons.south_rounded;
  }
  return Icons.settings_outlined;
}

String _engineCaptionForLabel(String rawLabel) {
  final label = rawLabel.toLowerCase();
  if (label.contains('babor')) {
    return 'Registro del motor de babor';
  }
  if (label.contains('estribor')) {
    return 'Registro del motor de estribor';
  }
  if (label.contains('aux')) {
    return 'Registro del motor auxiliar';
  }
  if (label.contains('central')) {
    return 'Registro del motor principal';
  }
  return 'Registro asociado a este motor';
}

class _EngineHourInputCard extends StatelessWidget {
  const _EngineHourInputCard({
    required this.engineLabel,
    required this.controller,
    required this.readOnly,
  });

  final String engineLabel;
  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final icon = _engineIconForLabel(engineLabel);
    return NavalgoPanel(
      padding: const EdgeInsets.all(14),
      tint: Colors.white.withValues(alpha: 0.96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: NavalgoColors.deepSea.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: NavalgoColors.deepSea),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatEngineLabel(engineLabel),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _engineCaptionForLabel(engineLabel),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NavalgoColors.storm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: TextInputType.number,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Horas actuales',
              hint: 'Introduce el contador actual',
              prefixIcon: const Icon(Icons.av_timer_outlined),
            ).copyWith(suffixText: 'h'),
          ),
        ],
      ),
    );
  }
}

class _WorkLogFieldCard extends StatelessWidget {
  const _WorkLogFieldCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NavalgoPanel(
      padding: const EdgeInsets.all(14),
      tint: Colors.white.withValues(alpha: 0.96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: NavalgoColors.deepSea.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: NavalgoColors.deepSea),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NavalgoColors.storm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WorkerAssignmentList extends StatelessWidget {
  const _WorkerAssignmentList({
    required this.workers,
    required this.selectedWorkers,
    required this.onToggle,
  });

  final List<WorkerProfile> workers;
  final Set<int> selectedWorkers;
  final void Function(int workerId, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (workers.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No hay mecánicos disponibles.')),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        itemCount: workers.length,
        separatorBuilder: (_, index) => Divider(
          height: 1,
          color: NavalgoColors.border.withValues(alpha: 0.55),
        ),
        itemBuilder: (context, index) {
          final worker = workers[index];
          final selected = selectedWorkers.contains(worker.id);
          return CheckboxListTile(
            value: selected,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: _WorkerAvatar(worker: worker),
            title: Text(
              worker.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(worker.role),
            onChanged: (value) => onToggle(worker.id, value ?? false),
          );
        },
      ),
    );
  }
}

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({required this.worker});

  final WorkerProfile worker;

  @override
  Widget build(BuildContext context) {
    final photoUrl = worker.photoUrl?.trim();
    final resolvedPhotoUrl = resolveMediaUrl(photoUrl);
    return CircleAvatar(
      radius: 22,
      backgroundColor: NavalgoColors.mist,
      foregroundImage: resolvedPhotoUrl.isNotEmpty
          ? NetworkImage(resolvedPhotoUrl)
          : null,
      child: Text(
        _workerInitials(worker.fullName),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: NavalgoColors.tide,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _workerInitials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'M';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

class _EditPartInput {
  const _EditPartInput({
    required this.ownerId,
    required this.vesselId,
    required this.workerIds,
    required this.highPriority,
    required this.closeDueDate,
    required this.materialTemplateId,
    required this.clearMaterialChecklist,
  });

  final int ownerId;
  final int? vesselId;
  final List<int> workerIds;
  final bool highPriority;
  final DateTime closeDueDate;
  final int? materialTemplateId;
  final bool clearMaterialChecklist;
}

class _EditPartDialog extends StatefulWidget {
  const _EditPartDialog({
    required this.workOrder,
    required this.owners,
    required this.vessels,
    required this.workers,
  });

  final WorkOrder workOrder;
  final List<Owner> owners;
  final List<Vessel> vessels;
  final List<WorkerProfile> workers;

  @override
  State<_EditPartDialog> createState() => _EditPartDialogState();
}

class _EditPartDialogState extends State<_EditPartDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late int _ownerId;
  int? _vesselId;
  late bool _highPriority;
  DateTime? _closeDueDate;
  late final Set<int> _selectedWorkers;
  int? _selectedMaterialTemplateId;
  bool _clearMaterialChecklist = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.workOrder.ownerId;
    _vesselId = widget.workOrder.vesselId;
    _highPriority =
        widget.workOrder.priority == 'HIGH' ||
        widget.workOrder.priority == 'URGENT';
    _closeDueDate = widget.workOrder.closeDueDate;
    _selectedWorkers = widget.workOrder.workerIds.toSet();
    _selectedMaterialTemplateId =
        widget.workOrder.materialChecklist?.sourceTemplateId;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerVessels = widget.vessels
        .where((v) => v.ownerId == _ownerId)
        .toList();
    final validVessel = ownerVessels.any((v) => v.id == _vesselId)
        ? _vesselId
        : null;

    return NavalgoFormDialog(
      eyebrow: 'PARTES',
      title: 'Editar parte',
      subtitle:
          'Actualiza propietario, embarcación, prioridad y mecánicos con la misma estética del editor de perfil.',
      maxWidth: 820,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Guardar',
          icon: Icons.save_outlined,
          onPressed: () {
            if (_closeDueDate == null) {
              setState(() {
                _validationError = 'La fecha de cierre es obligatoria.';
              });
              return;
            }
            Navigator.pop(
              context,
              _EditPartInput(
                ownerId: _ownerId,
                vesselId: _vesselId,
                workerIds: _selectedWorkers.toList(),
                highPriority: _highPriority,
                closeDueDate: _closeDueDate!,
                materialTemplateId: _selectedMaterialTemplateId,
                clearMaterialChecklist: _clearMaterialChecklist,
              ),
            );
          },
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.workOrder.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reorganiza la asignación del parte sin salir del panel operativo.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            NavalgoFormFieldBlock(
              label: 'Propietario',
              child: DropdownButtonFormField<int>(
                initialValue: _ownerId,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Propietario',
                  prefixIcon: const Icon(Icons.person_pin_outlined),
                ),
                items: widget.owners
                    .map(
                      (o) => DropdownMenuItem<int>(
                        value: o.id,
                        child: Text(o.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _ownerId = value;
                    if (!widget.vessels.any(
                      (v) => v.ownerId == _ownerId && v.id == _vesselId,
                    )) {
                      _vesselId = null;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Embarcación',
              child: DropdownButtonFormField<int?>(
                initialValue: validVessel,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Embarcación',
                  prefixIcon: const Icon(Icons.directions_boat_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin embarcación'),
                  ),
                  ...ownerVessels.map(
                    (v) => DropdownMenuItem<int?>(
                      value: v.id,
                      child: Text(v.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _vesselId = value),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Prioridad',
              child: NavalgoPanel(
                tint: Colors.white.withValues(alpha: 0.96),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _highPriority,
                  onChanged: (value) =>
                      setState(() => _highPriority = value ?? false),
                  title: const Text('Prioridad alta'),
                  subtitle: const Text(
                    'Resalta este parte en el panel principal de operaciones.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fecha de cierre',
              caption:
                  'Obligatoria. Se usará para recordar el cierre si el parte sigue abierto.',
              child: OutlinedButton.icon(
                onPressed: () async {
                  final initialDate =
                      _closeDueDate ??
                      DateTime.now().add(const Duration(days: 1));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (!mounted || picked == null) {
                    return;
                  }
                  setState(() {
                    _closeDueDate = picked;
                    _validationError = null;
                  });
                },
                icon: const Icon(Icons.event_available_outlined),
                label: Text(
                  _closeDueDate == null
                      ? 'Seleccionar fecha'
                      : _formatCalendarDate(_closeDueDate!),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Mecánicos asignados',
              caption: 'Selecciona el equipo que trabajará sobre este parte.',
              child: NavalgoPanel(
                tint: Colors.white.withValues(alpha: 0.96),
                child: _WorkerAssignmentList(
                  workers: widget.workers,
                  selectedWorkers: _selectedWorkers,
                  onToggle: (workerId, selected) {
                    setState(() {
                      if (selected) {
                        _selectedWorkers.add(workerId);
                      } else {
                        _selectedWorkers.remove(workerId);
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MaterialTemplateAssignmentField(
              selectedTemplateId: _selectedMaterialTemplateId,
              onChanged: (value) {
                setState(() {
                  _selectedMaterialTemplateId = value;
                  _clearMaterialChecklist =
                      value == null &&
                      widget.workOrder.materialChecklist != null;
                });
              },
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 12),
              Text(
                _validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreatePartInput {
  const _CreatePartInput({
    required this.title,
    required this.description,
    required this.ownerId,
    required this.vesselId,
    required this.workerIds,
    required this.closeDueDate,
    required this.laborHours,
    required this.materialTemplateId,
    required this.engineHours,
    required this.attachments,
    required this.priority,
  });

  final String title;
  final String description;
  final int ownerId;
  final int? vesselId;
  final List<int> workerIds;
  final DateTime closeDueDate;
  final double? laborHours;
  final int? materialTemplateId;
  final List<EngineHourLog> engineHours;
  final List<WorkOrderAttachmentItem> attachments;
  final String priority;
}

class _CreatePartDialog extends StatefulWidget {
  const _CreatePartDialog({
    required this.owners,
    required this.vessels,
    required this.workers,
  });

  final List<Owner> owners;
  final List<Vessel> vessels;
  final List<WorkerProfile> workers;

  @override
  State<_CreatePartDialog> createState() => _CreatePartDialogState();
}

class _CreatePartDialogState extends State<_CreatePartDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _laborHoursCtrl = TextEditingController();
  late int _ownerId;
  int? _vesselId;
  bool _highPriority = false;
  DateTime? _closeDueDate;
  final Set<int> _selectedWorkers = <int>{};
  final Map<String, TextEditingController> _engineHoursControllers =
      <String, TextEditingController>{};
  String? _validationError;
  int? _selectedMaterialTemplateId;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.owners.first.id;
    _syncVesselSelectionForOwner();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _laborHoursCtrl.dispose();
    for (final controller in _engineHoursControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableVessels = widget.vessels
        .where((vessel) => vessel.ownerId == _ownerId)
        .toList();

    return NavalgoFormDialog(
      eyebrow: 'PARTES',
      title: 'Nuevo parte',
      subtitle:
          'Da de alta un parte con el mismo estilo del formulario de perfil: limpio, compacto y con bloques claros.',
      maxWidth: 860,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Crear',
          icon: Icons.note_add_outlined,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            NavalgoFormFieldBlock(
              label: 'Título',
              child: TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Título',
                  prefixIcon: const Icon(Icons.title_outlined),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'El título es obligatorio.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Descripción',
              child: TextFormField(
                controller: _descriptionCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Descripción',
                  hint: 'Describe la intervención a realizar.',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Horas de trabajo',
              caption:
                  'Campo opcional para registrar el tiempo total imputable de la intervención.',
              child: TextFormField(
                controller: _laborHoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Horas de trabajo',
                  hint: 'Ej. 3.5',
                  prefixIcon: const Icon(Icons.schedule_outlined),
                ).copyWith(suffixText: 'h'),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Propietario',
              child: DropdownButtonFormField<int>(
                initialValue: _ownerId,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Propietario',
                  prefixIcon: const Icon(Icons.person_pin_outlined),
                ),
                items: widget.owners
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.id,
                        child: Text(o.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _ownerId = v ?? _ownerId;
                  });
                  _syncVesselSelectionForOwner();
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Embarcación',
              child: DropdownButtonFormField<int?>(
                initialValue: _vesselId,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Embarcación',
                  prefixIcon: const Icon(Icons.directions_boat_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin embarcación'),
                  ),
                  ...availableVessels.map(
                    (vessel) => DropdownMenuItem<int?>(
                      value: vessel.id,
                      child: Text(vessel.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _vesselId = value;
                  });
                  _syncEngineHoursForSelectedVessel();
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Prioridad',
              child: NavalgoPanel(
                tint: Colors.white.withValues(alpha: 0.96),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _highPriority,
                  onChanged: (value) =>
                      setState(() => _highPriority = value ?? false),
                  title: const Text('Prioridad alta'),
                  subtitle: const Text(
                    'Mostrará este parte como destacado en el panel de operaciones.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fecha de cierre',
              caption:
                  'Obligatoria. Si el parte sigue abierto después de esta fecha, se notificará a los asignados.',
              child: OutlinedButton.icon(
                onPressed: () async {
                  final initialDate =
                      _closeDueDate ??
                      DateTime.now().add(const Duration(days: 1));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (!mounted || picked == null) {
                    return;
                  }
                  setState(() {
                    _closeDueDate = picked;
                    _validationError = null;
                  });
                },
                icon: const Icon(Icons.event_available_outlined),
                label: Text(
                  _closeDueDate == null
                      ? 'Seleccionar fecha'
                      : _formatCalendarDate(_closeDueDate!),
                ),
              ),
            ),
            if (_engineHoursControllers.isNotEmpty) ...[
              const SizedBox(height: 14),
              NavalgoFormFieldBlock(
                label: 'Horas de motores',
                caption:
                    'Opcional al crear. Puedes completarlas más tarde indicando qué motor corresponde a cada campo.',
                child: Column(
                  children: _engineHoursControllers.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EngineHourInputCard(
                        engineLabel: entry.key,
                        controller: entry.value,
                        readOnly: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _MaterialTemplateAssignmentField(
              selectedTemplateId: _selectedMaterialTemplateId,
              onChanged: (value) {
                setState(() {
                  _selectedMaterialTemplateId = value;
                });
              },
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Asignar trabajadores',
              caption:
                  'Marca los mecánicos que quedan vinculados al parte desde el inicio.',
              child: NavalgoPanel(
                tint: Colors.white.withValues(alpha: 0.96),
                child: _WorkerAssignmentList(
                  workers: widget.workers,
                  selectedWorkers: _selectedWorkers,
                  onToggle: (workerId, selected) {
                    setState(() {
                      if (selected) {
                        _selectedWorkers.add(workerId);
                      } else {
                        _selectedWorkers.remove(workerId);
                      }
                    });
                  },
                ),
              ),
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 12),
              Text(
                _validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() {
        _validationError = null;
      });
      return;
    }

    final title = _titleCtrl.text.trim();
    final laborHours = _parseLaborHours(_laborHoursCtrl.text);
    if (_laborHoursCtrl.text.trim().isNotEmpty && laborHours == null) {
      setState(() {
        _validationError =
            'Las horas de trabajo deben ser un numero valido, por ejemplo 4 o 4.5.';
      });
      return;
    }

    if (_closeDueDate == null) {
      setState(() {
        _validationError = 'La fecha de cierre es obligatoria.';
      });
      return;
    }

    final engineHours = <EngineHourLog>[];
    for (final entry in _engineHoursControllers.entries) {
      final rawHours = entry.value.text.trim();
      if (rawHours.isEmpty) {
        continue;
      }
      final hours = int.tryParse(rawHours);
      if (hours == null) {
        setState(() {
          _validationError = 'Las horas de motor deben ser números enteros.';
        });
        return;
      }
      engineHours.add(EngineHourLog(engineLabel: entry.key, hours: hours));
    }

    Navigator.pop(
      context,
      _CreatePartInput(
        title: title,
        description: _descriptionCtrl.text.trim(),
        ownerId: _ownerId,
        vesselId: _vesselId,
        workerIds: _selectedWorkers.toList(),
        closeDueDate: _closeDueDate!,
        laborHours: laborHours,
        materialTemplateId: _selectedMaterialTemplateId,
        engineHours: engineHours,
        attachments: const <WorkOrderAttachmentItem>[],
        priority: _highPriority ? 'HIGH' : 'NORMAL',
      ),
    );
  }

  void _syncVesselSelectionForOwner() {
    final vessels = widget.vessels
        .where((vessel) => vessel.ownerId == _ownerId)
        .toList();
    if (vessels.isEmpty) {
      _vesselId = null;
    } else if (_vesselId == null ||
        !vessels.any((vessel) => vessel.id == _vesselId)) {
      _vesselId = vessels.first.id;
    }
    _syncEngineHoursForSelectedVessel();
  }

  void _syncEngineHoursForSelectedVessel() {
    final vessel = widget.vessels
        .where((item) => item.id == _vesselId)
        .cast<Vessel?>()
        .firstOrNull;
    final labels = vessel == null ? <String>[] : _resolveEngineLabels(vessel);

    final existingValues = <String, String>{
      for (final entry in _engineHoursControllers.entries)
        entry.key: entry.value.text,
    };

    for (final controller in _engineHoursControllers.values) {
      controller.dispose();
    }
    _engineHoursControllers
      ..clear()
      ..addEntries(
        labels.map(
          (label) => MapEntry(
            label,
            TextEditingController(text: existingValues[label] ?? ''),
          ),
        ),
      );

    if (mounted) {
      setState(() {
        _validationError = null;
      });
    }
  }

  List<String> _resolveEngineLabels(Vessel vessel) {
    if (vessel.engineLabels.isNotEmpty) {
      return vessel.engineLabels;
    }

    final count = vessel.engineCount ?? 0;
    return List<String>.generate(count, (index) => 'Motor ${index + 1}');
  }
}

class _PartBadge extends StatelessWidget {
  const _PartBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CompactMetricPill extends StatelessWidget {
  const _CompactMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: NavalgoColors.storm),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialChecklistItemCard extends StatelessWidget {
  const _MaterialChecklistItemCard({
    required this.item,
    required this.checked,
    required this.pendingRequests,
    required this.busy,
    required this.onChanged,
    required this.onRequestRevision,
  });

  final WorkOrderMaterialChecklistItem item;
  final bool checked;
  final int pendingRequests;
  final bool busy;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onRequestRevision;

  @override
  Widget build(BuildContext context) {
    return NavalgoPanel(
      tint: checked ? NavalgoColors.foam : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: checked,
                onChanged: busy || onChanged == null
                    ? null
                    : (value) => onChanged!(value ?? false),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.articleName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Referencia: ${item.reference}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (item.checkedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Último check: ${item.checkedAt!.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NavalgoColors.storm,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (pendingRequests > 0)
                NavalgoStatusChip(
                  label:
                      '$pendingRequests pendiente${pendingRequests == 1 ? '' : 's'}',
                  color: NavalgoColors.coral,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onRequestRevision,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Solicitar cambio'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialRevisionRequestCard extends StatelessWidget {
  const _MaterialRevisionRequestCard({
    required this.request,
    required this.busy,
    required this.canModerate,
    this.onApprove,
    this.onReject,
  });

  final MaterialRevisionRequest request;
  final bool busy;
  final bool canModerate;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final statusColor = _materialRevisionStatusColor(request.status);
    return NavalgoPanel(
      tint: statusColor.withValues(alpha: 0.06),
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
                      request.articleName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Referencia: ${request.reference}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              NavalgoStatusChip(
                label: _materialRevisionStatusLabel(request.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.observations,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Reportado por ${request.requestedByWorkerName ?? 'Técnico'}${request.createdAt != null ? ' · ${request.createdAt!.toLocal()}' : ''}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: NavalgoColors.storm),
          ),
          if ((request.resolutionNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Resolución: ${request.resolutionNote!.trim()}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: NavalgoColors.deepSea),
            ),
          ],
          if (canModerate) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_outlined),
                  label: const Text('Rechazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NavalgoColors.coral,
                  ),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Aprobar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialTemplateAssignmentField extends StatefulWidget {
  const _MaterialTemplateAssignmentField({
    required this.selectedTemplateId,
    required this.onChanged,
  });

  final int? selectedTemplateId;
  final ValueChanged<int?> onChanged;

  @override
  State<_MaterialTemplateAssignmentField> createState() =>
      _MaterialTemplateAssignmentFieldState();
}

class _MaterialTemplateAssignmentFieldState
    extends State<_MaterialTemplateAssignmentField> {
  bool _loading = false;
  String? _error;
  List<MaterialChecklistTemplate> _templates =
      const <MaterialChecklistTemplate>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadTemplates);
  }

  Future<void> _loadTemplates({int? selectTemplateId}) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final templates = await context
          .read<MaterialChecklistTemplateService>()
          .getTemplates(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = templates;
      });
      if (selectTemplateId != null) {
        widget.onChanged(selectTemplateId);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTemplate = _templates
        .where((item) => item.id == widget.selectedTemplateId)
        .cast<MaterialChecklistTemplate?>()
        .firstOrNull;

    return NavalgoFormFieldBlock(
      label: 'Plantilla de material',
      caption:
          'Opcional. Se clona al parte como checklist independiente para no alterar históricos cuando cambie la plantilla original.',
      child: NavalgoPanel(
        tint: Colors.white.withValues(alpha: 0.96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : DropdownButtonFormField<int?>(
                          initialValue: selectedTemplate?.id,
                          dropdownColor: NavalgoColors.shell,
                          decoration: NavalgoFormStyles.inputDecoration(
                            context,
                            label: 'Plantilla de material',
                            prefixIcon: const Icon(Icons.fact_check_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Sin plantilla'),
                            ),
                            ..._templates.map(
                              (template) => DropdownMenuItem<int?>(
                                value: template.id,
                                child: Text(template.name),
                              ),
                            ),
                          ],
                          onChanged: widget.onChanged,
                        ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          final selectedId = await showDialog<int?>(
                            context: context,
                            builder: (_) =>
                                const _ManageMaterialTemplatesDialog(),
                          );
                          if (!mounted) {
                            return;
                          }
                          await _loadTemplates(selectTemplateId: selectedId);
                        },
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Gestionar'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (selectedTemplate?.latestIncident != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: NavalgoColors.coral.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: NavalgoColors.coral.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Última incidencia reportada',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: NavalgoColors.coral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${selectedTemplate!.latestIncident!.articleName} · Ref ${selectedTemplate.latestIncident!.reference}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedTemplate.latestIncident!.observations,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageMaterialTemplatesDialog extends StatefulWidget {
  const _ManageMaterialTemplatesDialog();

  @override
  State<_ManageMaterialTemplatesDialog> createState() =>
      _ManageMaterialTemplatesDialogState();
}

class _ManageMaterialTemplatesDialogState
    extends State<_ManageMaterialTemplatesDialog> {
  bool _loading = false;
  String? _error;
  List<MaterialChecklistTemplate> _templates =
      const <MaterialChecklistTemplate>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadTemplates);
  }

  Future<void> _loadTemplates() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templates = await context
          .read<MaterialChecklistTemplateService>()
          .getTemplates(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditor({MaterialChecklistTemplate? template}) async {
    final saved = await showDialog<MaterialChecklistTemplate>(
      context: context,
      builder: (_) => _MaterialTemplateEditorDialog(template: template),
    );
    if (!mounted || saved == null) {
      return;
    }
    await _loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'MATERIAL',
      title: 'Plantillas de material',
      subtitle:
          'Crea y ajusta checklists reutilizables con artículo y referencia. Puedes usar una plantilla directamente al cerrar este diálogo.',
      maxWidth: 860,
      actions: [
        NavalgoGhostButton(
          label: 'Cerrar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Nueva plantilla',
          icon: Icons.playlist_add_outlined,
          onPressed: () => _openEditor(),
        ),
      ],
      child: _loading
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_templates.isEmpty)
                  Text(
                    'Todavía no hay plantillas de material creadas.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: _templates.map((template) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NavalgoPanel(
                            tint: Colors.white.withValues(alpha: 0.96),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            template.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          if ((template.description ?? '')
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              template.description!.trim(),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    NavalgoStatusChip(
                                      label: '${template.items.length} items',
                                      color: NavalgoColors.harbor,
                                    ),
                                  ],
                                ),
                                if (template.latestIncident != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: NavalgoColors.coral.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Última incidencia: ${template.latestIncident!.observations}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openEditor(template: template),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Editar'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () =>
                                          Navigator.pop(context, template.id),
                                      icon: const Icon(
                                        Icons.checklist_outlined,
                                      ),
                                      label: const Text('Usar en el parte'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MaterialTemplateEditorDialog extends StatefulWidget {
  const _MaterialTemplateEditorDialog({this.template});

  final MaterialChecklistTemplate? template;

  @override
  State<_MaterialTemplateEditorDialog> createState() =>
      _MaterialTemplateEditorDialogState();
}

class _MaterialTemplateEditorDialogState
    extends State<_MaterialTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final List<_MaterialTemplateItemDraft> _items;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    _descriptionCtrl = TextEditingController(
      text: widget.template?.description ?? '',
    );
    _items = (widget.template?.items ?? const <MaterialChecklistTemplateItem>[])
        .map(
          (item) => _MaterialTemplateItemDraft(
            articleName: item.articleName,
            reference: item.reference,
          ),
        )
        .toList();
    if (_items.isEmpty) {
      _items.add(_MaterialTemplateItemDraft());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final normalizedItems = <MaterialChecklistTemplateItem>[];
    for (var index = 0; index < _items.length; index += 1) {
      final draft = _items[index];
      final article = draft.articleController.text.trim();
      final reference = draft.referenceController.text.trim();
      if (article.isEmpty || reference.isEmpty) {
        setState(() {
          _error = 'Cada item debe tener artículo y referencia.';
        });
        return;
      }
      normalizedItems.add(
        MaterialChecklistTemplateItem(
          articleName: article,
          reference: reference,
          sortOrder: index,
        ),
      );
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = context.read<MaterialChecklistTemplateService>();
      final saved = widget.template == null
          ? await service.createTemplate(
              token,
              name: _nameCtrl.text.trim(),
              description: _descriptionCtrl.text.trim(),
              items: normalizedItems,
            )
          : await service.updateTemplate(
              token,
              templateId: widget.template!.id!,
              name: _nameCtrl.text.trim(),
              description: _descriptionCtrl.text.trim(),
              items: normalizedItems,
            );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'MATERIAL',
      title: widget.template == null ? 'Nueva plantilla' : 'Editar plantilla',
      subtitle:
          'Cada elemento debe indicar el artículo y su referencia para que el técnico no salga con una lista ambigua.',
      maxWidth: 780,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: _saving ? 'Guardando...' : 'Guardar plantilla',
          icon: _saving ? null : Icons.save_outlined,
          onPressed: _saving ? null : _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            NavalgoFormFieldBlock(
              label: 'Nombre',
              child: TextFormField(
                controller: _nameCtrl,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nombre de la plantilla',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) => (value?.trim() ?? '').isEmpty
                    ? 'El nombre es obligatorio.'
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Descripción',
              child: TextFormField(
                controller: _descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Descripción',
                  hint: 'Ej. Mantenimiento Guardia Civil - Motor Yamaha',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Elementos de la plantilla',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _items.add(_MaterialTemplateItemDraft());
                        }),
                  icon: const Icon(Icons.add_outlined),
                  label: const Text('Añadir item'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NavalgoPanel(
                  tint: Colors.white.withValues(alpha: 0.96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Artículo ${index + 1}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          if (_items.length > 1)
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      final removed = _items.removeAt(index);
                                      removed.dispose();
                                    }),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: item.articleController,
                        decoration: NavalgoFormStyles.inputDecoration(
                          context,
                          label: 'Artículo',
                          hint: 'Nombre del repuesto o consumible',
                          prefixIcon: const Icon(Icons.build_circle_outlined),
                        ),
                        validator: (value) => (value?.trim() ?? '').isEmpty
                            ? 'El artículo es obligatorio.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item.referenceController,
                        decoration: NavalgoFormStyles.inputDecoration(
                          context,
                          label: 'Referencia',
                          hint: 'SKU o código de pieza',
                          prefixIcon: const Icon(Icons.qr_code_outlined),
                        ),
                        validator: (value) => (value?.trim() ?? '').isEmpty
                            ? 'La referencia es obligatoria.'
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaterialTemplateItemDraft {
  _MaterialTemplateItemDraft({String articleName = '', String reference = ''})
    : articleController = TextEditingController(text: articleName),
      referenceController = TextEditingController(text: reference);

  final TextEditingController articleController;
  final TextEditingController referenceController;

  void dispose() {
    articleController.dispose();
    referenceController.dispose();
  }
}

Color _materialRevisionStatusColor(String status) {
  switch (status) {
    case 'APPROVED':
      return NavalgoColors.kelp;
    case 'REJECTED':
      return NavalgoColors.coral;
    case 'PENDING':
    default:
      return NavalgoColors.sand;
  }
}

String _materialRevisionStatusLabel(String status) {
  switch (status) {
    case 'APPROVED':
      return 'Aprobada';
    case 'REJECTED':
      return 'Rechazada';
    case 'PENDING':
    default:
      return 'Pendiente';
  }
}

String _formatLaborHoursInput(double? value) {
  if (value == null) {
    return '';
  }
  final text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  return text
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirst(RegExp(r'(\.[0-9]*?)0+$'), r'$1');
}

String _formatLaborHoursLabel(double? value) {
  if (value == null) {
    return 'Sin registrar';
  }
  return '${_formatLaborHoursInput(value)} h';
}

double? _parseLaborHours(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}
