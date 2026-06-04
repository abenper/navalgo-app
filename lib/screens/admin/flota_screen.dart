import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/owner.dart';
import '../../models/vessel.dart';
import '../../services/fleet_service.dart';
import '../../services/work_order_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/fleet_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';
import 'partes_screen.dart';

IconData _engineOptionIcon(String position) {
  switch (position) {
    case 'Motor central':
      return Icons.adjust;
    case 'Babor':
      return Icons.keyboard_double_arrow_left_rounded;
    case 'Estribor':
      return Icons.keyboard_double_arrow_right_rounded;
    case 'Auxiliar':
      return Icons.handyman_outlined;
    case 'Fuera borda':
    default:
      return Icons.shortcut;
  }
}

String _displayRegistrationNumber(String? registrationNumber) {
  final normalized = registrationNumber?.trim() ?? '';
  return normalized.isEmpty ? 'Sin matrícula' : normalized;
}

String? _validateRequiredText(String? value, String message) {
  if ((value?.trim() ?? '').isEmpty) {
    return message;
  }
  return _validateOptionalText(value, 255);
}

String? _validateOptionalText(String? value, int maxLength) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length > maxLength) {
    return 'Máximo $maxLength caracteres.';
  }
  return null;
}

String? _validateOptionalDecimal(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
  if (parsed == null || parsed < 0) {
    return 'Introduce un número válido.';
  }
  return null;
}

double? _parseOptionalDecimal(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

String _marineComponentIconAsset(String type) {
  switch (type) {
    case 'ENGINE':
      return 'assets/icons/marine/motor.png';
    case 'GENERATOR':
      return 'assets/icons/marine/generador.png';
    case 'GEARBOX':
      return 'assets/icons/marine/reductora.png';
    case 'JET':
      return 'assets/icons/marine/jet.png';
    default:
      return 'assets/icons/marine/motor.png';
  }
}

String _fleetComponentTypeLabel(String type) {
  switch (type) {
    case 'ENGINE':
      return 'Motor';
    case 'GENERATOR':
      return 'Generador';
    case 'GEARBOX':
      return 'Reductora';
    case 'JET':
      return 'Jet';
    default:
      return 'Otro';
  }
}

IconData _marineComponentFallbackIcon(String type) {
  switch (type) {
    case 'ENGINE':
      return Icons.speed_outlined;
    case 'GENERATOR':
      return Icons.electrical_services_outlined;
    case 'GEARBOX':
      return Icons.settings_outlined;
    case 'JET':
      return Icons.settings_input_component_outlined;
    default:
      return Icons.build_outlined;
  }
}

class _MarineComponentIcon extends StatelessWidget {
  const _MarineComponentIcon({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: Image.asset(
        _marineComponentIconAsset(type),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            _marineComponentFallbackIcon(type),
            size: 28,
            color: NavalgoColors.tide,
          );
        },
      ),
    );
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VesselAnalyticsDialog(vessel: vessel),
      ),
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
      builder: (_) => _OwnerDialog(existingOwners: fleetViewModel.owners),
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
      builder: (_) => _OwnerDialog(
        initialOwner: owner,
        existingOwners: fleetViewModel.owners,
      ),
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
      builder: (_) => NavalgoConfirmDialog(
        title: 'Eliminar propietario',
        message: 'Se eliminará a ${owner.displayName}.',
        confirmLabel: 'Eliminar',
        destructive: true,
        icon: Icons.person_off_outlined,
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
        engineSerialNumbers: input.engineSerialNumbers,
        hasJets: input.hasJets,
        jetSerialNumbers: input.jetSerialNumbers,
        hasGearboxes: input.hasGearboxes,
        gearboxSerialNumbers: input.gearboxSerialNumbers,
        components: input.components,
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
        engineSerialNumbers: input.engineSerialNumbers,
        hasJets: input.hasJets,
        jetSerialNumbers: input.jetSerialNumbers,
        hasGearboxes: input.hasGearboxes,
        gearboxSerialNumbers: input.gearboxSerialNumbers,
        components: input.components,
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
      builder: (_) => NavalgoConfirmDialog(
        title: 'Eliminar embarcación',
        message:
            'Se eliminará ${vessel.name} (${_displayRegistrationNumber(vessel.registrationNumber)}).',
        confirmLabel: 'Eliminar',
        destructive: true,
        icon: Icons.directions_boat_filled_outlined,
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
    final sessionUser = context.watch<SessionViewModel>().user;
    final canCreateFleet =
        sessionUser?.role == 'ADMIN' ||
        sessionUser?.role == 'COMERCIAL' ||
        sessionUser?.canEditWorkOrders == true;
    final canModifyFleet =
        sessionUser?.role == 'ADMIN' || sessionUser?.role == 'COMERCIAL';
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
      backgroundColor: Colors.transparent,
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
          ? Center(child: Text(vm.error!))
          : RefreshIndicator(
              onRefresh: () => vm.loadFleet(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 920;
                      final actions = canCreateFleet
                          ? Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: compact
                                  ? WrapAlignment.start
                                  : WrapAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _createOwner,
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Nuevo propietario'),
                                ),
                                NavalgoGradientButton(
                                  label: 'Nueva embarcación',
                                  icon: Icons.directions_boat,
                                  onPressed: () => _createVessel(vm.owners),
                                ),
                              ],
                            )
                          : const SizedBox.shrink();

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Propietarios',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            actions,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Propietarios',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(width: 16),
                          actions,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  NavalgoSearchField(
                    controller: _ownerSearchCtrl,
                    label: 'Filtrar por propietario',
                    hint: 'Nombre o documento del cliente',
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
                                      if (canModifyFleet)
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
                                                                '${_displayRegistrationNumber(vessel.registrationNumber)} • ${vessel.model ?? 'Modelo no indicado'}',
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
                  const NavalgoSectionHeader(title: 'Embarcaciones'),
                  const SizedBox(height: 10),
                  NavalgoSearchField(
                    controller: _vesselSearchCtrl,
                    label: 'Filtrar por embarcación o propietario',
                    hint: 'Nombre, matrícula o propietario',
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
                                    '${_displayRegistrationNumber(vessel.registrationNumber)} • ${vessel.ownerName}\n'
                                    'Modelo: ${vessel.model ?? 'N/D'} • Motores: ${vessel.engineCount ?? 0}\n'
                                    '${vessel.engineLabels.isEmpty ? 'Sin posiciones definidas' : vessel.engineLabels.join(', ')}',
                                  ),
                                  isThreeLine: true,
                                  trailing: canModifyFleet
                                      ? PopupMenuButton<String>(
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
                                        )
                                      : null,
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
  const _OwnerDialog({
    this.initialOwner,
    this.existingOwners = const <Owner>[],
  });

  final Owner? initialOwner;
  final List<Owner> existingOwners;

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
          'Gestiona la ficha del cliente con la misma lectura clara que usamos en Partes.',
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
                  return _validateRequiredText(
                    value,
                    'Indica el nombre del propietario.',
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: _type == 'COMPANY'
                  ? 'Documento (CIF/NIF)'
                  : 'Documento (DNI/NIF)',
              child: TextFormField(
                controller: _docCtrl,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: _type == 'COMPANY'
                      ? 'Documento (CIF/NIF)'
                      : 'Documento (DNI/NIF)',
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return _type == 'COMPANY'
                        ? 'Indica el CIF o NIF de la empresa.'
                        : 'Indica el DNI o NIF del cliente.';
                  }
                  return _validateOptionalText(value, 255);
                },
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
                validator: (value) => _validateOptionalText(value, 255),
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
                  if (trimmed.isEmpty && _type == 'PERSON') {
                    return 'Indica el correo del cliente.';
                  }
                  if (trimmed.isEmpty) {
                    return null;
                  }
                  final lengthError = _validateOptionalText(value, 255);
                  if (lengthError != null) {
                    return lengthError;
                  }
                  if (!RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(trimmed)) {
                    return 'Introduce un correo válido.';
                  }
                  final normalized = trimmed.toLowerCase();
                  final duplicate = widget.existingOwners.any((owner) {
                    if (owner.id == widget.initialOwner?.id) {
                      return false;
                    }
                    return (owner.email ?? '').trim().toLowerCase() ==
                        normalized;
                  });
                  if (duplicate) {
                    return 'Ya existe un cliente con ese correo.';
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
    required this.engineSerialNumbers,
    required this.hasJets,
    required this.jetSerialNumbers,
    required this.hasGearboxes,
    required this.gearboxSerialNumbers,
    required this.components,
    this.lengthMeters,
    required this.ownerId,
  });

  final String name;
  final String? registrationNumber;
  final String? model;
  final int? engineCount;
  final List<String> engineLabels;
  final List<String> engineSerialNumbers;
  final bool hasJets;
  final List<String> jetSerialNumbers;
  final bool hasGearboxes;
  final List<String> gearboxSerialNumbers;
  final List<Map<String, dynamic>> components;
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
  final List<TextEditingController> _engineSerialCtrls =
      <TextEditingController>[];
  List<int?> _engineComponentIds = <int?>[];
  bool _hasJets = false;
  bool _hasGearboxes = false;
  bool _hasGenerators = false;
  List<String> _associatedComponentLabels = <String>[];
  final List<TextEditingController> _jetSerialCtrls = <TextEditingController>[];
  final List<TextEditingController> _gearboxSerialCtrls =
      <TextEditingController>[];
  List<int?> _jetComponentIds = <int?>[];
  List<int?> _gearboxComponentIds = <int?>[];
  late final TextEditingController _generatorCountCtrl;
  final List<TextEditingController> _generatorSerialCtrls =
      <TextEditingController>[];
  List<int?> _generatorComponentIds = <int?>[];
  List<MarineComponent> _catalogComponents = const <MarineComponent>[];
  bool _loadingComponents = false;
  String? _componentLoadError;

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
    _generatorCountCtrl = TextEditingController(text: '1');
    _ownerId = _resolveInitialOwnerId(initial?.ownerId);

    final count = int.tryParse(_engineCtrl.text) ?? 1;
    final initialPositions = initial != null && initial.engineLabels.isNotEmpty
        ? _extractBasePositions(
            initial.engineLabels,
            count,
          ).map(_sanitizeEnginePosition).toList()
        : null;
    _syncEngineInputs(
      count,
      positions: initialPositions,
      serialNumbers: _resizeEngineSerialNumbers(
        count,
        initial?.engineSerialNumbers ?? const <String>[],
      ),
    );
    _associatedComponentLabels = _buildAssociatedComponentLabels();
    _hasJets = initial?.hasJets ?? false;
    _hasGearboxes = initial?.hasGearboxes ?? false;
    _syncAssociatedComponentControllers(
      _jetSerialCtrls,
      labels: _associatedComponentLabels,
      serialNumbers: initial?.jetSerialNumbers ?? const <String>[],
    );
    _syncAssociatedComponentControllers(
      _gearboxSerialCtrls,
      labels: _associatedComponentLabels,
      serialNumbers: initial?.gearboxSerialNumbers ?? const <String>[],
    );
    if (_associatedComponentLabels.isEmpty) {
      _hasJets = false;
      _hasGearboxes = false;
    }
    _hydrateComponentConfiguration(initial);
    _syncGeneratorSerialControllers(
      serialNumbers:
          initial?.components
              .where((component) => component.type == 'GENERATOR')
              .map((component) => component.serialNumber ?? '')
              .toList() ??
          const <String>[],
    );
    Future<void>.microtask(_loadCatalogComponents);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regCtrl.dispose();
    _modelCtrl.dispose();
    _engineCtrl.dispose();
    _lengthCtrl.dispose();
    _generatorCountCtrl.dispose();
    for (final controller in _engineSerialCtrls) {
      controller.dispose();
    }
    for (final controller in _jetSerialCtrls) {
      controller.dispose();
    }
    for (final controller in _gearboxSerialCtrls) {
      controller.dispose();
    }
    for (final controller in _generatorSerialCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialVessel != null;

    return NavalgoFormDialog(
      eyebrow: 'FLOTA',
      title: isEditing ? 'Editar embarcación' : 'Nueva embarcación',
      maxWidth: 680,
      subtitle:
          'Configura la embarcación, sus motores y el propietario desde una única ficha operativa.',
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
            if (!_validateSelectedComponents()) {
              return;
            }

            Navigator.pop(
              context,
              _VesselInput(
                name: _nameCtrl.text.trim(),
                registrationNumber: _regCtrl.text.trim().isEmpty
                    ? null
                    : _regCtrl.text.trim(),
                model: _modelCtrl.text.trim().isEmpty
                    ? null
                    : _modelCtrl.text.trim(),
                engineCount: int.tryParse(_engineCtrl.text.trim()),
                engineLabels: _buildEngineLabels(_enginePositions),
                engineSerialNumbers: _engineSerialCtrls
                    .map((controller) => controller.text.trim())
                    .toList(),
                hasJets: _hasJets,
                jetSerialNumbers: _jetSerialCtrls
                    .map((controller) => controller.text.trim())
                    .toList(),
                hasGearboxes: _hasGearboxes,
                gearboxSerialNumbers: _gearboxSerialCtrls
                    .map((controller) => controller.text.trim())
                    .toList(),
                components: _buildComponentPayload(),
                lengthMeters: _parseOptionalDecimal(_lengthCtrl.text),
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
                  return _validateRequiredText(
                    value,
                    'Indica el nombre de la embarcación.',
                  );
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
                validator: (value) => _validateOptionalText(value, 255),
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
                  prefixIcon: const Icon(Icons.description),
                ),
                validator: (value) => _validateOptionalText(value, 255),
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
                    _syncEngineInputs(int.tryParse(value) ?? 0),
              ),
            ),
            if (_enginePositions.isNotEmpty) ...[
              const SizedBox(height: 14),
              NavalgoFormFieldBlock(
                label: 'Tipo de motor',
                caption:
                    'Selecciona la posición o tipología de cada motor y añade justo debajo su número de serie.',
                child: Column(
                  children: List<Widget>.generate(_enginePositions.length, (
                    index,
                  ) {
                    return Builder(
                      builder: (context) {
                        final selectedPosition = _sanitizeEnginePosition(
                          _enginePositions[index],
                        );
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _enginePositions.length - 1
                                ? 0
                                : 16,
                          ),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: selectedPosition,
                                dropdownColor: NavalgoColors.shell,
                                decoration: NavalgoFormStyles.inputDecoration(
                                  context,
                                  label: 'Motor ${index + 1}',
                                  prefixIcon: Icon(
                                    _engineOptionIcon(selectedPosition),
                                  ),
                                ),
                                selectedItemBuilder: (context) {
                                  return _FlotaScreenState
                                      ._enginePositionOptions
                                      .map(
                                        (position) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(position),
                                        ),
                                      )
                                      .toList();
                                },
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
                                    _enginePositions[index] =
                                        _sanitizeEnginePosition(value);
                                    _refreshAssociatedComponentControls();
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              _buildCatalogComponentSelector(
                                type: 'ENGINE',
                                label: 'Modelo del motor',
                                selectedComponentId:
                                    index < _engineComponentIds.length
                                    ? _engineComponentIds[index]
                                    : null,
                                onChanged: (component) {
                                  setState(() {
                                    _engineComponentIds[index] = component.id;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _engineSerialCtrls[index],
                                textInputAction: TextInputAction.next,
                                decoration: NavalgoFormStyles.inputDecoration(
                                  context,
                                  label: 'Número de serie',
                                  hint:
                                      'Introduce el número de serie del motor',
                                  prefixIcon: const Icon(Icons.dialpad),
                                ),
                                validator: (value) =>
                                    _validateOptionalText(value, 255),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _buildAssociatedComponentSection(
              title: 'Jets',
              type: 'JET',
              value: _hasJets,
              onChanged: _associatedComponentLabels.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _hasJets = value ?? false;
                      });
                    },
              serialControllers: _jetSerialCtrls,
              componentIds: _jetComponentIds,
              onComponentChanged: (index, component) {
                setState(() {
                  _jetComponentIds[index] = component.id;
                });
              },
              serialFieldLabel: (index) => _associatedSerialFieldLabel(
                componentName: 'jet',
                engineLabel: _associatedComponentLabels[index],
              ),
            ),
            const SizedBox(height: 14),
            _buildAssociatedComponentSection(
              title: 'Reductoras',
              type: 'GEARBOX',
              value: _hasGearboxes,
              onChanged: _associatedComponentLabels.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _hasGearboxes = value ?? false;
                      });
                    },
              serialControllers: _gearboxSerialCtrls,
              componentIds: _gearboxComponentIds,
              onComponentChanged: (index, component) {
                setState(() {
                  _gearboxComponentIds[index] = component.id;
                });
              },
              serialFieldLabel: (index) => _associatedSerialFieldLabel(
                componentName: 'reductora',
                engineLabel: _associatedComponentLabels[index],
              ),
            ),
            const SizedBox(height: 14),
            _buildGeneratorSection(),
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
                validator: _validateOptionalDecimal,
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Propietario',
              child: widget.owners.isEmpty
                  ? Text(
                      'No hay propietarios disponibles.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : DropdownButtonFormField<int>(
                      initialValue:
                          widget.owners.any((owner) => owner.id == _ownerId)
                          ? _ownerId
                          : widget.owners.first.id,
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
                                  Text(
                                    o.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _ownerId = v ?? _ownerId),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _resolveInitialOwnerId(int? initialOwnerId) {
    if (widget.owners.isEmpty) {
      return initialOwnerId ?? 0;
    }
    if (initialOwnerId != null &&
        widget.owners.any((owner) => owner.id == initialOwnerId)) {
      return initialOwnerId;
    }
    return widget.owners.first.id;
  }

  String _sanitizeEnginePosition(String? rawValue) {
    final normalized = (rawValue ?? '').trim();
    if (_FlotaScreenState._enginePositionOptions.contains(normalized)) {
      return normalized;
    }
    return 'Fuera borda';
  }

  void _syncEngineInputs(
    int count, {
    List<String>? positions,
    List<String>? serialNumbers,
    List<int?>? componentIds,
  }) {
    final safeCount = count < 0 ? 0 : count;
    setState(() {
      final previousComponentIds = List<int?>.of(_engineComponentIds);
      _enginePositions = _resizeEnginePositions(
        safeCount,
        positions ?? _enginePositions,
      );
      _engineComponentIds = _resizeComponentIds(
        safeCount,
        componentIds ?? previousComponentIds,
      );

      final normalizedSerials = _resizeEngineSerialNumbers(
        safeCount,
        serialNumbers ?? _engineSerialCtrls.map((ctrl) => ctrl.text).toList(),
      );

      while (_engineSerialCtrls.length > safeCount) {
        _engineSerialCtrls.removeLast().dispose();
      }

      while (_engineSerialCtrls.length < safeCount) {
        _engineSerialCtrls.add(TextEditingController());
      }

      for (var index = 0; index < safeCount; index++) {
        if (_engineSerialCtrls[index].text != normalizedSerials[index]) {
          _engineSerialCtrls[index].text = normalizedSerials[index];
        }
      }

      _refreshAssociatedComponentControls();
    });
  }

  List<String> _resizeEnginePositions(int count, List<String> positions) {
    final normalized = positions.map(_sanitizeEnginePosition).toList();
    if (normalized.length >= count) {
      return normalized.take(count).toList();
    }

    return <String>[
      ...normalized,
      ...List<String>.filled(count - normalized.length, 'Fuera borda'),
    ];
  }

  List<String> _resizeEngineSerialNumbers(
    int count,
    List<String> serialNumbers,
  ) {
    final normalized = serialNumbers.map((item) => item.trim()).toList();
    if (normalized.length >= count) {
      return normalized.take(count).toList();
    }

    return <String>[
      ...normalized,
      ...List<String>.filled(count - normalized.length, ''),
    ];
  }

  List<int?> _resizeComponentIds(int count, List<int?> componentIds) {
    if (componentIds.length >= count) {
      return componentIds.take(count).toList();
    }
    return <int?>[
      ...componentIds,
      ...List<int?>.filled(count - componentIds.length, null),
    ];
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

  List<String> _buildAssociatedComponentLabels() {
    return _buildEngineLabels(
      _enginePositions,
    ).where((label) => _isAssociatedComponentPosition(label)).toList();
  }

  bool _isAssociatedComponentPosition(String label) {
    final baseLabel = label.replaceAll(RegExp(r'\s+\d+$'), '').trim();
    return baseLabel == 'Motor central' ||
        baseLabel == 'Babor' ||
        baseLabel == 'Estribor';
  }

  String _associatedSerialFieldLabel({
    required String componentName,
    required String engineLabel,
  }) {
    final position = engineLabel.trim().toLowerCase();
    return 'Número de serie de $componentName de $position';
  }

  int get _generatorCount {
    if (!_hasGenerators) {
      return 0;
    }
    final parsed = int.tryParse(_generatorCountCtrl.text.trim());
    if (parsed == null || parsed < 1) {
      return 0;
    }
    return parsed;
  }

  String _generatorLabel(int index, int total) {
    if (total <= 1) {
      return 'Generador';
    }
    return 'Generador ${index + 1}';
  }

  void _refreshAssociatedComponentControls() {
    final previousLabels = _associatedComponentLabels;
    final updatedLabels = _buildAssociatedComponentLabels();
    final jetValues = _mapControllerValues(previousLabels, _jetSerialCtrls);
    final gearboxValues = _mapControllerValues(
      previousLabels,
      _gearboxSerialCtrls,
    );
    final jetComponentIds = _mapComponentIds(previousLabels, _jetComponentIds);
    final gearboxComponentIds = _mapComponentIds(
      previousLabels,
      _gearboxComponentIds,
    );

    _associatedComponentLabels = updatedLabels;
    _syncAssociatedComponentControllers(
      _jetSerialCtrls,
      labels: updatedLabels,
      valuesByLabel: jetValues,
    );
    _jetComponentIds = _componentIdsFromLabels(updatedLabels, jetComponentIds);
    _syncAssociatedComponentControllers(
      _gearboxSerialCtrls,
      labels: updatedLabels,
      valuesByLabel: gearboxValues,
    );
    _gearboxComponentIds = _componentIdsFromLabels(
      updatedLabels,
      gearboxComponentIds,
    );

    if (updatedLabels.isEmpty) {
      _hasJets = false;
      _hasGearboxes = false;
    }
  }

  Map<String, String> _mapControllerValues(
    List<String> labels,
    List<TextEditingController> controllers,
  ) {
    final values = <String, String>{};
    for (
      var index = 0;
      index < labels.length && index < controllers.length;
      index++
    ) {
      values[labels[index]] = controllers[index].text.trim();
    }
    return values;
  }

  Map<String, int?> _mapComponentIds(List<String> labels, List<int?> ids) {
    final values = <String, int?>{};
    for (var index = 0; index < labels.length && index < ids.length; index++) {
      values[labels[index]] = ids[index];
    }
    return values;
  }

  List<int?> _componentIdsFromLabels(
    List<String> labels,
    Map<String, int?> valuesByLabel,
  ) {
    return labels.map((label) => valuesByLabel[label]).toList();
  }

  void _syncAssociatedComponentControllers(
    List<TextEditingController> controllers, {
    required List<String> labels,
    List<String>? serialNumbers,
    Map<String, String>? valuesByLabel,
  }) {
    final normalizedSerials = serialNumbers != null
        ? _resizeEngineSerialNumbers(labels.length, serialNumbers)
        : labels.map((label) => valuesByLabel?[label] ?? '').toList();

    while (controllers.length > labels.length) {
      controllers.removeLast().dispose();
    }

    while (controllers.length < labels.length) {
      controllers.add(TextEditingController());
    }

    for (var index = 0; index < labels.length; index++) {
      if (controllers[index].text != normalizedSerials[index]) {
        controllers[index].text = normalizedSerials[index];
      }
    }
  }

  void _syncGeneratorSerialControllers({
    List<String>? serialNumbers,
    List<int?>? componentIds,
  }) {
    final count = _generatorCount;
    _generatorComponentIds = _resizeComponentIds(
      count,
      componentIds ?? _generatorComponentIds,
    );
    final normalizedSerials = _resizeEngineSerialNumbers(
      count,
      serialNumbers ?? _generatorSerialCtrls.map((ctrl) => ctrl.text).toList(),
    );

    while (_generatorSerialCtrls.length > count) {
      _generatorSerialCtrls.removeLast().dispose();
    }

    while (_generatorSerialCtrls.length < count) {
      _generatorSerialCtrls.add(TextEditingController());
    }

    for (var index = 0; index < count; index++) {
      if (_generatorSerialCtrls[index].text != normalizedSerials[index]) {
        _generatorSerialCtrls[index].text = normalizedSerials[index];
      }
    }
  }

  Future<void> _loadCatalogComponents() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }
    setState(() {
      _loadingComponents = true;
      _componentLoadError = null;
    });
    try {
      final components = await context.read<FleetService>().getComponents(
        token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _catalogComponents = components;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _componentLoadError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingComponents = false;
        });
      }
    }
  }

  void _hydrateComponentConfiguration(Vessel? initial) {
    if (initial == null) {
      return;
    }
    final engineLabels = _buildEngineLabels(_enginePositions);
    _engineComponentIds = _componentIdsFor(
      initial.components,
      'ENGINE',
      engineLabels,
    );

    _jetComponentIds = _componentIdsFor(
      initial.components,
      'JET',
      _associatedComponentLabels,
    );
    _gearboxComponentIds = _componentIdsFor(
      initial.components,
      'GEARBOX',
      _associatedComponentLabels,
    );

    final generatorComponents = initial.components
        .where((component) => component.type == 'GENERATOR')
        .toList();
    if (generatorComponents.isNotEmpty) {
      _hasGenerators = true;
      _generatorCountCtrl.text = generatorComponents.length.toString();
      final generatorLabels = List<String>.generate(
        generatorComponents.length,
        (index) => _generatorLabel(index, generatorComponents.length),
      );
      _generatorComponentIds = _componentIdsFor(
        initial.components,
        'GENERATOR',
        generatorLabels,
      );
    }
  }

  List<int?> _componentIdsFor(
    List<VesselComponent> components,
    String type,
    List<String> labels,
  ) {
    final available = components
        .where((component) => component.type == type)
        .toList();
    return List<int?>.generate(labels.length, (index) {
      final label = labels[index].trim().toLowerCase();
      final byLabel = available.where(
        (component) => component.label.trim().toLowerCase() == label,
      );
      if (byLabel.isNotEmpty) {
        return byLabel.first.componentId;
      }
      if (index < available.length) {
        return available[index].componentId;
      }
      return null;
    });
  }

  String _componentTypeLabel(String type) {
    switch (type) {
      case 'ENGINE':
        return 'Motor';
      case 'GENERATOR':
        return 'Generador';
      case 'GEARBOX':
        return 'Reductora';
      case 'JET':
        return 'Jet';
      default:
        return 'Otro';
    }
  }

  List<Map<String, dynamic>> _buildComponentPayload() {
    final payload = <Map<String, dynamic>>[];
    final engineLabels = _buildEngineLabels(_enginePositions);
    for (var index = 0; index < engineLabels.length; index++) {
      _addInstalledComponentPayload(
        payload,
        type: 'ENGINE',
        label: engineLabels[index],
        componentId: index < _engineComponentIds.length
            ? _engineComponentIds[index]
            : null,
        serialNumber: index < _engineSerialCtrls.length
            ? _engineSerialCtrls[index].text.trim()
            : null,
      );
    }
    if (_hasJets) {
      for (var index = 0; index < _associatedComponentLabels.length; index++) {
        _addInstalledComponentPayload(
          payload,
          type: 'JET',
          label: _associatedComponentLabels[index],
          componentId: index < _jetComponentIds.length
              ? _jetComponentIds[index]
              : null,
          serialNumber: index < _jetSerialCtrls.length
              ? _jetSerialCtrls[index].text.trim()
              : null,
        );
      }
    }
    if (_hasGearboxes) {
      for (var index = 0; index < _associatedComponentLabels.length; index++) {
        _addInstalledComponentPayload(
          payload,
          type: 'GEARBOX',
          label: _associatedComponentLabels[index],
          componentId: index < _gearboxComponentIds.length
              ? _gearboxComponentIds[index]
              : null,
          serialNumber: index < _gearboxSerialCtrls.length
              ? _gearboxSerialCtrls[index].text.trim()
              : null,
        );
      }
    }
    final generatorCount = _generatorCount;
    for (var index = 0; index < generatorCount; index++) {
      _addInstalledComponentPayload(
        payload,
        type: 'GENERATOR',
        label: _generatorLabel(index, generatorCount),
        componentId: index < _generatorComponentIds.length
            ? _generatorComponentIds[index]
            : null,
        serialNumber: index < _generatorSerialCtrls.length
            ? _generatorSerialCtrls[index].text.trim()
            : null,
      );
    }
    return payload;
  }

  void _addInstalledComponentPayload(
    List<Map<String, dynamic>> payload, {
    required String type,
    required String label,
    required int? componentId,
    required String? serialNumber,
  }) {
    final component = _catalogComponentById(componentId);
    payload.add({
      'componentId': componentId,
      'type': type,
      'label': label,
      'manufacturer': component?.manufacturer,
      'model': component?.model,
      'serialNumber': (serialNumber ?? '').trim().isEmpty
          ? null
          : serialNumber!.trim(),
      'templateIds': component?.templateIds.toList() ?? const <int>[],
    });
  }

  MarineComponent? _catalogComponentById(int? componentId) {
    if (componentId == null) {
      return null;
    }
    for (final component in _catalogComponents) {
      if (component.id == componentId) {
        return component;
      }
    }
    return null;
  }

  Widget _buildCatalogComponentSelector({
    required String type,
    required String label,
    required int? selectedComponentId,
    required ValueChanged<MarineComponent> onChanged,
  }) {
    final selectedComponent = _catalogComponentById(selectedComponentId);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _loadingComponents
          ? null
          : () => _selectCatalogComponent(type: type, onChanged: onChanged),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NavalgoColors.border, width: 1.4),
        ),
        child: Row(
          children: [
            _MarineComponentIcon(type: type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: NavalgoColors.deepSea.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedComponent == null
                        ? 'Seleccionar ${_componentTypeLabel(type).toLowerCase()}'
                        : selectedComponent.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NavalgoColors.deepSea,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_componentLoadError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'No se pudo cargar el catalogo.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_loadingComponents)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCatalogComponent({
    required String type,
    required ValueChanged<MarineComponent> onChanged,
  }) async {
    final component = await showDialog<MarineComponent>(
      context: context,
      builder: (_) => _CatalogComponentPickerDialog(
        components: _catalogComponents,
        typeFilter: type,
      ),
    );
    if (!mounted || component == null) {
      return;
    }
    if (!_catalogComponents.any((item) => item.id == component.id)) {
      setState(() {
        _catalogComponents = [..._catalogComponents, component];
      });
    }
    onChanged(component);
  }

  bool _validateSelectedComponents() {
    final engineLabels = _buildEngineLabels(_enginePositions);
    for (var index = 0; index < engineLabels.length; index++) {
      if (index >= _engineComponentIds.length ||
          _engineComponentIds[index] == null) {
        AppToast.error(context, 'Selecciona el modelo de cada motor.');
        return false;
      }
    }
    if (_hasJets &&
        _hasMissingComponent(_associatedComponentLabels, _jetComponentIds)) {
      AppToast.error(context, 'Selecciona el modelo de cada jet.');
      return false;
    }
    if (_hasGearboxes &&
        _hasMissingComponent(
          _associatedComponentLabels,
          _gearboxComponentIds,
        )) {
      AppToast.error(context, 'Selecciona el modelo de cada reductora.');
      return false;
    }
    if (_hasGenerators &&
        _hasMissingComponent(
          List<String>.generate(
            _generatorCount,
            (index) => _generatorLabel(index, _generatorCount),
          ),
          _generatorComponentIds,
        )) {
      AppToast.error(context, 'Selecciona el modelo de cada generador.');
      return false;
    }
    return true;
  }

  bool _hasMissingComponent(List<String> labels, List<int?> componentIds) {
    for (var index = 0; index < labels.length; index++) {
      if (index >= componentIds.length || componentIds[index] == null) {
        return true;
      }
    }
    return false;
  }

  Widget _buildGeneratorSection() {
    return NavalgoFormFieldBlock(
      label: 'Generadores',
      caption: _hasGenerators
          ? 'Indica cuántos generadores lleva la embarcación.'
          : 'Activa esta opción si la embarcación tiene uno o varios generadores.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoPanel(
            tint: Colors.white.withValues(alpha: 0.96),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasGenerators,
              onChanged: (value) {
                setState(() {
                  _hasGenerators = value ?? false;
                  if (_hasGenerators &&
                      (_generatorCountCtrl.text.trim().isEmpty ||
                          (int.tryParse(_generatorCountCtrl.text.trim()) ?? 0) <
                              1)) {
                    _generatorCountCtrl.text = '1';
                  }
                  _syncGeneratorSerialControllers();
                });
              },
              title: const Text('¿Tiene generadores?'),
              subtitle: const Text(
                'Se crearán como componentes para asignarles plantillas.',
              ),
            ),
          ),
          if (_hasGenerators) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _generatorCountCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: NavalgoFormStyles.inputDecoration(
                context,
                label: 'Número de generadores',
                prefixIcon: const Icon(Icons.electrical_services_outlined),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                final count = int.tryParse(trimmed);
                if (count == null || count < 1) {
                  return 'Introduce cuántos generadores tiene.';
                }
                return null;
              },
              onChanged: (_) => setState(() {
                _syncGeneratorSerialControllers();
              }),
            ),
            if (_generatorSerialCtrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List<Widget>.generate(_generatorSerialCtrls.length, (index) {
                final label = _generatorLabel(
                  index,
                  _generatorSerialCtrls.length,
                );
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _generatorSerialCtrls.length - 1 ? 0 : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: NavalgoColors.deepSea,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildCatalogComponentSelector(
                        type: 'GENERATOR',
                        label: 'Modelo del generador',
                        selectedComponentId:
                            index < _generatorComponentIds.length
                            ? _generatorComponentIds[index]
                            : null,
                        onChanged: (component) {
                          setState(() {
                            _generatorComponentIds[index] = component.id;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _generatorSerialCtrls[index],
                        textInputAction: TextInputAction.next,
                        decoration: NavalgoFormStyles.inputDecoration(
                          context,
                          label: 'Número de serie',
                          hint: 'Introduce el número de serie del generador',
                          prefixIcon: const Icon(Icons.dialpad),
                        ),
                        validator: (value) => _validateOptionalText(value, 255),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAssociatedComponentSection({
    required String title,
    required String type,
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required List<TextEditingController> serialControllers,
    required List<int?> componentIds,
    required void Function(int index, MarineComponent component)
    onComponentChanged,
    required String Function(int index) serialFieldLabel,
  }) {
    final hasEligibleMotors = _associatedComponentLabels.isNotEmpty;
    return NavalgoFormFieldBlock(
      label: title,
      caption: hasEligibleMotors
          ? 'Se asociarán automáticamente según la posición del motor.'
          : 'Solo disponible cuando exista motor central, babor o estribor.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoPanel(
            tint: Colors.white.withValues(alpha: 0.96),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: value,
              onChanged: onChanged,
              title: Text('¿Tiene $title?'),
              subtitle: Text(
                hasEligibleMotors
                    ? 'Posiciones detectadas: ${_associatedComponentLabels.join(', ')}.'
                    : 'No hay motores compatibles configurados.',
              ),
            ),
          ),
          if (value && serialControllers.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List<Widget>.generate(serialControllers.length, (index) {
              final serialLabel = serialFieldLabel(index);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == serialControllers.length - 1 ? 0 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serialLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: NavalgoColors.deepSea,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildCatalogComponentSelector(
                      type: type,
                      label: 'Modelo de ${title.toLowerCase()}',
                      selectedComponentId: index < componentIds.length
                          ? componentIds[index]
                          : null,
                      onChanged: (component) =>
                          onComponentChanged(index, component),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: serialControllers[index],
                      textInputAction: TextInputAction.next,
                      decoration: NavalgoFormStyles.inputDecoration(
                        context,
                        label: 'Número de serie',
                        hint: 'Introduce el número de serie',
                        prefixIcon: const Icon(Icons.dialpad),
                      ),
                      validator: (value) => _validateOptionalText(value, 255),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _CatalogComponentPickerDialog extends StatefulWidget {
  const _CatalogComponentPickerDialog({
    required this.components,
    required this.typeFilter,
  });

  final List<MarineComponent> components;
  final String typeFilter;

  @override
  State<_CatalogComponentPickerDialog> createState() =>
      _CatalogComponentPickerDialogState();
}

class _CatalogComponentPickerDialogState
    extends State<_CatalogComponentPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<MarineComponent> _components;

  @override
  void initState() {
    super.initState();
    _components = List<MarineComponent>.of(widget.components);
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MarineComponent> get _filteredComponents {
    final query = _searchCtrl.text.trim().toLowerCase();
    final byType = _components
        .where((component) => component.type == widget.typeFilter)
        .toList();
    if (query.isEmpty) {
      return byType;
    }
    return byType.where((component) {
      final haystack = [
        component.name,
        component.manufacturer ?? '',
        component.model ?? '',
        _fleetComponentTypeLabel(component.type),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _createQuickComponent() async {
    final input = await showDialog<_QuickCatalogComponentInput>(
      context: context,
      builder: (_) =>
          _QuickCatalogComponentDialog(initialType: widget.typeFilter),
    );
    if (!mounted || input == null) {
      return;
    }
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }
    try {
      final saved = await context.read<FleetService>().createComponent(
        token,
        type: widget.typeFilter,
        name: input.name,
        manufacturer: input.manufacturer,
        model: input.model,
        templateIds: const <int>[],
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _components = [..._components, saved];
      });
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'No se pudo crear: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final components = _filteredComponents;
    return NavalgoFormDialog(
      eyebrow: 'FLOTA',
      title:
          'Seleccionar ${_fleetComponentTypeLabel(widget.typeFilter).toLowerCase()}',
      maxWidth: 620,
      actions: [
        TextButton.icon(
          onPressed: _createQuickComponent,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Nuevo'),
        ),
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavalgoSearchField(
            controller: _searchCtrl,
            label: 'Buscar',
            hint: 'Marca, modelo, nombre',
          ),
          const SizedBox(height: 12),
          if (components.isEmpty)
            const Text('Sin resultados.')
          else
            ...components.map(
              (component) => ListTile(
                leading: _MarineComponentIcon(type: component.type),
                title: Text(component.displayName),
                subtitle: Text(_fleetComponentTypeLabel(component.type)),
                onTap: () => Navigator.pop(context, component),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickCatalogComponentInput {
  const _QuickCatalogComponentInput({
    required this.name,
    this.manufacturer,
    this.model,
  });

  final String name;
  final String? manufacturer;
  final String? model;
}

class _QuickCatalogComponentDialog extends StatefulWidget {
  const _QuickCatalogComponentDialog({required this.initialType});

  final String initialType;

  @override
  State<_QuickCatalogComponentDialog> createState() =>
      _QuickCatalogComponentDialogState();
}

class _QuickCatalogComponentDialogState
    extends State<_QuickCatalogComponentDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _manufacturerCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manufacturerCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'COMPONENTES',
      title:
          'Nuevo ${_fleetComponentTypeLabel(widget.initialType).toLowerCase()}',
      maxWidth: 560,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Crear',
          icon: Icons.add_circle_outline,
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _QuickCatalogComponentInput(
                name: name,
                manufacturer: _manufacturerCtrl.text.trim().isEmpty
                    ? null
                    : _manufacturerCtrl.text.trim(),
                model: _modelCtrl.text.trim().isEmpty
                    ? null
                    : _modelCtrl.text.trim(),
              ),
            );
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Nombre',
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _manufacturerCtrl,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Marca',
              prefixIcon: const Icon(Icons.factory_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelCtrl,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Modelo',
              prefixIcon: const Icon(Icons.description_outlined),
            ),
          ),
        ],
      ),
    );
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
      eyebrow: 'FLOTA',
      title: vessel.name,
      subtitle:
          'Ficha técnica resumida con los datos que después reutiliza el flujo de Partes.',
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
              value: _displayRegistrationNumber(vessel.registrationNumber),
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Modelo',
            child: _VesselDetailValue(
              icon: Icons.description,
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
            label: 'Números de serie de motor',
            child: _VesselDetailValue(
              icon: Icons.dialpad,
              value: _buildEngineSerialSummary(vessel),
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Jets',
            child: _VesselDetailValue(
              icon: Icons.settings_input_component_outlined,
              value: _buildAssociatedSerialSummary(
                labels: vessel.jetLabels,
                serialNumbers: vessel.jetSerialNumbers,
                emptyLabel: 'No configurados',
              ),
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Reductoras',
            child: _VesselDetailValue(
              icon: Icons.precision_manufacturing_outlined,
              value: _buildAssociatedSerialSummary(
                labels: vessel.gearboxLabels,
                serialNumbers: vessel.gearboxSerialNumbers,
                emptyLabel: 'No configuradas',
              ),
            ),
          ),
          const SizedBox(height: 14),
          NavalgoFormFieldBlock(
            label: 'Componentes configurados',
            child: _VesselDetailValue(
              icon: Icons.fact_check_outlined,
              value: _buildComponentSummary(vessel),
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
                              value: '${e.engineLabel}: ${e.hours} h',
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
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavalgoColors.border),
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

String _buildEngineSerialSummary(Vessel vessel) {
  final totalEngines = <int>[
    vessel.engineCount ?? 0,
    vessel.engineLabels.length,
    vessel.engineSerialNumbers.length,
  ].reduce((current, next) => current > next ? current : next);

  if (totalEngines == 0) {
    return 'No indicado';
  }

  final lines = List<String>.generate(totalEngines, (index) {
    final label = index < vessel.engineLabels.length
        ? vessel.engineLabels[index]
        : 'Motor ${index + 1}';
    final serial = index < vessel.engineSerialNumbers.length
        ? vessel.engineSerialNumbers[index].trim()
        : '';
    return '$label: ${serial.isEmpty ? 'No indicado' : serial}';
  });

  return lines.join('\n');
}

List<VesselComponent> _vesselComponentsOfType(Vessel vessel, String type) {
  return vessel.components
      .where((component) => component.type.toUpperCase() == type)
      .toList();
}

bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

bool _hasEngineSpecs(Vessel vessel) {
  return (vessel.engineCount ?? 0) > 0 ||
      vessel.engineLabels.isNotEmpty ||
      vessel.engineSerialNumbers.any(_hasText) ||
      _vesselComponentsOfType(vessel, 'ENGINE').isNotEmpty;
}

bool _hasAssociatedSpecs({
  required List<String> labels,
  required List<String> serialNumbers,
}) {
  return labels.any(_hasText) || serialNumbers.any(_hasText);
}

bool _hasComponentSpecs(Vessel vessel, String type) {
  return _vesselComponentsOfType(vessel, type).any((component) {
    return _hasText(component.label) ||
        _hasText(component.manufacturer) ||
        _hasText(component.model) ||
        _hasText(component.serialNumber);
  });
}

String _buildEngineSpecSummary(Vessel vessel) {
  final components = _vesselComponentsOfType(vessel, 'ENGINE');
  if (components.isNotEmpty) {
    return _buildComponentTypeSummary(components);
  }
  return _buildEngineSerialSummary(vessel);
}

String _buildComponentTypeSummary(List<VesselComponent> components) {
  return components
      .map((component) {
        final label = component.label.trim().isNotEmpty
            ? component.label.trim()
            : _fleetComponentTypeLabel(component.type);
        final serial = component.serialNumber?.trim() ?? '';
        final details = <String>[
          if (_hasText(component.manufacturer)) component.manufacturer!.trim(),
          if (_hasText(component.model)) component.model!.trim(),
        ];
        final title = details.isEmpty
            ? label
            : '$label · ${details.join(' · ')}';
        return serial.isEmpty ? title : '$title: $serial';
      })
      .join('\n');
}

String _buildAssociatedSerialSummary({
  required List<String> labels,
  required List<String> serialNumbers,
  required String emptyLabel,
}) {
  if (labels.isEmpty) {
    return emptyLabel;
  }

  return List<String>.generate(labels.length, (index) {
    final serial = index < serialNumbers.length ? serialNumbers[index] : '';
    return '${labels[index]}: ${serial.trim().isEmpty ? 'No indicado' : serial.trim()}';
  }).join('\n');
}

String _buildComponentSummary(Vessel vessel) {
  if (vessel.components.isEmpty) {
    return 'Sin componentes configurados';
  }
  return vessel.components
      .map((component) {
        final details = <String>[
          component.type,
          component.label,
          if ((component.serialNumber ?? '').trim().isNotEmpty)
            'Serie ${component.serialNumber!.trim()}',
          if (component.templateNames.isNotEmpty)
            'Plantillas: ${component.templateNames.join(', ')}',
        ];
        return details.join(' · ');
      })
      .join('\n');
}

class _VesselAnalyticsDialog extends StatefulWidget {
  const _VesselAnalyticsDialog({required this.vessel});

  final Vessel vessel;

  @override
  State<_VesselAnalyticsDialog> createState() => _VesselAnalyticsDialogState();
}

class _VesselAnalyticsDialogState extends State<_VesselAnalyticsDialog> {
  VesselStats? _stats;
  String? _statsError;
  bool _loadingStats = false;
  bool _openingWorkOrder = false;

  bool get _canOpenWorkOrders =>
      context.read<SessionViewModel>().user?.role != 'COMERCIAL';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    setState(() {
      _loadingStats = true;
      _statsError = null;
    });

    try {
      final stats = await context.read<FleetService>().getVesselStats(
        token,
        vesselId: widget.vessel.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => _stats = stats);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = null;
        _statsError = 'No se pudieron cargar las estadisticas reales.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _openWorkOrderFromPoint(VesselEngineHourPoint point) async {
    await _openWorkOrderById(point.workOrderId);
  }

  Future<void> _openWorkOrderById(int workOrderId) async {
    if (_openingWorkOrder || workOrderId <= 0) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _openingWorkOrder = true);
    try {
      final workOrder = await context.read<WorkOrderService>().getWorkOrder(
        token,
        workOrderId: workOrderId,
      );
      if (!mounted) {
        return;
      }
      await openWorkOrderDetailsScreen(context, initialWorkOrder: workOrder);
      if (!mounted) {
        return;
      }
      await _loadStats();
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir el parte: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _openingWorkOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vessel = widget.vessel;
    final stats = _stats;
    final engineSummary = vessel.engineLabels.isEmpty
        ? 'Sin posiciones definidas'
        : vessel.engineLabels.join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(vessel.name),
        actions: [
          IconButton(
            onPressed: _loadingStats ? null : _loadStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: NavalgoPageBackground(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _VesselHeaderPanel(
                vessel: vessel,
                engineSummary: engineSummary,
                stats: stats,
                loading: _loadingStats,
                error: _statsError,
              ),
              const SizedBox(height: 16),
              _VesselAnalyticsSection(
                title: 'Ficha tecnica',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final normalWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    final wideWidth = constraints.maxWidth;

                    Widget buildCard({
                      IconData? icon,
                      String? iconAsset,
                      required String label,
                      required String value,
                      bool wide = false,
                    }) {
                      return SizedBox(
                        width: wide ? wideWidth : normalWidth,
                        child: _VesselSpecCard(
                          icon: icon,
                          iconAsset: iconAsset,
                          label: label,
                          value: value,
                        ),
                      );
                    }

                    final specCards = <Widget>[
                      buildCard(
                        icon: Icons.person_outline,
                        label: 'Propietario',
                        value: vessel.ownerName,
                      ),
                      buildCard(
                        icon: Icons.badge_outlined,
                        label: 'Matricula',
                        value: _displayRegistrationNumber(
                          vessel.registrationNumber,
                        ),
                      ),
                      buildCard(
                        icon: Icons.sailing_outlined,
                        label: 'Modelo',
                        value: vessel.model ?? 'No indicado',
                      ),
                      buildCard(
                        icon: Icons.straighten_outlined,
                        label: 'Eslora',
                        value: vessel.lengthMeters == null
                            ? 'No indicada'
                            : '${vessel.lengthMeters!.toStringAsFixed(1)} m',
                      ),
                    ];

                    if (_hasEngineSpecs(vessel)) {
                      specCards.add(
                        buildCard(
                          iconAsset: _marineComponentIconAsset('ENGINE'),
                          label: 'Motores',
                          value: _buildEngineSpecSummary(vessel),
                          wide: true,
                        ),
                      );
                    }

                    if (_hasComponentSpecs(vessel, 'JET') ||
                        _hasAssociatedSpecs(
                          labels: vessel.jetLabels,
                          serialNumbers: vessel.jetSerialNumbers,
                        )) {
                      final jetComponents = _vesselComponentsOfType(
                        vessel,
                        'JET',
                      );
                      specCards.add(
                        buildCard(
                          iconAsset: _marineComponentIconAsset('JET'),
                          label: 'Jets',
                          value: jetComponents.isNotEmpty
                              ? _buildComponentTypeSummary(jetComponents)
                              : _buildAssociatedSerialSummary(
                                  labels: vessel.jetLabels,
                                  serialNumbers: vessel.jetSerialNumbers,
                                  emptyLabel: 'No configurados',
                                ),
                          wide: true,
                        ),
                      );
                    }

                    if (_hasComponentSpecs(vessel, 'GEARBOX') ||
                        _hasAssociatedSpecs(
                          labels: vessel.gearboxLabels,
                          serialNumbers: vessel.gearboxSerialNumbers,
                        )) {
                      final gearboxComponents = _vesselComponentsOfType(
                        vessel,
                        'GEARBOX',
                      );
                      specCards.add(
                        buildCard(
                          iconAsset: _marineComponentIconAsset('GEARBOX'),
                          label: 'Reductoras',
                          value: gearboxComponents.isNotEmpty
                              ? _buildComponentTypeSummary(gearboxComponents)
                              : _buildAssociatedSerialSummary(
                                  labels: vessel.gearboxLabels,
                                  serialNumbers: vessel.gearboxSerialNumbers,
                                  emptyLabel: 'No configuradas',
                                ),
                          wide: true,
                        ),
                      );
                    }

                    if (_hasComponentSpecs(vessel, 'GENERATOR')) {
                      specCards.add(
                        buildCard(
                          iconAsset: _marineComponentIconAsset('GENERATOR'),
                          label: 'Generadores',
                          value: _buildComponentTypeSummary(
                            _vesselComponentsOfType(vessel, 'GENERATOR'),
                          ),
                          wide: true,
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: specCards,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _VesselAnalyticsSection(
                title: 'Resumen operativo',
                child: _loadingStats
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _statsError != null
                    ? _VesselDetailValue(
                        icon: Icons.error_outline,
                        value: _statsError!,
                      )
                    : _VesselStatsOverview(stats: stats),
              ),
              const SizedBox(height: 16),
              _VesselAnalyticsSection(
                title: 'Ultimas horas',
                child: stats == null || stats.latestEngineHours.isEmpty
                    ? const _VesselDetailValue(
                        icon: Icons.hourglass_empty_outlined,
                        value: 'Sin horas registradas',
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 760;
                          final cardWidth = compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 24) / 3;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: stats.latestEngineHours
                                .map(
                                  (item) => SizedBox(
                                    width: cardWidth,
                                    child: _LatestEngineHourCard(
                                      label: item.engineLabel,
                                      hours: item.hours,
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              _VesselAnalyticsSection(
                title: 'Horas de motor',
                child: stats == null || !stats.hasEngineData
                    ? const _VesselDetailValue(
                        icon: Icons.show_chart_outlined,
                        value: 'Sin datos suficientes',
                      )
                    : _VesselStatsChart(
                        stats: stats,
                        onPointTap: _canOpenWorkOrders
                            ? _openWorkOrderFromPoint
                            : (_) {},
                      ),
              ),
              if (_canOpenWorkOrders) ...[
                const SizedBox(height: 16),
                _VesselAnalyticsSection(
                  title: 'Partes asociados',
                  child: stats == null || stats.workOrderMilestones.isEmpty
                      ? const _VesselDetailValue(
                          icon: Icons.assignment_outlined,
                          value: 'Sin partes asociados',
                        )
                      : Column(
                          children: stats.workOrderMilestones
                              .map(
                                (milestone) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _VesselWorkOrderMilestoneCard(
                                    milestone: milestone,
                                    onTap: () => _openWorkOrderById(
                                      milestone.workOrderId,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VesselAnalyticsSection extends StatelessWidget {
  const _VesselAnalyticsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavalgoSectionHeader(title: title),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _VesselHeaderPanel extends StatelessWidget {
  const _VesselHeaderPanel({
    required this.vessel,
    required this.engineSummary,
    required this.stats,
    required this.loading,
    required this.error,
  });

  final Vessel vessel;
  final String engineSummary;
  final VesselStats? stats;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return NavalgoPanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 860;
          final summary = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _VesselSummaryChip(
                icon: Icons.person_outline,
                label: vessel.ownerName,
              ),
              _VesselSummaryChip(
                icon: Icons.badge_outlined,
                label: _displayRegistrationNumber(vessel.registrationNumber),
              ),
              _VesselSummaryChip(
                icon: Icons.speed_outlined,
                label: '${vessel.engineCount ?? 0} motor(es)',
              ),
              _VesselSummaryChip(
                icon: Icons.straighten_outlined,
                label: vessel.lengthMeters == null
                    ? 'Eslora no indicada'
                    : '${vessel.lengthMeters!.toStringAsFixed(1)} m',
              ),
              _VesselSummaryChip(
                icon: Icons.settings_suggest_outlined,
                label: engineSummary,
              ),
            ],
          );

          final statsCard = _VesselCompactStatsCard(
            stats: stats,
            loading: loading,
            error: error,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vessel.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    statsCard,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        vessel.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 250, child: statsCard),
                  ],
                ),
              const SizedBox(height: 16),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _VesselSummaryChip extends StatelessWidget {
  const _VesselSummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NavalgoColors.mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NavalgoColors.tide),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VesselCompactStatsCard extends StatelessWidget {
  const _VesselCompactStatsCard({
    required this.stats,
    required this.loading,
    required this.error,
  });

  final VesselStats? stats;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error ?? 'Actividad',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: NavalgoColors.deepSea,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (error == null && stats != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${stats!.totalWorkOrders} partes',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: NavalgoColors.deepSea,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatShortDate(stats!.lastRecordedAt) ?? 'Sin fecha',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
    );
  }
}

class _VesselSpecCard extends StatelessWidget {
  const _VesselSpecCard({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.value,
  });

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NavalgoColors.border),
        boxShadow: [
          BoxShadow(
            color: NavalgoColors.deepSea.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NavalgoColors.mist,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: iconAsset == null
                ? Icon(icon ?? Icons.info_outline, color: NavalgoColors.tide)
                : Image.asset(
                    iconAsset!,
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        icon ?? Icons.info_outline,
                        color: NavalgoColors.tide,
                      );
                    },
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: NavalgoColors.storm),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: NavalgoColors.deepSea,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestEngineHourCard extends StatelessWidget {
  const _LatestEngineHourCard({required this.label, required this.hours});

  final String label;
  final int hours;

  @override
  Widget build(BuildContext context) {
    return NavalgoMetricCard(
      label: label,
      value: '$hours h',
      icon: const Icon(Icons.speed_outlined),
      accent: NavalgoColors.harbor,
    );
  }
}

class _VesselStatsOverview extends StatelessWidget {
  const _VesselStatsOverview({required this.stats});

  final VesselStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const _VesselDetailValue(
        icon: Icons.analytics_outlined,
        value: 'Aun no hay datos operativos para esta embarcacion.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final cardWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _VesselMetricCard(
                icon: Icons.assignment_turned_in_outlined,
                label: 'Partes totales',
                value: '${stats!.totalWorkOrders}',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _VesselMetricCard(
                icon: Icons.speed_outlined,
                label: 'Partes con horas',
                value: '${stats!.workOrdersWithEngineHours}',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _VesselMetricCard(
                icon: Icons.schedule_outlined,
                label: 'Ultimo registro',
                value: _formatShortDate(stats!.lastRecordedAt) ?? 'Sin datos',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _VesselMetricCard(
                icon: Icons.trending_up_outlined,
                label: 'Hora maxima',
                value: stats!.highestRecordedHour == null
                    ? 'Sin datos'
                    : '${stats!.highestRecordedHour} h',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VesselMetricCard extends StatelessWidget {
  const _VesselMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NavalgoColors.tide),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: NavalgoColors.storm),
          ),
        ],
      ),
    );
  }
}

class _VesselStatsChart extends StatelessWidget {
  const _VesselStatsChart({required this.stats, required this.onPointTap});

  final VesselStats stats;
  final ValueChanged<VesselEngineHourPoint> onPointTap;

  @override
  Widget build(BuildContext context) {
    final allPoints = stats.engineSeries
        .expand((series) => series.points)
        .toList(growable: false);
    if (allPoints.isEmpty) {
      return const _VesselDetailValue(
        icon: Icons.show_chart_outlined,
        value: 'Sin puntos historicos para la grafica.',
      );
    }

    final sortedPoints = [...allPoints]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final minHours = allPoints
        .map((point) => point.hours)
        .reduce((current, next) => math.min(current, next));
    final maxHours = allPoints
        .map((point) => point.hours)
        .reduce((current, next) => math.max(current, next));

    final palette = <Color>[
      NavalgoColors.tide,
      NavalgoColors.kelp,
      NavalgoColors.sand,
      Colors.deepOrange,
      Colors.indigo,
      Colors.teal,
    ];
    final statusCounts = <String, int>{};
    for (final point in allPoints) {
      statusCounts.update(
        point.workOrderStatus,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < stats.engineSeries.length; index++)
              _ChartLegendChip(
                color: palette[index % palette.length],
                label:
                    '${stats.engineSeries[index].engineLabel} · ${stats.engineSeries[index].latestHours ?? '-'} h',
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NavalgoColors.border),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$maxHours h',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '$minHours h',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TappableVesselChartCanvas(
                        series: stats.engineSeries,
                        colors: palette,
                        onPointTap: onPointTap,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatShortDate(sortedPoints.first.recordedAt) ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: NavalgoColors.storm),
                  ),
                  Text(
                    _formatShortDate(sortedPoints.last.recordedAt) ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: NavalgoColors.storm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartLegendChip extends StatelessWidget {
  const _ChartLegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NavalgoColors.deepSea,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TappableVesselChartCanvas extends StatelessWidget {
  const _TappableVesselChartCanvas({
    required this.series,
    required this.colors,
    required this.onPointTap,
  });

  final List<VesselEngineHourSeries> series;
  final List<Color> colors;
  final ValueChanged<VesselEngineHourPoint> onPointTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 220);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final point = _findNearestChartPoint(
              series: series,
              size: size,
              tapPosition: details.localPosition,
            );
            if (point != null) {
              onPointTap(point);
            }
          },
          child: CustomPaint(
            painter: _VesselEngineHoursChartPainter(
              series: series,
              colors: colors,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _VesselWorkOrderMilestoneCard extends StatelessWidget {
  const _VesselWorkOrderMilestoneCard({
    required this.milestone,
    required this.onTap,
  });

  final VesselWorkOrderMilestone milestone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final engineHoursSummary = milestone.engineHours.isEmpty
        ? 'Sin horas registradas en este parte'
        : milestone.engineHours
              .map((item) => '${item.engineLabel}: ${item.hours} h')
              .join(' - ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
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
                    child: Text(
                      milestone.workOrderTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: NavalgoColors.deepSea,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(
                    label: _formatStatusLabel(milestone.workOrderStatus),
                    color: _statusColor(milestone.workOrderStatus),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatShortDate(milestone.recordedAt)} - ${milestone.maxHours == null ? 'Sin hora maxima' : 'Hasta ${milestone.maxHours} h'}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: NavalgoColors.storm),
              ),
              const SizedBox(height: 10),
              Text(
                engineHoursSummary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NavalgoColors.deepSea,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
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

class _VesselEngineHoursChartPainter extends CustomPainter {
  _VesselEngineHoursChartPainter({required this.series, required this.colors});

  final List<VesselEngineHourSeries> series;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = series
        .expand((item) => item.points)
        .toList(growable: false);
    if (allPoints.isEmpty) {
      return;
    }

    final minTime = allPoints
        .map((point) => point.recordedAt.millisecondsSinceEpoch.toDouble())
        .reduce(math.min);
    final maxTime = allPoints
        .map((point) => point.recordedAt.millisecondsSinceEpoch.toDouble())
        .reduce(math.max);
    final minHours = allPoints
        .map((point) => point.hours.toDouble())
        .reduce(math.min);
    final maxHours = allPoints
        .map((point) => point.hours.toDouble())
        .reduce(math.max);

    const horizontalPadding = 10.0;
    const verticalPadding = 12.0;
    final chartRect = Rect.fromLTWH(
      horizontalPadding,
      verticalPadding,
      size.width - (horizontalPadding * 2),
      size.height - (verticalPadding * 2),
    );

    final gridPaint = Paint()
      ..color = NavalgoColors.border
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = chartRect.top + (chartRect.height / 3) * index;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    double resolveX(DateTime recordedAt) {
      if (maxTime == minTime) {
        return chartRect.center.dx;
      }
      final ratio =
          (recordedAt.millisecondsSinceEpoch.toDouble() - minTime) /
          (maxTime - minTime);
      return chartRect.left + (chartRect.width * ratio);
    }

    double resolveY(int hours) {
      if (maxHours == minHours) {
        return chartRect.center.dy;
      }
      final ratio = (hours - minHours) / (maxHours - minHours);
      return chartRect.bottom - (chartRect.height * ratio);
    }

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final engineSeries = series[seriesIndex];
      if (engineSeries.points.isEmpty) {
        continue;
      }

      final color = colors[seriesIndex % colors.length];
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      final path = Path();

      for (
        var pointIndex = 0;
        pointIndex < engineSeries.points.length;
        pointIndex++
      ) {
        final point = engineSeries.points[pointIndex];
        final offset = Offset(
          resolveX(point.recordedAt),
          resolveY(point.hours),
        );
        if (pointIndex == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      canvas.drawPath(path, linePaint);

      for (final point in engineSeries.points) {
        final center = Offset(
          resolveX(point.recordedAt),
          resolveY(point.hours),
        );
        final incidentColor = _statusColor(point.workOrderStatus);
        final stemPaint = Paint()
          ..color = incidentColor.withValues(alpha: 0.16)
          ..strokeWidth = 2;
        final outerPaint = Paint()
          ..color = incidentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        final fillPaint = Paint()..color = color;
        canvas.drawLine(
          Offset(center.dx, center.dy),
          Offset(center.dx, chartRect.bottom),
          stemPaint,
        );
        canvas.drawCircle(center, 7, outerPaint);
        canvas.drawCircle(center, 4.6, fillPaint);
        canvas.drawCircle(center, 1.9, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VesselEngineHoursChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.colors != colors;
  }
}

VesselEngineHourPoint? _findNearestChartPoint({
  required List<VesselEngineHourSeries> series,
  required Size size,
  required Offset tapPosition,
}) {
  final allPoints = series
      .expand((item) => item.points)
      .toList(growable: false);
  if (allPoints.isEmpty || size.width <= 0 || size.height <= 0) {
    return null;
  }

  final minTime = allPoints
      .map((point) => point.recordedAt.millisecondsSinceEpoch.toDouble())
      .reduce(math.min);
  final maxTime = allPoints
      .map((point) => point.recordedAt.millisecondsSinceEpoch.toDouble())
      .reduce(math.max);
  final minHours = allPoints
      .map((point) => point.hours.toDouble())
      .reduce(math.min);
  final maxHours = allPoints
      .map((point) => point.hours.toDouble())
      .reduce(math.max);

  const horizontalPadding = 10.0;
  const verticalPadding = 12.0;
  final chartRect = Rect.fromLTWH(
    horizontalPadding,
    verticalPadding,
    size.width - (horizontalPadding * 2),
    size.height - (verticalPadding * 2),
  );

  double resolveX(DateTime recordedAt) {
    if (maxTime == minTime) {
      return chartRect.center.dx;
    }
    final ratio =
        (recordedAt.millisecondsSinceEpoch.toDouble() - minTime) /
        (maxTime - minTime);
    return chartRect.left + (chartRect.width * ratio);
  }

  double resolveY(int hours) {
    if (maxHours == minHours) {
      return chartRect.center.dy;
    }
    final ratio = (hours - minHours) / (maxHours - minHours);
    return chartRect.bottom - (chartRect.height * ratio);
  }

  VesselEngineHourPoint? bestPoint;
  double? bestDistance;
  const maxTapDistance = 18.0;

  for (final point in allPoints) {
    final pointOffset = Offset(
      resolveX(point.recordedAt),
      resolveY(point.hours),
    );
    final distance = (tapPosition - pointOffset).distance;
    if (distance > maxTapDistance) {
      continue;
    }
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestPoint = point;
    }
  }

  return bestPoint;
}

String? _formatShortDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _formatStatusLabel(String status) {
  switch (status) {
    case 'NEW':
      return 'Nuevo';
    case 'IN_PROGRESS':
      return 'En curso';
    case 'DONE':
      return 'Cerrado';
    case 'CANCELLED':
      return 'Cancelado';
    default:
      return status.replaceAll('_', ' ');
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'DONE':
      return NavalgoColors.kelp;
    case 'CANCELLED':
      return Colors.redAccent;
    case 'IN_PROGRESS':
      return NavalgoColors.tide;
    case 'NEW':
    default:
      return NavalgoColors.sand;
  }
}
