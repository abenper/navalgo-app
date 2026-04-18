import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/owner.dart';
import '../../models/vessel.dart';
import '../../services/fleet_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/fleet_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

IconData _engineOptionIcon(String position) {
  switch (position) {
    case 'Motor central':
      return Icons.adjust_outlined;
    case 'Babor':
      return Icons.keyboard_double_arrow_left_rounded;
    case 'Estribor':
      return Icons.keyboard_double_arrow_right_rounded;
    case 'Auxiliar':
      return Icons.extension_outlined;
    case 'Fuera borda':
    default:
      return Icons.power_outlined;
  }
}

class FlotaScreen extends StatefulWidget {
  const FlotaScreen({super.key});

  @override
  State<FlotaScreen> createState() => _FlotaScreenState();
}

class _FlotaScreenState extends State<FlotaScreen> {
  static const List<String> _enginePositionOptions = <String>[
    'Fuera borda',
    'Motor central',
    'Babor',
    'Estribor',
    'Auxiliar',
  ];

  final TextEditingController _ownerSearchCtrl = TextEditingController();
  final TextEditingController _vesselSearchCtrl = TextEditingController();
  int? _selectedOwnerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetViewModel>().loadFleet();
    });
  }

  @override
  void dispose() {
    _ownerSearchCtrl.dispose();
    _vesselSearchCtrl.dispose();
    super.dispose();
  }

  void _toggleOwnerSelection(Owner owner) {
    setState(() {
      _selectedOwnerId = _selectedOwnerId == owner.id ? null : owner.id;
    });
  }

  Future<void> _showVesselDetails(Vessel vessel) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _VesselDetailsDialog(vessel: vessel),
    );
  }

  IconData _ownerIcon(Owner owner) {
    return owner.type == 'COMPANY' ? Icons.business : Icons.person;
  }

  Color _ownerAccent(Owner owner) {
    return owner.type == 'COMPANY' ? NavalgoColors.tide : NavalgoColors.kelp;
  }

  Future<void> _createOwner() async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final fleetService = context.read<FleetService>();
    final fleetViewModel = context.read<FleetViewModel>();

    final input = await showDialog<_OwnerInput>(
      context: context,
      builder: (_) => const _OwnerDialog(),
    );
    if (!mounted || input == null) {
      return;
    }

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      await fleetService.createOwner(
        token,
        type: input.type,
        displayName: input.displayName,
        documentId: input.documentId,
        phone: input.phone,
        email: input.email,
      );
      await fleetViewModel.loadFleet();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo crear el propietario: $e')),
      );
    }
  }

  Future<void> _editOwner(Owner owner) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final fleetService = context.read<FleetService>();
    final fleetViewModel = context.read<FleetViewModel>();

    final input = await showDialog<_OwnerInput>(
      context: context,
      builder: (_) => _OwnerDialog(initialOwner: owner),
    );
    if (!mounted || input == null) {
      return;
    }

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      await fleetService.updateOwner(
        token,
        ownerId: owner.id,
        type: input.type,
        displayName: input.displayName,
        documentId: input.documentId,
        phone: input.phone,
        email: input.email,
      );
      await fleetViewModel.loadFleet();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Propietario actualizado')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo editar el propietario: $e')),
      );
    }
  }

  Future<void> _deleteOwner(Owner owner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar propietario'),
        content: Text('Se eliminara a ${owner.displayName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final fleetService = context.read<FleetService>();
    final fleetViewModel = context.read<FleetViewModel>();

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      await fleetService.deleteOwner(token, ownerId: owner.id);
      await fleetViewModel.loadFleet();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Propietario eliminado')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el propietario: $e')),
      );
    }
  }

  Future<void> _createVessel(List<Owner> owners) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final fleetService = context.read<FleetService>();
    final fleetViewModel = context.read<FleetViewModel>();

    if (owners.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Primero crea un propietario')),
      );
      return;
    }

    final input = await showDialog<_VesselInput>(
      context: context,
      builder: (_) => _VesselDialog(owners: owners),
    );
    if (!mounted || input == null) {
      return;
    }

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      await fleetService.createVessel(
        token,
        name: input.name,
        registrationNumber: input.registrationNumber,
        model: input.model,
        engineCount: input.engineCount,
        engineLabels: input.engineLabels,
        lengthMeters: input.lengthMeters,
        ownerId: input.ownerId,
      );
      await fleetViewModel.loadFleet();
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo crear la embarcación: $e')),
      );
    }
  }

  Future<void> _editVessel(Vessel vessel, List<Owner> owners) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final fleetService = context.read<FleetService>();
    final fleetViewModel = context.read<FleetViewModel>();

    final input = await showDialog<_VesselInput>(
      context: context,
      builder: (_) => _VesselDialog(owners: owners, initialVessel: vessel),
    );
    if (!mounted || input == null) {
      return;
    }

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      await fleetService.updateVessel(
        token,
        vesselId: vessel.id,
        name: input.name,
        registrationNumber: input.registrationNumber,
        model: input.model,
        engineCount: input.engineCount,
        engineLabels: input.engineLabels,
        lengthMeters: input.lengthMeters,
        ownerId: input.ownerId,
      );
      await fleetViewModel.loadFleet();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Embarcación actualizada')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo editar la embarcación: $e')),
      );
    }
  }

  Future<void> _deleteVessel(Vessel vessel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar embarcación'),
        content: Text(
          'Se eliminará ${vessel.name} (${vessel.registrationNumber}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionViewModel>();
    final fleetService = context.read<FleetService>();
    final fleetViewModel = context.read<FleetViewModel>();

    final token = session.token;
    if (token == null) {
      return;
    }

    try {
      await fleetService.deleteVessel(token, vesselId: vessel.id);
      await fleetViewModel.loadFleet();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Embarcación eliminada')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la embarcación: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FleetViewModel>();
    final vesselCountByOwner = <int, int>{};
    for (final vessel in vm.vessels) {
      vesselCountByOwner[vessel.ownerId] =
          (vesselCountByOwner[vessel.ownerId] ?? 0) + 1;
    }
    final selectedOwner = vm.owners.cast<Owner?>().firstWhere(
      (owner) => owner?.id == _selectedOwnerId,
      orElse: () => null,
    );

    return Scaffold(
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
          ? Center(child: Text(vm.error!))
          : RefreshIndicator(
              onRefresh: () => vm.loadFleet(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const NavalgoPageIntro(
                    eyebrow: 'CLIENTES Y EMBARCACIONES',
                    title:
                        'Consulta propietarios, embarcaciones y motores desde una misma vista.',
                    subtitle:
                        'Mantén actualizada la información de clientes y flota para la planificación y el seguimiento técnico.',
                  ),
                  const SizedBox(height: 18),
                  const NavalgoSectionHeader(
                    title: 'Propietarios',
                    subtitle:
                        'Consulta, filtra y actualiza clientes particulares y empresas.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ownerSearchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Filtrar por propietario',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _ownerSearchCtrl,
                    builder: (context, value, _) {
                      final ownerQuery = value.text.trim().toLowerCase();
                      final filteredOwners = vm.owners.where((owner) {
                        if (ownerQuery.isEmpty) {
                          return true;
                        }
                        return owner.displayName.toLowerCase().contains(
                              ownerQuery,
                            ) ||
                            owner.documentId.toLowerCase().contains(ownerQuery);
                      }).toList();

                      if (filteredOwners.isEmpty) {
                        return const NavalgoPanel(
                          child: Text('No se encontraron propietarios.'),
                        );
                      }

                      return Column(
                        children: filteredOwners.map((owner) {
                          final esEmpresa = owner.type == 'COMPANY';
                          final vesselCount = vesselCountByOwner[owner.id] ?? 0;
                          final isSelected = selectedOwner?.id == owner.id;
                          final accent = _ownerAccent(owner);
                          final ownerVessels = vm.vessels
                              .where((vessel) => vessel.ownerId == owner.id)
                              .toList();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isSelected
                                ? accent.withValues(alpha: 0.08)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                              side: BorderSide(
                                color: isSelected
                                    ? accent.withValues(alpha: 0.36)
                                    : NavalgoColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  onTap: () => _toggleOwnerSelection(owner),
                                  leading: CircleAvatar(
                                    backgroundColor: esEmpresa
                                        ? NavalgoColors.mist
                                        : NavalgoColors.foam,
                                    child: Icon(
                                      _ownerIcon(owner),
                                      color: accent,
                                    ),
                                  ),
                                  title: Text(
                                    owner.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${esEmpresa ? 'Empresa' : 'Particular'} • ${owner.documentId} • $vesselCount embarcación(es)',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (vesselCount > 0)
                                        Icon(
                                          isSelected
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          color: accent,
                                        ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editOwner(owner);
                                          }
                                          if (value == 'delete') {
                                            _deleteOwner(owner);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Editar'),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Embarcaciones asociadas',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: NavalgoColors.deepSea,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          ownerVessels.isEmpty
                                              ? 'Este cliente todavía no tiene embarcaciones registradas.'
                                              : 'Pulsa una embarcación para ver su ficha técnica.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: NavalgoColors.storm,
                                              ),
                                        ),
                                        if (ownerVessels.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          ...ownerVessels.map(
                                            (vessel) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  onTap: () =>
                                                      _showVesselDetails(
                                                        vessel,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),
                                                      border: Border.all(
                                                        color: NavalgoColors
                                                            .border,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration: BoxDecoration(
                                                            color: NavalgoColors
                                                                .foam,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .directions_boat_outlined,
                                                            color: NavalgoColors
                                                                .sand,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                vessel.name,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                '${vessel.registrationNumber} • ${vessel.model ?? 'Modelo no indicado'}',
                                                                style: Theme.of(
                                                                  context,
                                                                ).textTheme.bodyMedium,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const Icon(
                                                          Icons.chevron_right,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const NavalgoSectionHeader(
                    title: 'Embarcaciones',
                    subtitle:
                        'Filtra unidades, propietarios y configuración de motores.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _vesselSearchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Filtrar por embarcación o propietario',
                    ),
                  ),
                  if (selectedOwner != null) ...[
                    const SizedBox(height: 10),
                    NavalgoPanel(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _ownerAccent(
                              selectedOwner,
                            ).withValues(alpha: 0.12),
                            child: Icon(
                              _ownerIcon(selectedOwner),
                              color: _ownerAccent(selectedOwner),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mostrando la flota de ${selectedOwner.displayName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pulsa "Ver todas" para quitar el filtro por cliente.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedOwnerId = null;
                              });
                            },
                            child: const Text('Ver todas'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _vesselSearchCtrl,
                    builder: (context, value, _) {
                      final vesselQuery = value.text.trim().toLowerCase();
                      final filteredVessels = vm.vessels.where((vessel) {
                        if (selectedOwner != null &&
                            vessel.ownerId != selectedOwner.id) {
                          return false;
                        }
                        if (vesselQuery.isEmpty) {
                          return true;
                        }
                        return vessel.name.toLowerCase().contains(
                              vesselQuery,
                            ) ||
                            vessel.ownerName.toLowerCase().contains(
                              vesselQuery,
                            ) ||
                            vessel.registrationNumber.toLowerCase().contains(
                              vesselQuery,
                            );
                      }).toList();

                      if (filteredVessels.isEmpty) {
                        return const NavalgoPanel(
                          child: Text('No se encontraron embarcaciones.'),
                        );
                      }

                      return Column(
                        children: filteredVessels
                            .map(
                              (vessel) => Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  onTap: () => _showVesselDetails(vessel),
                                  leading: CircleAvatar(
                                    backgroundColor: NavalgoColors.foam,
                                    child: const Icon(
                                      Icons.directions_boat,
                                      color: NavalgoColors.sand,
                                    ),
                                  ),
                                  title: Text(
                                    vessel.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${vessel.registrationNumber} • ${vessel.ownerName}\n'
                                    'Modelo: ${vessel.model ?? 'N/D'} • Motores: ${vessel.engineCount ?? 0}\n'
                                    '${vessel.engineLabels.isEmpty ? 'Sin posiciones definidas' : vessel.engineLabels.join(', ')}',
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editVessel(vessel, vm.owners);
                                      }
                                      if (value == 'delete') {
                                        _deleteVessel(vessel);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: NavalgoPanel(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createOwner,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nuevo Propietario'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _createVessel(vm.owners),
                    icon: const Icon(Icons.directions_boat),
                    label: const Text('Nueva embarcación'),
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

class _OwnerInput {
  const _OwnerInput({
    required this.type,
    required this.displayName,
    required this.documentId,
    this.phone,
    this.email,
  });

  final String type;
  final String displayName;
  final String documentId;
  final String? phone;
  final String? email;
}

class _OwnerDialog extends StatefulWidget {
  const _OwnerDialog({this.initialOwner});

  final Owner? initialOwner;

  @override
  State<_OwnerDialog> createState() => _OwnerDialogState();
}

class _OwnerDialogState extends State<_OwnerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _docCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late String _type;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOwner;
    _nameCtrl = TextEditingController(text: initial?.displayName ?? '');
    _docCtrl = TextEditingController(text: initial?.documentId ?? '');
    _phoneCtrl = TextEditingController(text: initial?.phone ?? '');
    _emailCtrl = TextEditingController(text: initial?.email ?? '');
    _type = initial?.type ?? 'PERSON';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _docCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialOwner != null;

    return NavalgoFormDialog(
      eyebrow: 'FLOTA',
      title: isEditing ? 'Editar propietario' : 'Nuevo propietario',
      subtitle:
          'Registra los datos fiscales y de contacto con el mismo formato visual del resto de formularios principales.',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: isEditing ? 'Guardar cambios' : 'Guardar',
          icon: Icons.save_outlined,
          onPressed: () {
            final form = _formKey.currentState;
            if (form == null || !form.validate()) {
              return;
            }

            Navigator.pop(
              context,
              _OwnerInput(
                type: _type,
                displayName: _nameCtrl.text.trim(),
                documentId: _docCtrl.text.trim(),
                phone: _phoneCtrl.text.trim().isEmpty
                    ? null
                    : _phoneCtrl.text.trim(),
                email: _emailCtrl.text.trim().isEmpty
                    ? null
                    : _emailCtrl.text.trim(),
              ),
            );
          },
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavalgoFormFieldBlock(
              label: 'Tipo de propietario',
              child: DropdownButtonFormField<String>(
                initialValue: _type,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Tipo de propietario',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'PERSON', child: Text('Particular')),
                  DropdownMenuItem(value: 'COMPANY', child: Text('Empresa')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'PERSON'),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Nombre',
              child: TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nombre',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Indica el nombre del propietario.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Documento (DNI/NIF)',
              child: TextFormField(
                controller: _docCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Documento (DNI/NIF)',
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Teléfono',
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Teléfono',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Correo electrónico',
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.alternate_email_outlined),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return null;
                  }
                  if (!trimmed.contains('@') || !trimmed.contains('.')) {
                    return 'Introduce un correo válido.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VesselInput {
  const _VesselInput({
    required this.name,
    required this.registrationNumber,
    this.model,
    this.engineCount,
    required this.engineLabels,
    this.lengthMeters,
    required this.ownerId,
  });

  final String name;
  final String registrationNumber;
  final String? model;
  final int? engineCount;
  final List<String> engineLabels;
  final double? lengthMeters;
  final int ownerId;
}

class _VesselDialog extends StatefulWidget {
  const _VesselDialog({required this.owners, this.initialVessel});

  final List<Owner> owners;
  final Vessel? initialVessel;

  @override
  State<_VesselDialog> createState() => _VesselDialogState();
}

class _VesselDialogState extends State<_VesselDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _regCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _engineCtrl;
  late final TextEditingController _lengthCtrl;
  late int _ownerId;
  List<String> _enginePositions = <String>[];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialVessel;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _regCtrl = TextEditingController(text: initial?.registrationNumber ?? '');
    _modelCtrl = TextEditingController(text: initial?.model ?? '');
    _engineCtrl = TextEditingController(
      text: (initial?.engineCount ?? 1).toString(),
    );
    _lengthCtrl = TextEditingController(
      text: initial?.lengthMeters?.toString() ?? '',
    );
    _ownerId = initial?.ownerId ?? widget.owners.first.id;

    final count = int.tryParse(_engineCtrl.text) ?? 1;
    _syncEnginePositions(count);
    if (initial != null && initial.engineLabels.isNotEmpty) {
      _enginePositions = _extractBasePositions(initial.engineLabels, count);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regCtrl.dispose();
    _modelCtrl.dispose();
    _engineCtrl.dispose();
    _lengthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialVessel != null;

    return NavalgoFormDialog(
      eyebrow: 'FLOTA',
      title: isEditing ? 'Editar embarcación' : 'Nueva embarcación',
      subtitle:
          'Define la ficha técnica y asigna el propietario con la misma estética del formulario de perfil.',
      maxWidth: 680,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: isEditing ? 'Guardar cambios' : 'Guardar',
          icon: Icons.save_outlined,
          onPressed: () {
            final form = _formKey.currentState;
            if (form == null || !form.validate()) {
              return;
            }

            Navigator.pop(
              context,
              _VesselInput(
                name: _nameCtrl.text.trim(),
                registrationNumber: _regCtrl.text.trim(),
                model: _modelCtrl.text.trim().isEmpty
                    ? null
                    : _modelCtrl.text.trim(),
                engineCount: int.tryParse(_engineCtrl.text.trim()),
                engineLabels: _buildEngineLabels(_enginePositions),
                lengthMeters: double.tryParse(_lengthCtrl.text.trim()),
                ownerId: _ownerId,
              ),
            );
          },
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavalgoFormFieldBlock(
              label: 'Nombre',
              child: TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nombre',
                  prefixIcon: const Icon(Icons.sailing_outlined),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Indica el nombre de la embarcación.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Matrícula',
              child: TextFormField(
                controller: _regCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Matrícula',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Modelo',
              child: TextFormField(
                controller: _modelCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Modelo',
                  prefixIcon: const Icon(Icons.sailing_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Número de motores',
              child: TextFormField(
                controller: _engineCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Número de motores',
                  prefixIcon: const Icon(Icons.speed_outlined),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Indica cuántos motores tiene.';
                  }
                  final count = int.tryParse(trimmed);
                  if (count == null || count < 0) {
                    return 'Introduce un número válido.';
                  }
                  return null;
                },
                onChanged: (value) =>
                    _syncEnginePositions(int.tryParse(value) ?? 0),
              ),
            ),
            if (_enginePositions.isNotEmpty) ...[
              const SizedBox(height: 14),
              NavalgoFormFieldBlock(
                label: 'Tipo de motor',
                caption:
                    'Selecciona la posición o tipología de cada motor. Incluye ahora la opción Motor central.',
                child: Column(
                  children: List<Widget>.generate(_enginePositions.length, (
                    index,
                  ) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _enginePositions.length - 1 ? 0 : 12,
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _enginePositions[index],
                        dropdownColor: NavalgoColors.shell,
                        decoration: NavalgoFormStyles.inputDecoration(
                          context,
                          label: 'Motor ${index + 1}',
                          prefixIcon: Icon(
                            _engineOptionIcon(_enginePositions[index]),
                          ),
                        ),
                        items: _FlotaScreenState._enginePositionOptions
                            .map(
                              (position) => DropdownMenuItem(
                                value: position,
                                child: Row(
                                  children: [
                                    Icon(
                                      _engineOptionIcon(position),
                                      size: 18,
                                      color: NavalgoColors.tide,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(position),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _enginePositions[index] = value ?? 'Fuera borda';
                          });
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Eslora (m)',
              child: TextFormField(
                controller: _lengthCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Eslora (m)',
                  prefixIcon: const Icon(Icons.straighten_outlined),
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
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
                items: widget.owners
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.id,
                        child: Row(
                          children: [
                            Icon(
                              o.type == 'COMPANY'
                                  ? Icons.business
                                  : Icons.person,
                              size: 18,
                              color: o.type == 'COMPANY'
                                  ? NavalgoColors.tide
                                  : NavalgoColors.kelp,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(o.displayName)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _ownerId = v ?? _ownerId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncEnginePositions(int count) {
    final safeCount = count < 0 ? 0 : count;
    setState(() {
      if (safeCount == 0) {
        _enginePositions = <String>[];
        return;
      }

      if (_enginePositions.length < safeCount) {
        _enginePositions = <String>[
          ..._enginePositions,
          ...List<String>.filled(
            safeCount - _enginePositions.length,
            'Fuera borda',
          ),
        ];
      } else {
        _enginePositions = _enginePositions.take(safeCount).toList();
      }
    });
  }

  List<String> _buildEngineLabels(List<String> positions) {
    final counts = <String, int>{};
    final totals = <String, int>{};

    for (final position in positions) {
      totals[position] = (totals[position] ?? 0) + 1;
    }

    return positions.map((position) {
      counts[position] = (counts[position] ?? 0) + 1;
      if ((totals[position] ?? 0) == 1) {
        return position;
      }
      return '$position ${counts[position]}';
    }).toList();
  }

  List<String> _extractBasePositions(List<String> labels, int count) {
    final list = labels
        .map((item) => item.replaceAll(RegExp(r'\s+\d+$'), '').trim())
        .toList();

    if (list.length >= count) {
      return list.take(count).toList();
    }

    return <String>[
      ...list,
      ...List<String>.filled(count - list.length, 'Fuera borda'),
    ];
  }
}

class _VesselDetailsDialog extends StatefulWidget {
  const _VesselDetailsDialog({required this.vessel});

  final Vessel vessel;

  @override
  State<_VesselDetailsDialog> createState() => _VesselDetailsDialogState();
}

class _VesselDetailsDialogState extends State<_VesselDetailsDialog> {
  List<EngineHourSummary>? _engineHours;
  bool _loadingHours = false;

  @override
  void initState() {
    super.initState();
    _loadEngineHours();
  }

  Future<void> _loadEngineHours() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) return;
    setState(() => _loadingHours = true);
    try {
      final hours = await context.read<FleetService>().getVesselLastEngineHours(
            token,
            vesselId: widget.vessel.id,
          );
      if (mounted) setState(() => _engineHours = hours);
    } catch (_) {
      if (mounted) setState(() => _engineHours = const []);
    } finally {
      if (mounted) setState(() => _loadingHours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vessel = widget.vessel;
    final engineSummary = vessel.engineLabels.isEmpty
        ? 'Sin posiciones definidas'
        : vessel.engineLabels.join(', ');

    return NavalgoFormDialog(
      eyebrow: 'EMBARCACIÓN',
      title: vessel.name,
      subtitle:
          'Consulta la ficha técnica completa y los datos del cliente asociado.',
      actions: [
        NavalgoGhostButton(
          label: 'Cerrar',
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoFormFieldBlock(
            label: 'Propietario',
            child: _VesselDetailValue(
              icon: Icons.person_outline,
              value: vessel.ownerName,
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Matrícula',
            child: _VesselDetailValue(
              icon: Icons.badge_outlined,
              value: vessel.registrationNumber,
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Modelo',
            child: _VesselDetailValue(
              icon: Icons.sailing_outlined,
              value: vessel.model ?? 'No indicado',
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Eslora',
            child: _VesselDetailValue(
              icon: Icons.straighten_outlined,
              value: vessel.lengthMeters == null
                  ? 'No indicada'
                  : '${vessel.lengthMeters!.toStringAsFixed(1)} m',
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Motores',
            child: _VesselDetailValue(
              icon: Icons.speed_outlined,
              value: '${vessel.engineCount ?? 0} configurado(s)',
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Posiciones / tipología',
            child: _VesselDetailValue(
              icon: Icons.tune_outlined,
              value: engineSummary,
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Últimas horas registradas',
            child: _loadingHours
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : (_engineHours == null || _engineHours!.isEmpty)
                    ? _VesselDetailValue(
                        icon: Icons.hourglass_empty_outlined,
                        value: 'Sin horas registradas',
                      )
                    : Column(
                        children: _engineHours!
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _VesselDetailValue(
                                  icon: Icons.speed_outlined,
                                  value:
                                      '${e.engineLabel}: ${e.hours} h',
                                ),
                              ),
                            )
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

class _VesselDetailValue extends StatelessWidget {
  const _VesselDetailValue({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NavalgoColors.tide),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NavalgoColors.deepSea,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
