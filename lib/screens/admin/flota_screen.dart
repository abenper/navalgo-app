import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/owner.dart';
import '../../services/fleet_service.dart';
import '../../viewmodels/fleet_view_model.dart';
import '../../viewmodels/session_view_model.dart';

class FlotaScreen extends StatefulWidget {
  const FlotaScreen({super.key});

  @override
  State<FlotaScreen> createState() => _FlotaScreenState();
}

class _FlotaScreenState extends State<FlotaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetViewModel>().loadFleet();
    });
  }

  Future<void> _createOwner() async {
    final input = await showDialog<_OwnerInput>(
      context: context,
      builder: (_) => const _CreateOwnerDialog(),
    );
    if (input == null) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    try {
      await context.read<FleetService>().createOwner(
        token,
        type: input.type,
        displayName: input.displayName,
        documentId: input.documentId,
        phone: input.phone,
        email: input.email,
      );
      await context.read<FleetViewModel>().loadFleet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear el propietario: $e')),
        );
      }
    }
  }

  Future<void> _createVessel(List<Owner> owners) async {
    if (owners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero crea un propietario')),
      );
      return;
    }

    final input = await showDialog<_VesselInput>(
      context: context,
      builder: (_) => _CreateVesselDialog(owners: owners),
    );
    if (input == null) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }

    try {
      await context.read<FleetService>().createVessel(
        token,
        name: input.name,
        registrationNumber: input.registrationNumber,
        model: input.model,
        engineCount: input.engineCount,
        lengthMeters: input.lengthMeters,
        ownerId: input.ownerId,
      );
      await context.read<FleetViewModel>().loadFleet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear la embarcacion: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FleetViewModel>();

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
                      const Text(
                        'Propietarios',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...vm.owners.map((owner) {
                        final esEmpresa = owner.type == 'COMPANY';
                        final vesselCount = vm.vessels.where((v) => v.ownerId == owner.id).length;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  esEmpresa ? Colors.blue.shade50 : Colors.green.shade50,
                              child: Icon(
                                esEmpresa ? Icons.business : Icons.person,
                                color: esEmpresa
                                    ? Colors.blue.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                            title: Text(
                              owner.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${esEmpresa ? 'Empresa' : 'Particular'} • '
                              '${owner.documentId} • '
                              '$vesselCount embarcacion(es)',
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 18),
                      const Text(
                        'Embarcaciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...vm.vessels.map((vessel) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade50,
                                child: Icon(
                                  Icons.directions_boat,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              title: Text(
                                vessel.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${vessel.registrationNumber} • ${vessel.ownerName}\n'
                                'Modelo: ${vessel.model ?? 'N/D'} • Motores: ${vessel.engineCount ?? 0}',
                              ),
                              isThreeLine: true,
                            ),
                          )),
                    ],
                  ),
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab-owner',
            onPressed: _createOwner,
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo Propietario'),
            backgroundColor: Colors.blue.shade900,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab-vessel',
            onPressed: () => _createVessel(vm.owners),
            icon: const Icon(Icons.add),
            label: const Text('Nueva Embarcacion'),
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
          ),
        ],
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

class _CreateOwnerDialog extends StatefulWidget {
  const _CreateOwnerDialog();

  @override
  State<_CreateOwnerDialog> createState() => _CreateOwnerDialogState();
}

class _CreateOwnerDialogState extends State<_CreateOwnerDialog> {
  final _nameCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _type = 'PERSON';

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
    return AlertDialog(
      title: const Text('Nuevo Propietario'),
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
                labelText: 'Telefono',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
          child: const Text('Guardar'),
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
    this.lengthMeters,
    required this.ownerId,
  });

  final String name;
  final String registrationNumber;
  final String? model;
  final int? engineCount;
  final double? lengthMeters;
  final int ownerId;
}

class _CreateVesselDialog extends StatefulWidget {
  const _CreateVesselDialog({required this.owners});

  final List<Owner> owners;

  @override
  State<_CreateVesselDialog> createState() => _CreateVesselDialogState();
}

class _CreateVesselDialogState extends State<_CreateVesselDialog> {
  final _nameCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _engineCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  late int _ownerId;

  @override
  void initState() {
    super.initState();
    _ownerId = widget.owners.first.id;
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
    return AlertDialog(
      title: const Text('Nueva Embarcacion'),
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
                labelText: 'Matricula',
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
                labelText: 'Numero de motores',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _lengthCtrl,
              decoration: const InputDecoration(
                labelText: 'Eslora (m)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              onChanged: (v) => setState(() => _ownerId = v ?? _ownerId),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              _VesselInput(
                name: _nameCtrl.text.trim(),
                registrationNumber: _regCtrl.text.trim(),
                model: _modelCtrl.text.trim(),
                engineCount: int.tryParse(_engineCtrl.text.trim()),
                lengthMeters: double.tryParse(_lengthCtrl.text.trim()),
                ownerId: _ownerId,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
