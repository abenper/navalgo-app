import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/owner.dart';
import '../../models/vessel.dart';
import '../../services/fleet_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/fleet_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class FlotaScreen extends StatefulWidget {
  const FlotaScreen({super.key});

  @override
  State<FlotaScreen> createState() => _FlotaScreenState();
}

class _FlotaScreenState extends State<FlotaScreen> {
  static const List<String> _enginePositionOptions = <String>[
    'Fuera borda',
    'Babor',
    'Estribor',
    'Auxiliar',
  ];

  final TextEditingController _ownerSearchCtrl = TextEditingController();
  final TextEditingController _vesselSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetViewModel>().loadFleet();
    });
    _ownerSearchCtrl.addListener(() => setState(() {}));
    _vesselSearchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ownerSearchCtrl.dispose();
    _vesselSearchCtrl.dispose();
    super.dispose();
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
    final ownerQuery = _ownerSearchCtrl.text.trim().toLowerCase();
    final vesselQuery = _vesselSearchCtrl.text.trim().toLowerCase();

    final filteredOwners = vm.owners.where((owner) {
      if (ownerQuery.isEmpty) {
        return true;
      }
      return owner.displayName.toLowerCase().contains(ownerQuery) ||
          owner.documentId.toLowerCase().contains(ownerQuery);
    }).toList();

    final filteredVessels = vm.vessels.where((vessel) {
      if (vesselQuery.isEmpty) {
        return true;
      }
      return vessel.name.toLowerCase().contains(vesselQuery) ||
          vessel.ownerName.toLowerCase().contains(vesselQuery) ||
          vessel.registrationNumber.toLowerCase().contains(vesselQuery);
    }).toList();

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
                  ...filteredOwners.map((owner) {
                    final esEmpresa = owner.type == 'COMPANY';
                    final vesselCount = vm.vessels
                        .where((v) => v.ownerId == owner.id)
                        .length;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esEmpresa
                              ? NavalgoColors.mist
                              : NavalgoColors.foam,
                          child: Icon(
                            esEmpresa ? Icons.business : Icons.person,
                            color: esEmpresa
                                ? NavalgoColors.tide
                                : NavalgoColors.kelp,
                          ),
                        ),
                        title: Text(
                          owner.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${esEmpresa ? 'Empresa' : 'Particular'} • ${owner.documentId} • $vesselCount embarcación(es)',
                        ),
                        trailing: PopupMenuButton<String>(
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
                      ),
                    );
                  }),
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
                  const SizedBox(height: 10),
                  ...filteredVessels.map(
                    (vessel) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: NavalgoColors.foam,
                          child: const Icon(
                            Icons.directions_boat,
                            color: NavalgoColors.sand,
                          ),
                        ),
                        title: Text(
                          vessel.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

    return AlertDialog(
      title: Text(isEditing ? 'Editar Propietario' : 'Nuevo Propietario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'PERSON', child: Text('Particular')),
                DropdownMenuItem(value: 'COMPANY', child: Text('Empresa')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'PERSON'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _docCtrl,
              decoration: const InputDecoration(
                labelText: 'Documento (DNI/NIF)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _OwnerInput(
                type: _type,
                displayName: _nameCtrl.text.trim(),
                documentId: _docCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
              ),
            );
          },
          child: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
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

    return AlertDialog(
      title: Text(isEditing ? 'Editar embarcación' : 'Nueva embarcación'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _regCtrl,
              decoration: const InputDecoration(
                labelText: 'Matrícula',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _engineCtrl,
              decoration: const InputDecoration(
                labelText: 'Número de motores',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) =>
                  _syncEnginePositions(int.tryParse(value) ?? 0),
            ),
            if (_enginePositions.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Posición de cada motor',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ...List<Widget>.generate(_enginePositions.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    initialValue: _enginePositions[index],
                    decoration: InputDecoration(
                      labelText: 'Motor ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    items: _FlotaScreenState._enginePositionOptions
                        .map(
                          (position) => DropdownMenuItem(
                            value: position,
                            child: Text(position),
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
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _lengthCtrl,
              decoration: const InputDecoration(
                labelText: 'Eslora (m)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
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
                  .map(
                    (o) => DropdownMenuItem(
                      value: o.id,
                      child: Text(o.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _ownerId = v ?? _ownerId),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _VesselInput(
                name: _nameCtrl.text.trim(),
                registrationNumber: _regCtrl.text.trim(),
                model: _modelCtrl.text.trim(),
                engineCount: int.tryParse(_engineCtrl.text.trim()),
                engineLabels: _buildEngineLabels(_enginePositions),
                lengthMeters: double.tryParse(_lengthCtrl.text.trim()),
                ownerId: _ownerId,
              ),
            );
          },
          child: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
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
