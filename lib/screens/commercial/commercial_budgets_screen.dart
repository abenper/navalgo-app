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
import '../../widgets/navalgo_ui.dart';
import '../../widgets/pdf_preview.dart';

class CommercialBudgetsScreen extends StatefulWidget {
  const CommercialBudgetsScreen({super.key});

  @override
  State<CommercialBudgetsScreen> createState() => _CommercialBudgetsScreenState();
}

class _CommercialBudgetsScreenState extends State<CommercialBudgetsScreen> {
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;
  List<Budget> _budgets = const <Budget>[];
  List<Owner> _owners = const <Owner>[];
  List<Vessel> _vessels = const <Vessel>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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
      final budgets = await budgetService.getBudgets(token);
      final owners = await fleetService.getOwners(token);
      final vessels = await fleetService.getVessels(token);
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
    if (_owners.isEmpty || _vessels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero necesitas tener clientes y embarcaciones.'),
        ),
      );
      return;
    }

    final draft = await showDialog<_BudgetDraft>(
      context: context,
      builder: (_) => _CreateBudgetDialog(
        owners: _owners,
        vessels: _vessels,
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

    setState(() {
      _isCreating = true;
    });

    try {
      final uploaded = await budgetService.uploadBudgetPdf(
        token,
        ownerId: draft.ownerId,
        vesselId: draft.vesselId,
        fileName: draft.fileName,
        bytes: draft.fileBytes,
      );
      await budgetService.createBudget(
        token,
        ownerId: draft.ownerId,
        vesselId: draft.vesselId,
        contactEmail: draft.contactEmail,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presupuesto eliminado.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el presupuesto: $error')),
      );
    }
  }

  Future<void> _showPdfPreview(String objectUrl, Uint8List bytes, String title) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        final dialogWidth = math.min(MediaQuery.of(context).size.width * 0.92, 900.0);
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
      final bytes = await context.read<BudgetService>().downloadBudgetPdf(token, budget.pdfUrl);
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      final objectUrl = browser_file.createObjectUrlFromBytes(bytes, mimeType: 'application/pdf');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar el PDF: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentCount = _budgets.where((budget) => budget.status == 'SENT').length;
    final draftCount = _budgets.where((budget) => budget.status == 'DRAFT').length;
    final answeredCount = _budgets
        .where(
          (budget) =>
              budget.status == 'ACCEPTED' || budget.status == 'REJECTED',
        )
        .length;

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
                const NavalgoSectionHeader(
                  title: 'Listado',
                  subtitle:
                      'Desde aqu\u00ED controlas el estado del presupuesto y abres el PDF cuando lo necesites.',
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
                else
                  ..._budgets.map(
                    (budget) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BudgetCard(
                        budget: budget,
                        onOpenPdf: () => _openPdf(budget),
                        onSend: budget.status == 'DRAFT'
                            ? () => _sendBudget(budget)
                            : null,
                        onDelete: () => _deleteBudget(budget),
                      ),
                    ),
                  ),
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
    this.onSend,
    this.onDelete,
  });

  final Budget budget;
  final VoidCallback onOpenPdf;
  final VoidCallback? onSend;
  final VoidCallback? onDelete;

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
              if (onSend != null)
                FilledButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar al cliente'),
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
  });

  final List<Owner> owners;
  final List<Vessel> vessels;

  @override
  State<_CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends State<_CreateBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  int? _ownerId;
  int? _vesselId;
  PlatformFile? _pickedFile;
  List<int>? _pickedFileBytes;

  @override
  void initState() {
    super.initState();
    _ownerId = null;
    _vesselId = null;
    _contactEmailCtrl.text = '';
    _searchCtrl.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_handleSearchChanged);
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _contactEmailCtrl.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      final query = _searchCtrl.text.trim();
      if (query.isEmpty) {
        _ownerId = null;
        _vesselId = null;
        return;
      }
      _syncOwnerSelectionForSearch();
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

  List<Vessel> get _availableVessels => widget.vessels
      .where((vessel) => vessel.ownerId == _ownerId)
      .toList();

  void _syncVesselSelection() {
    final availableVessels = _availableVessels;
    if (_ownerId == null || availableVessels.isEmpty) {
      _vesselId = null;
      return;
    }
    if (!availableVessels.any((vessel) => vessel.id == _vesselId)) {
      _vesselId = availableVessels.first.id;
    }
  }

  void _syncOwnerSelectionForSearch() {
    final filteredOwners = _filteredOwners;
    if (filteredOwners.isEmpty) {
      _ownerId = null;
      _vesselId = null;
      return;
    }
    if (_ownerId == null || !filteredOwners.any((owner) => owner.id == _ownerId)) {
      _ownerId = filteredOwners.first.id;
      _contactEmailCtrl.text = filteredOwners.first.email ?? '';
      _syncVesselSelection();
    }
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
    _syncVesselSelection();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_ownerId == null || _vesselId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un cliente con embarcacion asociada.'),
        ),
      );
      return;
    }
    final fileBytes = _pickedFileBytes;
    if (_pickedFile == null || fileBytes == null || fileBytes.isEmpty) {
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
            'Indica un correo electrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³nico vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido para enviar el presupuesto.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _BudgetDraft(
        ownerId: _ownerId!,
        vesselId: _vesselId!,
        contactEmail: contactEmail,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        amount: null,
        currency: 'EUR',
        fileName: _pickedFile!.name,
        fileBytes: fileBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOwners = _filteredOwners;
    final availableVessels = _availableVessels;
    final selectedOwnerId = filteredOwners.any((owner) => owner.id == _ownerId)
        ? _ownerId
        : null;
    final selectedVesselId =
        availableVessels.any((vessel) => vessel.id == _vesselId) ? _vesselId : null;
    final screenSize = MediaQuery.of(context).size;
    final maxDialogWidth = screenSize.width * 0.92;
    final contentMaxHeight = screenSize.height - 140;

    return AlertDialog(
      title: const Text('Nuevo presupuesto'),
      content: SizedBox(
        width: maxDialogWidth > 560 ? 560 : maxDialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: contentMaxHeight,
              ),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('owner-${selectedOwnerId ?? 'none'}-${filteredOwners.length}'),
                    initialValue: selectedOwnerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cliente',
                      hintText: 'Selecciona un cliente',
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
                          _contactEmailCtrl.clear();
                          _vesselId = null;
                          return;
                        }
                        final selectedOwner = widget.owners.where(
                          (owner) => owner.id == value,
                        );
                        final owner = selectedOwner.isEmpty ? null : selectedOwner.first;
                        _contactEmailCtrl.text = owner?.email ?? '';
                        _syncVesselSelection();
                      });
                    },
                    validator: (_) {
                      if (filteredOwners.isEmpty) {
                        return 'No hay clientes que coincidan con la b\u00fasqueda.';
                      }
                      if (_ownerId == null) {
                        return 'Selecciona un cliente';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('vessel-${selectedVesselId ?? 'none'}-${availableVessels.length}'),
                    initialValue: selectedVesselId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Embarcaci\u00f3n',
                      hintText: 'Selecciona una embarcaci\u00f3n',
                    ),
                    items: availableVessels
                        .map(
                          (vessel) => DropdownMenuItem<int>(
                            value: vessel.id,
                            child: Text(
                              vessel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _vesselId = value;
                      });
                    },
                    validator: (_) {
                      if (_ownerId == null) {
                        return null;
                      }
                      if (availableVessels.isEmpty) {
                        return 'Ese cliente no tiene embarcaciones.';
                      }
                      if (_vesselId == null) {
                        return 'Selecciona una embarcaci\u00f3n';
                      }
                      return null;
                    },
                  ),
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
                        _pickedFile == null ? 'Adjuntar PDF' : _pickedFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (filteredOwners.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'No hemos encontrado ese cliente. Primero crea el cliente y su embarcaci\u00f3n en Flota, o usa el correo del propietario de una ficha ya existente.',
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
        FilledButton(
          onPressed: _submit,
          child: const Text('Crear borrador'),
        ),
      ],
    );
  }
}

class _BudgetDraft {
  const _BudgetDraft({
    required this.ownerId,
    required this.vesselId,
    required this.contactEmail,
    required this.title,
    this.description,
    this.amount,
    required this.currency,
    required this.fileName,
    required this.fileBytes,
  });

  final int ownerId;
  final int vesselId;
  final String contactEmail;
  final String title;
  final String? description;
  final double? amount;
  final String currency;
  final String fileName;
  final List<int> fileBytes;
}
