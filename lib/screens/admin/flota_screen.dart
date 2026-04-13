import 'package:flutter/material.dart';

class FlotaScreen extends StatefulWidget {
  const FlotaScreen({super.key});

  @override
  State<FlotaScreen> createState() => _FlotaScreenState();
}

class _FlotaScreenState extends State<FlotaScreen> {
  final List<Map<String, dynamic>> _clientes = [
    {'nombre': 'Naviera Sur S.A.', 'tipo': 'Empresa', 'barcos': 3},
    {'nombre': 'Antonio Banderas', 'tipo': 'Particular', 'barcos': 1},
  ];

  void _mostrarFormularioCliente() {
    showDialog(
      context: context,
      builder: (context) {
        return const _FormularioClienteDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _clientes.length,
        itemBuilder: (context, index) {
          final cliente = _clientes[index];
          final esEmpresa = cliente['tipo'] == 'Empresa';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: esEmpresa ? Colors.blue.shade50 : Colors.green.shade50,
                child: Icon(esEmpresa ? Icons.business : Icons.person, color: esEmpresa ? Colors.blue.shade900 : Colors.green.shade900),
              ),
              title: Text(cliente['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${cliente['tipo']} • ${cliente['barcos']} Embarcación(es)'),
              trailing: IconButton(
                icon: const Icon(Icons.directions_boat),
                tooltip: 'Ver Embarcaciones',
                onPressed: () {},
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormularioCliente,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Propietario'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _FormularioClienteDialog extends StatefulWidget {
  const _FormularioClienteDialog();

  @override
  State<_FormularioClienteDialog> createState() => _FormularioClienteDialogState();
}

class _FormularioClienteDialogState extends State<_FormularioClienteDialog> {
  String _tipoCliente = 'Particular';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Registrar Propietario', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selección de Tipo
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'Particular',
                  groupValue: _tipoCliente,
                  onChanged: (val) => setState(() => _tipoCliente = val!),
                ),
                const Text('Particular'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'Empresa',
                  groupValue: _tipoCliente,
                  onChanged: (val) => setState(() => _tipoCliente = val!),
                ),
                const Text('Empresa'),
              ],
            ),
            const SizedBox(height: 12),
            
            TextField(
              decoration: InputDecoration(
                labelText: _tipoCliente == 'Empresa' ? 'Nombre de la Empresa' : 'Nombre Completo', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
              )
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: _tipoCliente == 'Empresa' ? 'CIF' : 'DNI / NIE', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
              )
            ),
            const SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade900, 
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado correctamente')));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}