import 'package:flutter/material.dart';

class AusenciasScreen extends StatefulWidget {
  const AusenciasScreen({super.key});

  @override
  State<AusenciasScreen> createState() => _AusenciasScreenState();
}

class _AusenciasScreenState extends State<AusenciasScreen> {
  // Simulador de peticiones de ausencias
  final List<Map<String, dynamic>> _requests = [
    {'fecha': '15 Ago - 30 Ago', 'estado': 'Aprobada', 'color': Colors.green, 'motivo': 'Vacaciones'},
    {'fecha': '24 Dic', 'estado': 'Pendiente', 'color': Colors.orange, 'motivo': 'Asuntos Propios'},
  ];

  void _mostrarFormulario() async {
    // Abrimos el nuevo diálogo y esperamos su resultado
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _FormularioAusenciaDialog(),
    );

    // Si el usuario guardó (no canceló), lo añadimos a la lista
    if (result != null) {
      setState(() {
        _requests.insert(0, result);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada exitosamente')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (req['color'] as Color).withValues(alpha: 0.1),
                child: Icon(Icons.event_note, color: req['color'] as Color),
              ),
              title: Text('Fechas: ${req['fecha']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Motivo: ${req['motivo']}'),
              trailing: Chip(
                label: Text(req['estado'] as String),
                backgroundColor: (req['color'] as Color).withValues(alpha: 0.1),
                labelStyle: TextStyle(color: req['color'] as Color, fontWeight: FontWeight.bold),
                side: BorderSide.none,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormulario,
        icon: const Icon(Icons.add),
        label: const Text('Solicitar Ausencia'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _FormularioAusenciaDialog extends StatefulWidget {
  const _FormularioAusenciaDialog();

  @override
  State<_FormularioAusenciaDialog> createState() => _FormularioAusenciaDialogState();
}

class _FormularioAusenciaDialogState extends State<_FormularioAusenciaDialog> {
  String _motivo = 'Vacaciones';
  DateTimeRange? _fechas;

  final List<String> _motivos = [
    'Vacaciones',
    'Médico',
    'Maternidad/Paternidad',
    'Asuntos Propios',
    'Otro'
  ];

  String _format(DateTime d) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${d.day} ${months[d.month - 1]}';
  }

  String get _textoFechas {
    if (_fechas == null) return 'Toca para seleccionar fechas...';
    // Si es el mismo día de inicio y fin, mostramos solo un día
    if (_fechas!.start == _fechas!.end) return _format(_fechas!.start);
    return '${_format(_fechas!.start)} - ${_format(_fechas!.end)}';
  }

  Future<void> _seleccionarFechas() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _fechas,
      helpText: 'SELECCIONA FECHAS (Toca 2 veces para 1 solo día)',
      confirmText: 'GUARDAR', // Botón de confirmación en español
      cancelText: 'CANCELAR', // Botón de cancelar en español
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade900),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechas = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Solicitar Ausencia', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Motivo', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _motivo,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: _motivos.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (val) => setState(() => _motivo = val!),
          ),
          const SizedBox(height: 20),
          const Text('Fechas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.maxFinite,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.calendar_today),
              label: Text(_textoFechas, style: const TextStyle(fontSize: 16, color: Colors.black87)),
              onPressed: _seleccionarFechas,
            ),
          ),
        ],
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
            if (_fechas == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona las fechas')));
              return;
            }
            Navigator.pop(context, {
              'fecha': _textoFechas,
              'estado': 'Pendiente',
              'color': Colors.orange,
              'motivo': _motivo,
            });
          },
          child: const Text('Solicitar'),
        ),
      ],
    );
  }
}