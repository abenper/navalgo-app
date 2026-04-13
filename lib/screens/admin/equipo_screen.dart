import 'package:flutter/material.dart';

class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key});

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  // Datos simulados más estructurados
  final List<Map<String, dynamic>> _equipo = [
    {'id': 1, 'nombre': 'Carlos Jefe', 'especialidad': 'Electromecánica', 'activo': true},
    {'id': 2, 'nombre': 'Ana Mecánica', 'especialidad': 'Motores Diesel', 'activo': true},
    {'id': 3, 'nombre': 'Luis Gómez', 'especialidad': 'Cascos y Pintura', 'activo': false},
    {'id': 4, 'nombre': 'Juan Pérez', 'especialidad': 'Electrónica Naval', 'activo': true},
  ];

  void _mostrarFormularioNuevoTrabajador() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Añadir Trabajador', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Especialidad',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trabajador añadido')));
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _equipo.length,
        itemBuilder: (context, index) {
          final trabajador = _equipo[index];
          final bool isAvailable = trabajador['activo'] as bool;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.person, color: Colors.blue.shade900),
              ),
              title: Text(trabajador['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Especialidad: ${trabajador['especialidad']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAvailable ? Icons.check_circle : Icons.remove_circle, 
                    color: isAvailable ? Colors.green : Colors.grey
                  ),
                  const SizedBox(width: 8),
                  Text(isAvailable ? 'Activo' : 'Descanso'),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormularioNuevoTrabajador,
        icon: const Icon(Icons.add),
        label: const Text('Añadir Trabajador'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
    );
  }
}