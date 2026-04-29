import 'package:flutter/material.dart';

import '../../theme/navalgo_theme.dart';
import '../../widgets/navalgo_ui.dart';

class AusenciasScreen extends StatefulWidget {
  const AusenciasScreen({super.key});

  @override
  State<AusenciasScreen> createState() => _AusenciasScreenState();
}

class _AusenciasScreenState extends State<AusenciasScreen> {
  final List<Map<String, dynamic>> _requests = [
    {
      'fecha': '15 Ago - 30 Ago',
      'estado': 'Aprobada',
      'color': NavalgoColors.kelp,
      'motivo': 'Vacaciones',
    },
    {
      'fecha': '24 Dic',
      'estado': 'Pendiente',
      'color': NavalgoColors.sand,
      'motivo': 'Asuntos Propios',
    },
  ];

  Future<void> _mostrarFormulario() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _FormularioAusenciaDialog(),
    );

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
          final color = req['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NavalgoPanel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.event_note_outlined, color: color),
                ),
                title: Text(
                  'Fechas: ${req['fecha']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Motivo: ${req['motivo']}'),
                ),
                trailing: NavalgoStatusChip(
                  label: req['estado'] as String,
                  color: color,
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormulario,
        icon: const Icon(Icons.add),
        label: const Text('Solicitar ausencia'),
      ),
    );
  }
}

class _FormularioAusenciaDialog extends StatefulWidget {
  const _FormularioAusenciaDialog();

  @override
  State<_FormularioAusenciaDialog> createState() =>
      _FormularioAusenciaDialogState();
}

class _FormularioAusenciaDialogState extends State<_FormularioAusenciaDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _motivo = 'Vacaciones';
  DateTimeRange? _fechas;

  final List<String> _motivos = [
    'Vacaciones',
    'Médico',
    'Maternidad/Paternidad',
    'Asuntos Propios',
    'Otro',
  ];

  String _format(DateTime d) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String get _textoFechas {
    if (_fechas == null) {
      return 'Toca para seleccionar fechas';
    }
    if (_fechas!.start == _fechas!.end) {
      return _format(_fechas!.start);
    }
    return '${_format(_fechas!.start)} - ${_format(_fechas!.end)}';
  }

  Future<void> _seleccionarFechas() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _fechas,
      helpText: 'Selecciona fechas',
      confirmText: 'Guardar',
      cancelText: 'Cancelar',
      saveText: 'Guardar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: NavalgoColors.tide,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: NavalgoColors.ink,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: NavalgoColors.deepSea,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechas = picked);
    }
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_fechas == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona las fechas')),
      );
      return;
    }

    Navigator.pop(context, {
      'fecha': _textoFechas,
      'estado': 'Pendiente',
      'color': NavalgoColors.sand,
      'motivo': _motivo,
    });
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      title: 'Solicitar ausencia',
      subtitle:
          'Usa la misma estructura del sistema para indicar motivo y rango de fechas.',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Solicitar',
          icon: Icons.event_available_outlined,
          onPressed: _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NavalgoFormFieldBlock(
              label: 'Motivo',
              child: DropdownButtonFormField<String>(
                initialValue: _motivo,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Motivo',
                  prefixIcon: const Icon(Icons.fact_check_outlined),
                ),
                items: _motivos
                    .map(
                      (motivo) =>
                          DropdownMenuItem(value: motivo, child: Text(motivo)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _motivo = value ?? _motivo),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Fechas',
              caption:
                  'Selecciona un rango o toca dos veces el mismo día para una ausencia de una sola jornada.',
              child: NavalgoPickerField(
                label: 'Fechas',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                value: _fechas == null ? null : _textoFechas,
                placeholder: 'Toca para seleccionar fechas',
                onTap: _seleccionarFechas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
