import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../models/worker_profile.dart';
import '../services/auth_service.dart';
import '../services/worker_photo_service.dart';
import '../services/worker_service.dart';
import '../theme/navalgo_theme.dart';
import '../utils/app_toast.dart';
import '../viewmodels/session_view_model.dart';
import 'navalgo_ui.dart';

Future<void> showProfileEditorDialog(BuildContext context) async {
  final session = context.read<SessionViewModel>();
  final token = session.token;
  final user = session.user;
  if (token == null || token.isEmpty) {
    AppToast.warning(context, 'No hay sesión activa.');
    return;
  }

  if (user == null) {
    AppToast.warning(context, 'No hay usuario activo.');
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) =>
        _ProfileEditorDialog(initialProfile: _fallbackProfile(user)),
  );
}

Future<void> showChangePasswordFormDialog(BuildContext context) async {
  final token = context.read<SessionViewModel>().token;
  if (token == null || token.isEmpty) {
    AppToast.warning(context, 'No hay sesión activa.');
    return;
  }

  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );

  if (changed == true && context.mounted) {
    AppToast.success(context, 'Contraseña actualizada correctamente.');
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog({required this.initialProfile});

  final WorkerProfile initialProfile;

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _specialityController;
  late WorkerProfile _profile;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  late String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _fullNameController = TextEditingController(text: _profile.fullName);
    _emailController = TextEditingController(text: _profile.email);
    _specialityController = TextEditingController(
      text: _profile.speciality ?? '',
    );
    _photoUrl = _profile.photoUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatestProfile());
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _specialityController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestProfile() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final latestProfile = await context.read<WorkerService>().getMyProfile(
        token,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = latestProfile;
        _photoUrl = latestProfile.photoUrl;
        _fullNameController.text = latestProfile.fullName;
        _emailController.text = latestProfile.email;
        _specialityController.text = latestProfile.speciality ?? '';
      });
    } catch (_) {
      // Keep the session-backed data so the form can still be edited offline.
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final session = context.read<SessionViewModel>();
    final currentUser = session.user;
    final token = session.token;
    if (currentUser == null || token == null || token.isEmpty) {
      AppToast.warning(context, 'No hay sesión activa.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final result = await context.read<WorkerService>().updateMyProfile(
        token,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        speciality: _specialityController.text.trim().isEmpty
            ? null
            : _specialityController.text.trim(),
      );

      await session.updateUser(
        currentUser.copyWith(
          name: result.worker.fullName,
          email: result.worker.email,
          role: result.worker.role,
          token: result.token,
          canEditWorkOrders: result.worker.canEditWorkOrders,
          mustChangePassword: result.worker.mustChangePassword,
          photoUrl: result.worker.photoUrl,
        ),
      );

      if (!mounted) {
        return;
      }

      AppToast.success(context, 'Perfil actualizado.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'No se pudo guardar el perfil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePhoto() async {
    final session = context.read<SessionViewModel>();
    final currentUser = session.user;
    final token = session.token;
    if (currentUser == null || token == null || token.isEmpty) {
      AppToast.warning(context, 'No hay sesión activa.');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 800,
    );
    if (picked == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final photoService = context.read<WorkerPhotoService>();
    final bytes = await picked.readAsBytes();

    setState(() => _isUploadingPhoto = true);

    try {
      final uploaded = await photoService.uploadPhoto(
        token,
        workerId: currentUser.id,
        fileName: picked.name,
        bytes: bytes,
        mimeType: picked.mimeType ?? 'image/jpeg',
      );

      await session.updateUser(
        currentUser.copyWith(
          name: uploaded.fullName,
          email: uploaded.email,
          role: uploaded.role,
          canEditWorkOrders: uploaded.canEditWorkOrders,
          mustChangePassword: uploaded.mustChangePassword,
          photoUrl: uploaded.photoUrl,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() => _photoUrl = uploaded.photoUrl);
      AppToast.success(context, 'Foto de perfil actualizada.');
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        AppToast.error(context, 'Error al subir foto: $message');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(_fullNameController.text);

    return NavalgoFormDialog(
      eyebrow: 'PERFIL PERSONAL',
      title: 'Actualiza tus datos',
      subtitle:
          'Edita nombre, correo y especialidad sin salir de la sesión. Si cambias el email, el acceso se renueva automáticamente.',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        NavalgoGradientButton(
          label: _isSaving ? 'Guardando...' : 'Guardar cambios',
          icon: Icons.save_outlined,
          onPressed: _isSaving ? null : _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 460;
                return Container(
                  padding: EdgeInsets.all(compact ? 16 : 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildProfileAvatar(context, initials),
                                const SizedBox(width: 16),
                                Expanded(child: _buildProfileSummary(context)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: NavalgoGhostButton(
                                label: _isUploadingPhoto
                                    ? 'Subiendo...'
                                    : 'Cambiar foto',
                                icon: Icons.photo_camera_outlined,
                                onPressed: _isUploadingPhoto
                                    ? null
                                    : _changePhoto,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            _buildProfileAvatar(context, initials),
                            const SizedBox(width: 16),
                            Expanded(child: _buildProfileSummary(context)),
                            const SizedBox(width: 12),
                            NavalgoGhostButton(
                              label: _isUploadingPhoto
                                  ? 'Subiendo...'
                                  : 'Cambiar foto',
                              icon: Icons.photo_camera_outlined,
                              onPressed: _isUploadingPhoto
                                  ? null
                                  : _changePhoto,
                            ),
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 18),
            NavalgoFormFieldBlock(
              label: 'Nombre completo',
              child: TextFormField(
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nombre completo',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Indica tu nombre.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Correo electrónico',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.alternate_email_outlined),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Indica tu correo.';
                  }
                  if (!trimmed.contains('@') || !trimmed.contains('.')) {
                    return 'Introduce un correo válido.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Especialidad',
              caption:
                  'Opcional, pero útil para identificar el perfil operativo.',
              child: TextFormField(
                controller: _specialityController,
                textInputAction: TextInputAction.done,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Especialidad',
                  hint: 'Motores, electrónica, carpintería...',
                  prefixIcon: const Icon(Icons.handyman_outlined),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final list = parts.take(2).toList();
    if (list.isEmpty) {
      return 'N';
    }
    return list.map((part) => part[0].toUpperCase()).join();
  }

  Widget _buildProfileAvatar(BuildContext context, String initials) {
    return CircleAvatar(
      radius: 32,
      backgroundColor: Colors.white,
      backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
          ? NetworkImage(_photoUrl!)
          : null,
      child: _photoUrl == null || _photoUrl!.isEmpty
          ? Text(
              initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: NavalgoColors.deepSea,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  Widget _buildProfileSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _profile.role == 'ADMIN' ? 'Administrador' : 'Trabajador',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _profile.canEditWorkOrders
              ? 'Con permiso de edición sobre partes'
              : 'Sin permiso de edición sobre partes',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final session = context.read<SessionViewModel>();
    final currentUser = session.user;
    final token = session.token;
    if (currentUser == null || token == null || token.isEmpty) {
      AppToast.warning(context, 'No hay sesión activa.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<AuthService>().changePassword(
        token,
        currentPassword: _currentController.text.trim(),
        newPassword: _newController.text.trim(),
      );

      await session.updateUser(currentUser.copyWith(mustChangePassword: false));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'No se pudo cambiar la contraseña: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      eyebrow: 'SEGURIDAD',
      title: 'Cambia tu contraseña',
      subtitle:
          'Usa una clave robusta de al menos 12 caracteres, con mayúsculas, minúsculas, números y símbolo.',
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
        ),
        NavalgoGradientButton(
          label: _isSaving ? 'Guardando...' : 'Guardar',
          icon: Icons.lock_reset_outlined,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavalgoFormFieldBlock(
              label: 'Contraseña actual',
              child: TextFormField(
                controller: _currentController,
                obscureText: !_showCurrent,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Contraseña actual',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    icon: Icon(
                      _showCurrent ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Introduce tu contraseña actual.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Nueva contraseña',
              caption: 'Mínimo 12 caracteres con una combinación fuerte.',
              child: TextFormField(
                controller: _newController,
                obscureText: !_showNew,
                textInputAction: TextInputAction.next,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showNew = !_showNew),
                    icon: Icon(
                      _showNew ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Introduce la nueva contraseña.';
                  }
                  if (trimmed.length < 12) {
                    return 'Debe tener al menos 12 caracteres.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Confirmar nueva contraseña',
              child: TextFormField(
                controller: _confirmController,
                obscureText: !_showConfirm,
                textInputAction: TextInputAction.done,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Confirmar nueva contraseña',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    icon: Icon(
                      _showConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Confirma la nueva contraseña.';
                  }
                  if (trimmed != _newController.text.trim()) {
                    return 'Las contraseñas no coinciden.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _isSaving ? null : _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

WorkerProfile _fallbackProfile(User user) {
  return WorkerProfile(
    id: user.id,
    fullName: user.name,
    email: user.email,
    speciality: null,
    role: user.role,
    active: true,
    mustChangePassword: user.mustChangePassword,
    canEditWorkOrders: user.canEditWorkOrders,
    contractStartDate: DateTime.now(),
    photoUrl: user.photoUrl,
  );
}
