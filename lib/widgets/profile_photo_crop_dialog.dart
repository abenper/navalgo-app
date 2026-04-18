import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../theme/navalgo_theme.dart';
import '../utils/app_toast.dart';
import 'navalgo_ui.dart';

Future<Uint8List?> showProfilePhotoCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    builder: (_) => _ProfilePhotoCropDialog(imageBytes: imageBytes),
  );
}

class _ProfilePhotoCropDialog extends StatefulWidget {
  const _ProfilePhotoCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_ProfilePhotoCropDialog> createState() =>
      _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<_ProfilePhotoCropDialog> {
  final CropController _cropController = CropController();
  bool _isCropping = false;

  void _applyCrop() {
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'FOTO DE PERFIL',
      title: 'Ajusta el encuadre',
      subtitle:
          'Mueve y acerca la imagen hasta dejar visible la zona que quieres usar como avatar.',
      maxWidth: 760,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
        ),
        NavalgoGradientButton(
          label: _isCropping ? 'Recortando...' : 'Aplicar recorte',
          icon: Icons.crop,
          onPressed: _isCropping ? null : _applyCrop,
        ),
      ],
      child: SizedBox(
        height: 460,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Crop(
            image: widget.imageBytes,
            controller: _cropController,
            aspectRatio: 1,
            withCircleUi: true,
            interactive: true,
            radius: 24,
            baseColor: NavalgoColors.deepSea,
            maskColor: Colors.black.withValues(alpha: 0.42),
            progressIndicator: const Center(child: CircularProgressIndicator()),
            onCropped: (result) {
              switch (result) {
                case CropSuccess(:final croppedImage):
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(context).pop(Uint8List.fromList(croppedImage));
                  return;
                case CropFailure(:final cause):
                  if (!mounted) {
                    return;
                  }
                  setState(() => _isCropping = false);
                  AppToast.error(
                    context,
                    'No se pudo recortar la imagen: $cause',
                  );
                  return;
              }
            },
          ),
        ),
      ),
    );
  }
}
