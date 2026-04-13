import 'package:flutter/material.dart';

// Pantalla principal que muestra la lista de partes de trabajo
class PartesScreen extends StatefulWidget {
  const PartesScreen({super.key});

  @override
  State<PartesScreen> createState() => _PartesScreenState();
}

class _PartesScreenState extends State<PartesScreen> {
  // Datos simulados que reflejan la nueva estructura de la DB
  final List<Map<String, dynamic>> _partes = [
    {
      'titulo': 'Revisión anual de motor y casco',
      'cliente': 'Naviera Sur S.A.',
      'asignados': ['Carlos Jefe', 'Ana Mecánica'], // Ahora es una lista
      'urgente': true,
    },
    {
      'titulo': 'Reparación sistema eléctrico',
      'cliente': 'Juan Pérez',
      'asignados': ['Carlos Jefe'],
      'urgente': false,
    },
  ];

  void _mostrarFormularioNuevoParte() {
    showDialog(
      context: context,
      builder: (context) => const _FormularioParteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _partes.length,
        itemBuilder: (context, index) {
          final parte = _partes[index];
          final bool isUrgent = parte['urgente'];
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isUrgent ? Colors.red.shade100 : Colors.blue.shade100,
                child: Icon(Icons.build, color: isUrgent ? Colors.red.shade900 : Colors.blue.shade900),
              ),
              title: Text(parte['titulo'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              // Unimos la lista de asignados con comas
              subtitle: Text('Cliente: ${parte['cliente']}\nAsignado a: ${(parte['asignados'] as List).join(', ')}'),
              isThreeLine: true,
              trailing: Chip(
                label: Text(isUrgent ? 'Urgente' : 'En Curso'),
                backgroundColor: isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
                side: BorderSide.none,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormularioNuevoParte,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Parte'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// Widget interno y con estado para gestionar el formulario complejo
class _FormularioParteDialog extends StatefulWidget {
  const _FormularioParteDialog();

  @override
  State<_FormularioParteDialog> createState() => _FormularioParteDialogState();
}

class _FormularioParteDialogState extends State<_FormularioParteDialog> {
  final _formKey = GlobalKey<FormState>();
  int _numeroMotores = 1;
  
  // Lista de trabajadores disponibles (simulada)
  final List<Map<String, dynamic>> _trabajadoresDisponibles = [
      {'id': 1, 'nombre': 'Carlos Jefe'},
      {'id': 2, 'nombre': 'Ana Mecánica'},
      {'id': 4, 'nombre': 'Juan Pérez'},
  ];
  // Lista para guardar los trabajadores que se van seleccionando
  final List<Map<String, dynamic>> _trabajadoresSeleccionados = [];

  // Muestra un diálogo para seleccionar múltiples trabajadores
  void _seleccionarTrabajadores() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Asignar Trabajadores'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _trabajadoresDisponibles.length,
              itemBuilder: (context, index) {
                final trabajador = _trabajadoresDisponibles[index];
                // Usamos un StatefulWidget para manejar el estado del checkbox
                return _CheckboxListTile(
                  trabajador: trabajador,
                  seleccionados: _trabajadoresSeleccionados,
                  onChanged: (seleccionado) {
                    setState(() {
                      if (seleccionado) {
                        _trabajadoresSeleccionados.add(trabajador);
                      } else {
                        _trabajadoresSeleccionados.removeWhere((t) => t['id'] == trabajador['id']);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nuevo Parte de Trabajo', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CAMPOS PRINCIPALES ---
              TextFormField(decoration: InputDecoration(labelText: 'Título del Trabajo', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextFormField(decoration: InputDecoration(labelText: 'Seleccionar Embarcación', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              
              // --- ASIGNACIÓN DE TRABAJADORES ---
              const Text('Trabajadores Asignados', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  ..._trabajadoresSeleccionados.map((t) => Chip(label: Text(t['nombre']), onDeleted: () => setState(() => _trabajadoresSeleccionados.remove(t)))),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Asignar'),
                    onPressed: _seleccionarTrabajadores,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- HORAS DE MOTOR ---
              const Text('Registro de Motores', style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                initialValue: '1',
                decoration: InputDecoration(labelText: 'Número de motores', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() => _numeroMotores = int.tryParse(value) ?? 1),
              ),
              const SizedBox(height: 8),
              if (_numeroMotores > 0)
                ...List.generate(_numeroMotores, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(child: TextFormField(decoration: InputDecoration(labelText: 'Motor ${index + 1} (Babor, etc.)'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Horas'), keyboardType: TextInputType.number)),
                    ],
                  ),
                )),
              const SizedBox(height: 20),

              // --- ADJUNTAR ARCHIVOS ---
              const Text('Documentación Gráfica', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text('Adjuntar fotos o vídeos'),
                onPressed: () { /* TODO: Implementar file picker */ },
              ),
            ],
          ),
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parte creado exitosamente')));
          },
          child: const Text('Guardar Parte'),
        ),
      ],
    );
  }
}

// Pequeño widget para manejar el estado del checkbox dentro del diálogo
class _CheckboxListTile extends StatefulWidget {
  final Map<String, dynamic> trabajador;
  final List<Map<String, dynamic>> seleccionados;
  final ValueChanged<bool> onChanged;

  const _CheckboxListTile({required this.trabajador, required this.seleccionados, required this.onChanged});

  @override
  State<_CheckboxListTile> createState() => _CheckboxListTileState();
}

class _CheckboxListTileState extends State<_CheckboxListTile> {
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.seleccionados.any((t) => t['id'] == widget.trabajador['id']);
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(widget.trabajador['nombre']),
      value: _isChecked,
      onChanged: (bool? value) {
        setState(() => _isChecked = value ?? false);
        widget.onChanged(_isChecked);
      },
    );
  }
}