import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/budget.dart';
import '../../models/owner.dart';
import '../../models/vessel.dart';
import '../../services/budget_service.dart';
import '../../services/fleet_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

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
        const SnackBar(content: Text('Presupuesto creado en borrador')),
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
                : 'Presupuesto enviado al cliente por correo.',
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

  Future<void> _openPdf(String pdfUrl) async {
    final uri = Uri.tryParse(pdfUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createBudget,
        icon: _isCreating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_circle_outline),
        label: Text(_isCreating ? 'Creando...' : 'Nuevo presupuesto'),
      ),
      body: NavalgoPageBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                NavalgoPageIntro(
                  eyebrow: 'COMERCIAL',
                  title: 'Presupuestos',
                  subtitle:
                      'Crea propuestas ligadas a un cliente y una embarcacion, sube el PDF y envialo por correo desde aqui.',
                  trailing: Container(
                    width: 320,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.request_quote_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Flujo actual',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ya puedes crear borradores y enviarlos al cliente. La aceptacion y rechazo desde portal cliente sera el siguiente bloque.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final cardWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: NavalgoMetricCard(
                            label: 'Borradores',
                            value: '$draftCount',
                            icon: const Icon(Icons.edit_note_outlined),
                            accent: NavalgoColors.tide,
                            note: 'Listos para revisar antes de enviar.',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: NavalgoMetricCard(
                            label: 'Enviados',
                            value: '$sentCount',
                            icon: const Icon(Icons.mark_email_read_outlined),
                            accent: NavalgoColors.sand,
                            note: 'Pendientes de respuesta del cliente.',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: NavalgoMetricCard(
                            label: 'Respondidos',
                            value: '$answeredCount',
                            icon: const Icon(Icons.rule_folder_outlined),
                            accent: NavalgoColors.kelp,
                            note: 'Aceptados o rechazados por el cliente.',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const NavalgoSectionHeader(
                  title: 'Listado',
                  subtitle:
                      'Desde aqui controlas el estado del presupuesto y abres el PDF cuando lo necesites.',
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  NavalgoPanel(child: Text(_error!))
                else if (_budgets.isEmpty)
                  const NavalgoPanel(
                    child: Text(
                      'Aun no hay presupuestos creados. Usa el boton de abajo para preparar el primero.',
                    ),
                  )
                else
                  ..._budgets.map(
                    (budget) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BudgetCard(
                        budget: budget,
                        onOpenPdf: () => _openPdf(budget.pdfUrl),
                        onSend: budget.status == 'DRAFT'
                            ? () => _sendBudget(budget)
                            : null,
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
  });

  final Budget budget;
  final VoidCallback onOpenPdf;
  final VoidCallback? onSend;

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
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  int? _ownerId;
  int? _vesselId;
  String _currency = 'EUR';
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.owners.first.id;
    _syncVesselSelection();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<Vessel> get _availableVessels => widget.vessels
      .where((vessel) => vessel.ownerId == _ownerId)
      .toList();

  void _syncVesselSelection() {
    final availableVessels = _availableVessels;
    if (availableVessels.isEmpty) {
      _vesselId = null;
      return;
    }
    if (!availableVessels.any((vessel) => vessel.id == _vesselId)) {
      _vesselId = availableVessels.first.id;
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    setState(() {
      _pickedFile = result.files.first;
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
    final fileBytes = _pickedFile?.bytes;
    if (_pickedFile == null || fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta un PDF para el presupuesto.')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));

    Navigator.of(context).pop(
      _BudgetDraft(
        ownerId: _ownerId!,
        vesselId: _vesselId!,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        amount: amount,
        currency: _currency,
        fileName: _pickedFile!.name,
        fileBytes: fileBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableVessels = _availableVessels;

    return AlertDialog(
      title: const Text('Nuevo presupuesto'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _ownerId,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  items: widget.owners
                      .map(
                        (owner) => DropdownMenuItem<int>(
                          value: owner.id,
                          child: Text(owner.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _ownerId = value;
                      _syncVesselSelection();
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _vesselId,
                  decoration: const InputDecoration(labelText: 'Embarcacion'),
                  items: availableVessels
                      .map(
                        (vessel) => DropdownMenuItem<int>(
                          value: vessel.id,
                          child: Text(vessel.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _vesselId = value;
                    });
                  },
                  validator: (_) {
                    if (availableVessels.isEmpty) {
                      return 'Ese cliente no tiene embarcaciones.';
                    }
                    if (_vesselId == null) {
                      return 'Selecciona una embarcacion';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titulo'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce un titulo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountCtrl,
                        decoration: const InputDecoration(labelText: 'Importe'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: 'Moneda'),
                        items: const [
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _currency = value ?? 'EUR';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    _pickedFile == null
                        ? 'Adjuntar PDF'
                        : _pickedFile!.name,
                  ),
                ),
              ],
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
    required this.title,
    this.description,
    this.amount,
    required this.currency,
    required this.fileName,
    required this.fileBytes,
  });

  final int ownerId;
  final int vesselId;
  final String title;
  final String? description;
  final double? amount;
  final String currency;
  final String fileName;
  final List<int> fileBytes;
}
