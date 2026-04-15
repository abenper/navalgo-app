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

      await fleetViewModel.loadFleet();
      if (user.role == 'ADMIN') {
        await workersViewModel.loadWorkers();
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

  Future<void> _updateStatus(int id, String status) async {
    await context.read<WorkOrdersViewModel>().updateWorkOrderStatus(
      workOrderId: id,
      status: status,
    );
  }

  Future<void> _openWorkerParteDialog(WorkOrder parte) async {
    final session = context.read<SessionViewModel>();
    final workOrdersVm = context.read<WorkOrdersViewModel>();

    if (parte.signatureUrl != null) {
      // Already signed: just show attachments
      await _openAttachmentsDialog(parte);
      return;
    }

    final signed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => _WorkerSignDialog(parte: parte),
    );

    if (signed == true && mounted) {
      AppToast.success(context, 'Parte firmado correctamente.');
      await workOrdersVm.loadWorkOrders(workerId: session.user?.id);
    }
  }

  Future<void> _openAttachmentsDialog(WorkOrder parte) async {    if (parte.attachments.isEmpty && parte.attachmentUrls.isEmpty) {
      AppToast.info(context, 'Este parte no tiene adjuntos.');
      return;
    }

    final attachments = parte.attachments.isNotEmpty
        ? parte.attachments
        : parte.attachmentUrls
            .map((url) => WorkOrderAttachmentItem(
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

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adjuntos del parte',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: attachments.length,
                    itemBuilder: (context, index) {
                      final item = attachments[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            item.fileType == 'VIDEO' ? Icons.videocam : Icons.image,
                            color: item.fileType == 'VIDEO' ? Colors.deepPurple : Colors.blue,
                          ),
                          title: Text(item.originalFileName ?? 'Adjunto ${index + 1}'),
                          subtitle: Text(
                            item.capturedAt == null
                                ? item.fileUrl
                                : 'Hora: ${item.capturedAt!.toLocal()}\nGPS: ${item.latitude?.toStringAsFixed(5) ?? 'N/D'}, ${item.longitude?.toStringAsFixed(5) ?? 'N/D'}',
                          ),
                          isThreeLine: item.capturedAt != null,
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () async {
                              final uri = Uri.parse(item.fileUrl);
                              final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!opened && context.mounted) {
                                AppToast.error(context, 'No se pudo abrir el adjunto');
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markUrgent(WorkOrder parte) async {
    final session = context.read<SessionViewModel>();
    final workOrderService = context.read<WorkOrderService>();
    final workOrdersViewModel = context.read<WorkOrdersViewModel>();
    final token = session.token;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) {
      return;
    }

    try {
      await workOrderService.updateWorkOrder(
            token,
            workOrderId: parte.id,
            priority: 'URGENT',
          );
      await workOrdersViewModel.loadWorkOrders(
        workerId: session.user?.role == 'ADMIN' ? null : session.user?.id,
      );
      if (!mounted) {
        return;
      }
      AppToast.warning(context, 'Parte marcado como URGENTE');
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('No se pudo marcar urgente: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkOrdersViewModel>();
    final isAdmin = context.watch<SessionViewModel>().user?.role == 'ADMIN';

    return Scaffold(
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
                    padding: const EdgeInsets.all(16),
                    itemCount: vm.workOrders.length,
                    itemBuilder: (context, index) {
                      final WorkOrder parte = vm.workOrders[index];
                      final bool isUrgent = parte.priority == 'URGENT';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isUrgent ? Colors.red.shade100 : Colors.blue.shade100,
                            child: Icon(
                              Icons.build,
                              color: isUrgent ? Colors.red.shade900 : Colors.blue.shade900,
                            ),
                          ),
                          title: Text(
                            parte.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Cliente: ${parte.ownerName}\n'
                            'Asignado: ${parte.workerNames.isEmpty ? 'Sin asignar' : parte.workerNames.join(', ')}\n'
                            'Estado: ${parte.status} • Prioridad: ${parte.priority}'
                            '${parte.signatureUrl != null ? ' • ✓ Firmado' : ''}',
                          ),
                          isThreeLine: true,
                          onTap: () => isAdmin
                              ? _openAttachmentsDialog(parte)
                              : _openWorkerParteDialog(parte),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'MARK_URGENT') {
                                _markUrgent(parte);
                                return;
                              }
                              _updateStatus(parte.id, value);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'NEW', child: Text('Pendiente')),
                              const PopupMenuItem(value: 'IN_PROGRESS', child: Text('En curso')),
                              const PopupMenuItem(value: 'DONE', child: Text('Finalizado')),
                              const PopupMenuItem(value: 'CANCELLED', child: Text('Cancelado')),
                              if (isAdmin && parte.priority != 'URGENT')
                                const PopupMenuItem(
                                  value: 'MARK_URGENT',
                                  child: Text('Marcar como urgente'),
                                ),
                            ],
                            child: Chip(
                              label: Text(parte.priority == 'URGENT' ? 'URGENTE' : parte.status),
                              backgroundColor: _statusColor(parte.status).withValues(alpha: 0.12),
                              side: BorderSide.none,
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
                child: FilledButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Nuevo Parte'),
                ),
              ),
            )
          : null,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DONE':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blue;
    }
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
  String _priority = 'NORMAL';
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
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridad',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text('LOW')),
                    DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                    DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
                    DropdownMenuItem(value: 'URGENT', child: Text('URGENT')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'NORMAL'),
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
        priority: _priority,
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
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov'],
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

        final uploaded = await mediaService.uploadMedia(
          token,
          fileName: file.name,
          bytes: bytes,
          mimeType: _guessMimeType(file.name),
          latitude: position?.latitude,
          longitude: position?.longitude,
          capturedAt: DateTime.now(),
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
      case 'webp':
        return 'image/webp';
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

// ===================================================================
// _WorkerSignDialog: firma digital + adjuntar fotos/videos desde cámara
// ===================================================================
class _WorkerSignDialog extends StatefulWidget {
  const _WorkerSignDialog({required this.parte});

  final WorkOrder parte;

  @override
  State<_WorkerSignDialog> createState() => _WorkerSignDialogState();
}

class _WorkerSignDialogState extends State<_WorkerSignDialog> {
  late final SignatureController _sigController;
  final List<_PickedProof> _proofFiles = [];
  bool _signing = false;

  @override
  void initState() {
    super.initState();
    _sigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Firmar Parte: ${widget.parte.title}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Cliente: ${widget.parte.ownerName}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu firma',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
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
                    onPressed: _sigController.clear,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Borrar firma'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Fotos/Videos de evidencia',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _pickProof,
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
                              onDeleted: () {
                                setState(() => _proofFiles.remove(proof));
                              },
                            ))
                        .toList(),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _signing ? null : _submit,
                    icon: _signing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.draw),
                    label: Text(_signing ? 'Enviando...' : 'Firmar y enviar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickProof() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov'],
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

  Future<void> _submit() async {
    if (!_sigController.isNotEmpty) {
      AppToast.warning(context, 'Dibuja tu firma antes de enviar.');
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) return;

    setState(() => _signing = true);

    final mediaService = context.read<WorkOrderMediaService>();

    try {
      final signatureBytes =
          await _sigController.toPngBytes();
      if (signatureBytes == null) throw Exception('No se pudo exportar la firma');

      Position? position;
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          position = await Geolocator.getCurrentPosition();
        }
      } catch (_) {}

      await mediaService.signWorkOrder(
        token,
        workOrderId: widget.parte.id,
        signatureFileName: 'firma_parte_${widget.parte.id}.png',
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

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _signing = false);
      AppToast.error(context, 'Error al firmar: $e');
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
      case 'webp':
        return 'image/webp';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'video/mp4';
    }
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
