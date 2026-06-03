import 'package:flutter/material.dart';

class ClientVesselPromptResult {
  const ClientVesselPromptResult({
    this.name,
    this.registrationNumber,
    this.model,
  });

  final String? name;
  final String? registrationNumber;
  final String? model;
}

Future<ClientVesselPromptResult?> showClientVesselPromptDialog(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'Guardar embarcación',
  String skipLabel = 'Lo haré después',
}) {
  return showDialog<ClientVesselPromptResult>(
    context: context,
    builder: (_) => _ClientVesselPromptDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
      skipLabel: skipLabel,
    ),
  );
}

class _ClientVesselPromptDialog extends StatefulWidget {
  const _ClientVesselPromptDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.skipLabel,
  });

  final String title;
  final String message;
  final String actionLabel;
  final String skipLabel;

  @override
  State<_ClientVesselPromptDialog> createState() =>
      _ClientVesselPromptDialogState();
}

class _ClientVesselPromptDialogState extends State<_ClientVesselPromptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _registrationCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _registrationCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final hasAnyValue =
        _nameCtrl.text.trim().isNotEmpty ||
        _registrationCtrl.text.trim().isNotEmpty ||
        _modelCtrl.text.trim().isNotEmpty;

    if (!hasAnyValue) {
      Navigator.of(context).pop(const ClientVesselPromptResult());
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      ClientVesselPromptResult(
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
                ),
                validator: (value) {
                  if ((_registrationCtrl.text.trim().isNotEmpty ||
                          _modelCtrl.text.trim().isNotEmpty) &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Indica el nombre de la embarcación';
                  }
                  if ((value?.trim() ?? '').length > 255) {
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
                decoration: const InputDecoration(labelText: 'Modelo'),
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
          onPressed: () =>
              Navigator.of(context).pop(const ClientVesselPromptResult()),
          child: Text(widget.skipLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
