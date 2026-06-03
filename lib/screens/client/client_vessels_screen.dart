import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vessel.dart';
import '../../services/fleet_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

bool isPlaceholderClientVessel(Vessel vessel) =>
    vessel.registrationNumber.trim().toUpperCase().startsWith('TMP-');

String displayClientVesselRegistration(String? registrationNumber) {
  final normalized = registrationNumber?.trim() ?? '';
  return normalized.isEmpty ? 'Sin matrícula' : normalized;
}

Future<List<Vessel>> loadClientVessels(BuildContext context) async {
  final session = context.read<SessionViewModel>();
  final token = session.token;
  final ownerId = session.user?.ownerId;
  if (token == null || ownerId == null) {
    return const <Vessel>[];
  }
  final vessels = await context.read<FleetService>().getVessels(
    token,
    ownerId: ownerId,
  );
  return vessels.where((vessel) => !isPlaceholderClientVessel(vessel)).toList();
}

Future<Vessel?> ensureClientHasVessel(
  BuildContext context, {
  String? suggestedVesselName,
}) async {
  final session = context.read<SessionViewModel>();
  final fleetService = context.read<FleetService>();
  final token = session.token;
  final ownerId = session.user?.ownerId;
  if (token == null || ownerId == null) {
    AppToast.error(
      context,
      'Tu cuenta aún no está vinculada a un cliente. Contacta con soporte.',
    );
    return null;
  }

  final existing = await loadClientVessels(context);
  if (existing.isNotEmpty) {
    return existing.first;
  }

  if (!context.mounted) {
    return null;
  }

  final draft = await showDialog<_ClientVesselDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreateClientVesselDialog(
      initialName: suggestedVesselName,
      title: 'Añade tu embarcación',
      message:
          'Antes de abrir el presupuesto necesitamos registrar tu embarcación para mantener el seguimiento y asociar correctamente la documentación.',
      actionLabel: 'Guardar embarcación',
    ),
  );
  if (draft == null) {
    return null;
  }

  try {
    final vessel = await fleetService.createVessel(
      token,
      ownerId: ownerId,
      name: draft.name,
      registrationNumber: draft.registrationNumber,
      model: draft.model,
    );
    if (context.mounted) {
      AppToast.success(context, 'Embarcación creada correctamente.');
    }
    return vessel;
  } catch (error) {
    if (context.mounted) {
      AppToast.error(context, 'No se pudo crear la embarcación: $error');
    }
    return null;
  }
}

class ClientVesselsScreen extends StatefulWidget {
  const ClientVesselsScreen({super.key});

  @override
  State<ClientVesselsScreen> createState() => _ClientVesselsScreenState();
}

class _ClientVesselsScreenState extends State<ClientVesselsScreen> {
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;
  List<Vessel> _vessels = const <Vessel>[];

  @override
  void initState() {
    super.initState();
    _loadVessels();
  }

  Future<void> _loadVessels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final vessels = await loadClientVessels(context);
      if (!mounted) {
        return;
      }
      setState(() {
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

  Future<void> _createVessel() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final ownerId = session.user?.ownerId;
    if (token == null || ownerId == null) {
      AppToast.error(
        context,
        'Tu cuenta aún no está vinculada a un cliente. Contacta con soporte.',
      );
      return;
    }

    final draft = await showDialog<_ClientVesselDraft>(
      context: context,
      builder: (_) => const _CreateClientVesselDialog(
        title: 'Nueva embarcación',
        message:
            'Añade la embarcación para que sus presupuestos, partes y documentación queden bien asociados.',
        actionLabel: 'Crear embarcación',
      ),
    );
    if (!mounted || draft == null) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      await context.read<FleetService>().createVessel(
        token,
        ownerId: ownerId,
        name: draft.name,
        registrationNumber: draft.registrationNumber,
        model: draft.model,
      );
      await _loadVessels();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Embarcación creada correctamente.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo crear la embarcación: $error');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadVessels,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu flota',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aquí registras las embarcaciones asociadas a tu cuenta para poder seguir presupuestos, trabajos y documentación.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                NavalgoGradientButton(
                  label: _isCreating ? 'Creando...' : 'Añadir embarcación',
                  icon: _isCreating ? null : Icons.add_circle_outline,
                  onPressed: _isCreating ? null : _createVessel,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              NavalgoPanel(child: Text('No se pudo cargar tu flota: $_error'))
            else if (_vessels.isEmpty)
              NavalgoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aún no tienes embarcaciones registradas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Añade tu primera embarcación para llevar seguimiento de presupuestos, trabajos y documentación.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isCreating ? null : _createVessel,
                      icon: const Icon(Icons.directions_boat_outlined),
                      label: const Text('Crear embarcación'),
                    ),
                  ],
                ),
              )
            else
              ..._vessels.map(
                (vessel) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NavalgoPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vessel.name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: NavalgoColors.deepSea,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: NavalgoColors.tide.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                displayClientVesselRegistration(
                                  vessel.registrationNumber,
                                ),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: NavalgoColors.tide,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (vessel.model != null &&
                            vessel.model!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Modelo: ${vessel.model!}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateClientVesselDialog extends StatefulWidget {
  const _CreateClientVesselDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    this.initialName,
  });

  final String title;
  final String message;
  final String actionLabel;
  final String? initialName;

  @override
  State<_CreateClientVesselDialog> createState() =>
      _CreateClientVesselDialogState();
}

class _CreateClientVesselDialogState extends State<_CreateClientVesselDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final TextEditingController _registrationCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _registrationCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _ClientVesselDraft(
        name: _nameCtrl.text.trim(),
        registrationNumber: _registrationCtrl.text.trim().isEmpty
            ? null
            : _registrationCtrl.text.trim(),
        model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la embarcación',
                  hintText: 'Ej. Alborán',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Indica el nombre de la embarcación';
                  }
                  if (value.trim().length > 255) {
                    return 'Máximo 255 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _registrationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Matrícula',
                  hintText: 'Opcional',
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').length > 255) {
                    return 'Máximo 255 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  hintText: 'Opcional',
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').length > 255) {
                    return 'Máximo 255 caracteres';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _ClientVesselDraft {
  const _ClientVesselDraft({
    required this.name,
    this.registrationNumber,
    this.model,
  });

  final String name;
  final String? registrationNumber;
  final String? model;
}
