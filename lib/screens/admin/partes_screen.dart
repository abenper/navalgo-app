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
import '../../services/work_order_service.dart';
import '../../viewmodels/fleet_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/work_orders_view_model.dart';
import '../../viewmodels/workers_view_model.dart';

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
        const SnackBar(content: Text('Crea un propietario antes de crear partes')),
      );
      return;
    }

    final input = await showModalBottomSheet<_CreatePartInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
            .map((item) => <String, dynamic>{
                  'engineLabel': item.engineLabel,
                  'hours': item.hours,
                })
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
    await showModalBottomSheet<void>(
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
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
    final isAdmin = context.watch<SessionViewModel>().user?.role == 'ADMIN';
    final workOrders = vm.workOrders;
    final signedCount = vm.workOrders.where((item) => item.signatureUrl?.isNotEmpty ?? false).length;
    final pendingSignatureCount = vm.workOrders.where((item) => item.signatureUrl?.isEmpty ?? true).length;
    final highPriorityCount = vm.workOrders.where((item) => _isHighPriority(item.priority)).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(child: Text(vm.error!))
              : RefreshIndicator(
                  onRefresh: () async {
                    final session = context.read<SessionViewModel>();
                    await vm.loadWorkOrders(
                      workerId: session.user?.role == 'ADMIN' ? null : session.user?.id,
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
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0B2D3A), Color(0xFF124B61), Color(0xFF1F6A7D)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0B2D3A).withValues(alpha: 0.22),
                                      blurRadius: 32,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cuaderno de Taller Naval',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Gestiona partes, firmas y evidencias con una vista más clara para operaciones de muelle y mantenimiento.',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.84),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      spacing: 14,
                                      runSpacing: 14,
                                      children: [
                                        _FleetMetricCard(
                                          label: 'Firmados',
                                          value: '$signedCount',
                                          tone: const Color(0xFF3BAA6E),
                                        ),
                                        _FleetMetricCard(
                                          label: 'Pendientes de firma',
                                          value: '$pendingSignatureCount',
                                          tone: const Color(0xFFD55A4E),
                                        ),
                                        _FleetMetricCard(
                                          label: 'Prioridad alta',
                                          value: '$highPriorityCount',
                                          tone: const Color(0xFFD5A021),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              Text(
                                'Partes activos',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFF102B36),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Verde para firmados, rojo para pendientes de firma y etiqueta amarilla para prioridad alta.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF5A707A),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (workOrders.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFDAE5EA)),
                                  ),
                                  child: const Text(
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
                      final bool isSigned = parte.signatureUrl?.isNotEmpty ?? false;
                      final bool isHighPriority = _isHighPriority(parte.priority);
                      final Color accentColor = isSigned
                          ? const Color(0xFF3BAA6E)
                          : const Color(0xFFD55A4E);
                      final Color surfaceColor = isSigned
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
                                    border: Border.all(color: accentColor.withValues(alpha: 0.28)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.08),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        width: 8,
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
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
                                                          parte.title,
                                                          style: const TextStyle(
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.w800,
                                                            color: Color(0xFF0F2530),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          parte.ownerName,
                                                          style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF40606C),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isAdmin)
                                                    IconButton(
                                                      tooltip: 'Borrar parte',
                                                      onPressed: () => _deleteWorkOrderFromList(parte),
                                                      icon: const Icon(Icons.delete_outline),
                                                      color: const Color(0xFF9B2C20),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF64808B)),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _PartBadge(
                                                    label: isSigned ? 'Firmado' : 'Pendiente de firma',
                                                    textColor: accentColor,
                                                    backgroundColor: accentColor.withValues(alpha: 0.12),
                                                  ),
                                                  if (isHighPriority)
                                                    const _PartBadge(
                                                      label: 'Prioridad alta',
                                                      textColor: Color(0xFF8A6200),
                                                      backgroundColor: Color(0xFFFFF2CC),
                                                    ),
                                                  if (parte.vesselName != null && parte.vesselName!.trim().isNotEmpty)
                                                    _PartBadge(
                                                      label: parte.vesselName!,
                                                      textColor: const Color(0xFF1E5166),
                                                      backgroundColor: const Color(0xFFDDF0F6),
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
                                                style: const TextStyle(color: Color(0xFF738892)),
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
      bottomNavigationBar: isAdmin
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0E4457),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _openCreateDialog,
                        icon: const Icon(Icons.assignment_add),
                        label: const Text('Nuevo parte'),
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
    _sigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _observationsCtrl = TextEditingController(text: _workOrder.description ?? '');
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
  bool get _hasEditPermission => context.read<SessionViewModel>().user?.canEditWorkOrders ?? false;
  bool get _canEditPart => _isAdmin || (_isWorker && _hasEditPermission);
  bool get _canUpdateWorkLog => _isAdmin || _isWorker;
  bool get _isSigned => _workOrder.signatureUrl != null && _workOrder.signatureUrl!.isNotEmpty;
  bool get _canSign => _isWorker && !_isSigned;

  bool get _canDeleteMedia {
    if (_isAdmin || _canEditPart) {
      return true;
    }
    return !_isSigned;
  }

  @override
  Widget build(BuildContext context) {
    final attachments = _workOrder.attachments.isNotEmpty
        ? _workOrder.attachments
        : _workOrder.attachmentUrls
            .map((url) => WorkOrderAttachmentItem(
                  id: null,
                  fileUrl: url,
                  fileType: url.toLowerCase().endsWith('.mp4') ? 'VIDEO' : 'IMAGE',
                  originalFileName: null,
                  capturedAt: null,
                  latitude: null,
                  longitude: null,
                  watermarked: false,
                  audioRemoved: false,
                ))
            .toList();

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
                if (_isHighPriority(_workOrder.priority)) const Chip(label: Text('Prioridad alta')),
                if (_isSigned) const Chip(label: Text('Firmado')),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  _DetailRow(label: 'Propietario', value: _workOrder.ownerName),
                  _DetailRow(label: 'Embarcacion', value: _workOrder.vesselName ?? 'Sin embarcacion'),
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
                  const SizedBox(height: 10),
                  const Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _observationsCtrl,
                    readOnly: !_canUpdateWorkLog || _busy,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Añadir observaciones del trabajo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Horas de motor', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (_engineHoursControllers.isEmpty)
                    const Text('Sin motores disponibles para este parte')
                  else
                    ..._engineHoursControllers.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: entry.value,
                          readOnly: !_canUpdateWorkLog || _busy,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: entry.key,
                            border: const OutlineInputBorder(),
                            hintText: 'Horas',
                          ),
                        ),
                      ),
                    ),
                  if (_canUpdateWorkLog) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _saveWorkLogChanges,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar horas y observaciones'),
                      ),
                    ),
                  ],
                  if (_workOrder.engineHours.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Ultimo registro guardado', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ..._workOrder.engineHours.map(
                      (item) => _DetailRow(label: item.engineLabel, value: '${item.hours} h'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Firma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  if (_isSigned) ...[
                    Text(
                      'Firmado por: ${_workOrder.signedByWorkerName ?? 'Usuario no disponible'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (_workOrder.signedAt != null)
                      Text('Firmado el: ${_workOrder.signedAt!.toLocal()}'),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 3.4,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          _workOrder.signatureUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text('No se pudo cargar la firma'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openExternal(_workOrder.signatureUrl!),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir firma'),
                        ),
                        const SizedBox(width: 8),
                        if (_canEditPart)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _clearSignature,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Borrar firma'),
                          ),
                      ],
                    ),
                  ] else ...[
                    const Text('Este parte todavia no tiene firma.'),
                    if (_canSign) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Signature(
                            controller: _sigController,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _busy || _signing ? null : _sigController.clear,
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Borrar firma'),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Evidencias para firma',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _busy || _signing ? null : _pickProof,
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: const Text('Añadir'),
                          ),
                        ],
                      ),
                      if (_proofFiles.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _proofFiles
                              .map((proof) => Chip(
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
                                        : () => setState(() => _proofFiles.remove(proof)),
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy || _signing ? null : _submitInlineSignature,
                          icon: _signing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.draw),
                          label: Text(_signing ? 'Enviando...' : 'Firmar y enviar'),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  const Text('Multimedia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  if (_canDeleteMedia)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickAndUploadMediaForPart,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Añadir multimedia'),
                      ),
                    ),
                  if (attachments.isEmpty)
                    const Text('Sin adjuntos')
                  else
                    ...attachments.map((item) {
                      return Card(
                        child: ListTile(
                          leading: Icon(item.fileType == 'VIDEO' ? Icons.videocam : Icons.image),
                          title: Text(item.originalFileName ?? 'Adjunto'),
                          subtitle: Text(item.capturedAt == null
                              ? item.fileUrl
                              : 'Hora: ${item.capturedAt!.toLocal()}'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () => _openExternal(item.fileUrl),
                                icon: const Icon(Icons.open_in_new),
                              ),
                              if (_canDeleteMedia)
                                IconButton(
                                  onPressed: _busy ? null : () => _deleteAttachment(item),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
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
                    icon: Icon(Icons.delete_forever, color: Colors.red.shade700),
                    label: Text('Borrar parte', style: TextStyle(color: Colors.red.shade700)),
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

  Future<void> _openExternal(String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
        AppToast.warning(context, 'Todas las horas de motor deben ser numeros enteros.');
        return;
      }
      engineHours.add({'engineLabel': entry.key, 'hours': parsed});
    }
    final engineHoursPayload = _engineHoursControllers.isEmpty ? null : engineHours;

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
        _workOrder = updated;
        _syncWorkInputsFromWorkOrder();
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
          setState(() => _proofFiles.add(_PickedProof(
                fileName: file.name,
                bytes: file.bytes!,
                mimeType: _guessMimeType(file.name),
              )));
        }
      }
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickMedia();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? _guessMimeType(picked.name);
      setState(() => _proofFiles.add(_PickedProof(
            fileName: picked.name,
            bytes: bytes,
            mimeType: mime,
          )));
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
            .map((p) => ProofFile(
                  fileName: p.fileName,
                  bytes: p.bytes,
                  mimeType: p.mimeType,
                ))
            .toList(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (!mounted) {
        return;
      }
      await _reloadFromServer();
      if (!mounted) {
        return;
      }
      setState(() {
        _proofFiles.clear();
        _sigController.clear();
      });
      AppToast.success(context, 'Parte firmado correctamente.');
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

  Future<void> _pickAndUploadMediaForPart() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      AppToast.error(context, 'No hay sesion activa para subir archivos.');
      return;
    }

    final mediaService = context.read<WorkOrderMediaService>();

    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      Position? position;
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {
        position = null;
      }

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
        final updated = await mediaService.attachToWorkOrder(
          token,
          workOrderId: _workOrder.id,
          fileName: file.name,
          bytes: bytes,
          mimeType: _guessMimeType(file.name),
          latitude: position?.latitude,
          longitude: position?.longitude,
          capturedAt: DateTime.now(),
        );
        _workOrder = updated;
      }

      if (!mounted) {
        return;
      }
      setState(() {});
      AppToast.success(context, 'Multimedia subida correctamente.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo subir multimedia: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
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

    final result = await showModalBottomSheet<_EditPartInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
        _workOrder = updated;
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
        content: Text('¿Seguro que quieres eliminar "${_workOrder.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
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
      await context.read<WorkOrderService>().deleteWorkOrder(token, workOrderId: _workOrder.id);
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
        _workOrder = updated;
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
        content: const Text('Esta accion no se puede deshacer. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
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
        _workOrder = updated;
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
      for (final entry in _engineHoursControllers.entries) entry.key: entry.value.text,
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

  bool _isHighPriority(String priority) {
    return priority == 'HIGH' || priority == 'URGENT';
  }

  List<String> _resolveEngineLabelsFromWorkOrder() {
    final fleetVm = context.read<FleetViewModel>();
    final vessel = fleetVm.vessels.where((item) => item.id == _workOrder.vesselId).firstOrNull;
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

  Future<void> _reloadFromServer() async {
    final session = context.read<SessionViewModel>();
    final vm = context.read<WorkOrdersViewModel>();
    await vm.loadWorkOrders(workerId: _isAdmin ? null : session.user?.id);
    final updated = vm.workOrders.where((item) => item.id == _workOrder.id).firstOrNull;
    if (updated != null && mounted) {
      setState(() {
        _workOrder = updated;
        _syncWorkInputsFromWorkOrder();
      });
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
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
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
  late int _ownerId;
  int? _vesselId;
  late bool _highPriority;
  late final Set<int> _selectedWorkers;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.workOrder.ownerId;
    _vesselId = widget.workOrder.vesselId;
    _highPriority = widget.workOrder.priority == 'HIGH' || widget.workOrder.priority == 'URGENT';
    _selectedWorkers = widget.workOrder.workerIds.toSet();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerVessels = widget.vessels.where((v) => v.ownerId == _ownerId).toList();
    final validVessel = ownerVessels.any((v) => v.id == _vesselId) ? _vesselId : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Editar parte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                widget.workOrder.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _ownerId,
                decoration: const InputDecoration(labelText: 'Propietario', border: OutlineInputBorder()),
                items: widget.owners
                    .map((o) => DropdownMenuItem<int>(value: o.id, child: Text(o.displayName)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _ownerId = value;
                    if (!widget.vessels.any((v) => v.ownerId == _ownerId && v.id == _vesselId)) {
                      _vesselId = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: validVessel,
                decoration: const InputDecoration(labelText: 'Embarcacion', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sin embarcacion')),
                  ...ownerVessels.map((v) => DropdownMenuItem<int?>(value: v.id, child: Text(v.name))),
                ],
                onChanged: (value) => setState(() => _vesselId = value),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _highPriority,
                onChanged: (value) => setState(() => _highPriority = value ?? false),
                title: const Text('Prioridad alta'),
                subtitle: const Text('Resalta este parte en amarillo en el panel principal.'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Mecanicos asignados',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 180,
                child: ListView(
                  children: widget.workers.map((worker) {
                    final selected = _selectedWorkers.contains(worker.id);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(worker.fullName),
                      subtitle: Text(worker.role),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedWorkers.add(worker.id);
                          } else {
                            _selectedWorkers.remove(worker.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
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
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  late int _ownerId;
  int? _vesselId;
  bool _highPriority = false;
  bool _uploadingMedia = false;
  final Set<int> _selectedWorkers = <int>{};
  final List<WorkOrderAttachmentItem> _uploadedAttachments = <WorkOrderAttachmentItem>[];
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nuevo Parte',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titulo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _ownerId,
                  decoration: const InputDecoration(
                    labelText: 'Propietario',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.owners
                      .map((o) => DropdownMenuItem(value: o.id, child: Text(o.displayName)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _ownerId = v ?? _ownerId;
                    });
                    _syncVesselSelectionForOwner();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: _vesselId,
                  decoration: const InputDecoration(
                    labelText: 'Embarcacion',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sin embarcacion'),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingMedia ? null : _pickAndUploadMedia,
                        icon: _uploadingMedia
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_uploadingMedia ? 'Subiendo...' : 'Subir foto/video (web)'),
                      ),
                    ),
                  ],
                ),
                if (_uploadedAttachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _uploadedAttachments
                        .map((item) => Chip(
                              avatar: Icon(
                                item.fileType == 'VIDEO' ? Icons.videocam : Icons.image,
                                size: 18,
                              ),
                              label: Text(item.originalFileName ?? 'Adjunto'),
                              onDeleted: () {
                                setState(() {
                                  _uploadedAttachments.remove(item);
                                });
                              },
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _highPriority,
                  onChanged: (value) => setState(() => _highPriority = value ?? false),
                  title: const Text('Prioridad alta'),
                  subtitle: const Text('Mostrará este parte como destacado en el panel de operaciones.'),
                ),
                if (_engineHoursControllers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Horas de motor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ..._engineHoursControllers.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: entry.key,
                          hintText: 'Horas',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Asignar trabajadores',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 180,
                  child: ListView(
                    children: widget.workers.map((worker) {
                      final selected = _selectedWorkers.contains(worker.id);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(worker.fullName),
                        subtitle: Text(worker.role),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedWorkers.add(worker.id);
                            } else {
                              _selectedWorkers.remove(worker.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                if (_validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Crear'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() {
        _validationError = 'El titulo es obligatorio.';
      });
      return;
    }

    final engineHours = <EngineHourLog>[];
    for (final entry in _engineHoursControllers.entries) {
      final hours = int.tryParse(entry.value.text.trim());
      if (hours == null) {
        setState(() {
          _validationError = 'Rellena las horas de todos los motores con numeros enteros.';
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
        attachments: List<WorkOrderAttachmentItem>.from(_uploadedAttachments),
        priority: _highPriority ? 'HIGH' : 'NORMAL',
      ),
    );
  }

  Future<void> _pickAndUploadMedia() async {
    if (!kIsWeb) {
      AppToast.warning(context, 'La subida de multimedia esta habilitada solo en la web.');
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      AppToast.error(context, 'No hay sesion activa para subir archivos.');
      return;
    }

    setState(() {
      _uploadingMedia = true;
    });

    final mediaService = context.read<WorkOrderMediaService>();

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      Position? position;
      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {
        position = null;
      }

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          continue;
        }

        final owner = widget.owners.where((o) => o.id == _ownerId).firstOrNull;
        final vessel = widget.vessels.where((v) => v.id == _vesselId).firstOrNull;

        final uploaded = await mediaService.uploadMedia(
          token,
          fileName: file.name,
          bytes: bytes,
          mimeType: _guessMimeType(file.name),
          latitude: position?.latitude,
          longitude: position?.longitude,
          capturedAt: DateTime.now(),
          ownerName: owner?.displayName,
          vesselName: vessel?.name,
          workOrderDate: DateTime.now(),
        );

        _uploadedAttachments.add(uploaded);
      }

      if (!mounted) {
        return;
      }
      setState(() {});
      AppToast.success(context, 'Multimedia subida correctamente.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo subir multimedia: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingMedia = false;
        });
      }
    }
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

  void _syncVesselSelectionForOwner() {
    final vessels = widget.vessels.where((vessel) => vessel.ownerId == _ownerId).toList();
    if (vessels.isEmpty) {
      _vesselId = null;
    } else if (_vesselId == null || !vessels.any((vessel) => vessel.id == _vesselId)) {
      _vesselId = vessels.first.id;
    }
    _syncEngineHoursForSelectedVessel();
  }

  void _syncEngineHoursForSelectedVessel() {
    final vessel = widget.vessels.where((item) => item.id == _vesselId).cast<Vessel?>().firstOrNull;
    final labels = vessel == null ? <String>[] : _resolveEngineLabels(vessel);

    final existingValues = <String, String>{
      for (final entry in _engineHoursControllers.entries) entry.key: entry.value.text,
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

class _FleetMetricCard extends StatelessWidget {
  const _FleetMetricCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PickedProof {
  const _PickedProof(
      {required this.fileName,
      required this.bytes,
      required this.mimeType});

  final String fileName;
  final List<int> bytes;
  final String mimeType;
}
