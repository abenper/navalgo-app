import 'package:file_picker/file_picker.dart';
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
                                  trailing: Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      NavalgoMetricCard(
                                        label: 'Firmados',
                                        value: '$signedCount',
                                        icon: Icons.verified_outlined,
                                        accent: const Color(0xFF3BAA6E),
                                      ),
                                      NavalgoMetricCard(
                                        label: 'Pendientes de firma',
                                        value: '$pendingSignatureCount',
                                        icon: Icons.draw_outlined,
                                        accent: const Color(0xFFD55A4E),
                                      ),
                                      NavalgoMetricCard(
                                        label: 'Prioridad alta',
                                        value: '$highPriorityCount',
                                        icon: Icons.priority_high_rounded,
                                        accent: const Color(0xFFD5A021),
                                      ),
                                    ],
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
}

class _WorkOrderDetailsSheet extends StatefulWidget {
  const _WorkOrderDetailsSheet({required this.initialWorkOrder});

  final WorkOrder initialWorkOrder;

  @override
  State<_WorkOrderDetailsSheet> createState() => _WorkOrderDetailsSheetState();
}

class _WorkOrderDetailsSheetState extends State<_WorkOrderDetailsSheet> {
  late WorkOrder _workOrder;
  late List<WorkOrderAttachmentItem> _attachments;
  bool _busy = false;
  bool _signing = false;
  late final SignatureController _sigController;
  final List<_PickedProof> _proofFiles = <_PickedProof>[];
  late final TextEditingController _observationsCtrl;
  final Map<String, TextEditingController> _engineHoursControllers =
      <String, TextEditingController>{};

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
    _observationsCtrl = TextEditingController(
      text: _workOrder.description ?? '',
    );
    _syncWorkInputsFromWorkOrder();
  }

  @override
  void dispose() {
    _sigController.dispose();
    _observationsCtrl.dispose();
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
  bool get _isSigned =>
      _workOrder.signatureUrl != null && _workOrder.signatureUrl!.isNotEmpty;
  bool get _canSign => (_isWorker || _isAdmin) && !_isSigned;

  bool get _canDeleteMedia {
    if (_isAdmin || _canEditPart) {
      return true;
    }
    return !_isSigned;
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
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
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
                    label: 'Creado',
                    value: _workOrder.createdAt.toLocal().toString(),
                  ),
                  const SizedBox(height: 16),
                  _buildWorkLogSection(),
                  const SizedBox(height: 14),
                  _buildSignatureSection(),
                ],
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
          'Actualiza observaciones y horas de motor antes de cerrar o firmar el parte.',
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
          NavalgoFormFieldBlock(
            label: 'Observaciones',
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
            const SizedBox(height: 16),
            _buildProofAttachmentsPanel(
              title: 'Pruebas adjuntas a esta firma',
              emptyText: 'No hay pruebas adjuntas registradas en este cierre.',
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
            const SizedBox(height: 16),
            _buildProofAttachmentsPanel(
              title: 'Pruebas vinculadas al cierre',
              emptyText: 'Todavía no hay pruebas adjuntas a este parte.',
            ),
          ],
        ),
      );
    }

    return _buildSectionCard(
      title: 'Firma y cierre',
      subtitle:
          'Dibuja la firma y añade pruebas opcionales que viajarán junto al cierre del parte.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildProofAttachmentsPanel(
              title: 'Pruebas ya guardadas',
              emptyText: 'No hay pruebas guardadas todavía.',
            ),
          ],
          const SizedBox(height: 10),
          Container(
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pruebas adjuntas a esta firma',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fotos o vídeos opcionales que se enviarán junto con la firma, no como multimedia general del parte.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _busy || _signing ? null : _pickProof,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Añadir prueba'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_proofFiles.isEmpty)
                  Text(
                    'No has añadido pruebas para esta firma.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _proofFiles
                        .map(
                          (proof) => Chip(
                            avatar: Icon(
                              proof.mimeType.startsWith('video/')
                                  ? Icons.videocam
                                  : Icons.image,
                              size: 16,
                            ),
                            label: Text(
                              proof.fileName,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: _busy || _signing
                                ? null
                                : () =>
                                      setState(() => _proofFiles.remove(proof)),
                          ),
                        )
                        .toList(),
                  ),
              ],
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

  Widget _buildProofAttachmentsPanel({
    required String title,
    required String emptyText,
  }) {
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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Aquí solo se muestran las evidencias vinculadas al cierre del parte.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_attachments.isEmpty)
            Text(emptyText, style: Theme.of(context).textTheme.bodyMedium)
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
                        title: Text(item.originalFileName ?? 'Prueba adjunta'),
                        subtitle: Text(
                          item.capturedAt == null
                              ? item.fileUrl
                              : 'Hora: ${item.capturedAt!.toLocal()}',
                        ),
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

  Future<void> _saveWorkLogChanges() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
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

  Future<void> _pickProof() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
      );
      if (result == null) return;
      for (final file in result.files) {
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          setState(
            () => _proofFiles.add(
              _PickedProof(
                fileName: file.name,
                bytes: file.bytes!,
                mimeType: _guessMimeType(file.name),
              ),
            ),
          );
        }
      }
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickMedia();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? _guessMimeType(picked.name);
      setState(
        () => _proofFiles.add(
          _PickedProof(fileName: picked.name, bytes: bytes, mimeType: mime),
        ),
      );
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
      final signatureBytes = await _sigController.toPngBytes();
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
        proofFiles: _proofFiles
            .map(
              (p) => ProofFile(
                fileName: p.fileName,
                bytes: p.bytes,
                mimeType: p.mimeType,
              ),
            )
            .toList(),
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
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _updateWorkOrder(updated);
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
        _updateWorkOrder(updated);
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
        _updateWorkOrder(updated);
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

  void _updateWorkOrder(WorkOrder updated, {bool syncInputs = false}) {
    _workOrder = updated;
    _attachments = _resolveAttachments(updated);
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
  if (label.contains('babor') || label.contains('port')) {
    return Icons.keyboard_double_arrow_left_rounded;
  }
  if (label.contains('estribor') || label.contains('starboard')) {
    return Icons.keyboard_double_arrow_right_rounded;
  }
  if (label.contains('central') || label.contains('main')) {
    return Icons.tune_rounded;
  }
  if (label.contains('aux')) {
    return Icons.settings_input_component_outlined;
  }
  if (label.contains('proa')) {
    return Icons.north_rounded;
  }
  if (label.contains('popa')) {
    return Icons.south_rounded;
  }
  return Icons.precision_manufacturing_outlined;
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
  });

  final int ownerId;
  final int? vesselId;
  final List<int> workerIds;
  final bool highPriority;
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
  late final Set<int> _selectedWorkers;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.workOrder.ownerId;
    _vesselId = widget.workOrder.vesselId;
    _highPriority =
        widget.workOrder.priority == 'HIGH' ||
        widget.workOrder.priority == 'URGENT';
    _selectedWorkers = widget.workOrder.workerIds.toSet();
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
            Navigator.pop(
              context,
              _EditPartInput(
                ownerId: _ownerId,
                vesselId: _vesselId,
                workerIds: _selectedWorkers.toList(),
                highPriority: _highPriority,
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
    required this.engineHours,
    required this.attachments,
    required this.priority,
  });

  final String title;
  final String description;
  final int ownerId;
  final int? vesselId;
  final List<int> workerIds;
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
  late int _ownerId;
  int? _vesselId;
  bool _highPriority = false;
  final Set<int> _selectedWorkers = <int>{};
  final Map<String, TextEditingController> _engineHoursControllers =
      <String, TextEditingController>{};
  String? _validationError;

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
            if (_engineHoursControllers.isNotEmpty) ...[
              const SizedBox(height: 14),
              NavalgoFormFieldBlock(
                label: 'Horas por motor',
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

class _PickedProof {
  const _PickedProof({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final List<int> bytes;
  final String mimeType;
}
