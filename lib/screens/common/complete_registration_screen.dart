import 'package:flutter/material.dart';
import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/network/api_exception.dart';
import 'package:navalgo/theme/navalgo_theme.dart';
import 'package:navalgo/widgets/client_vessel_prompt_dialog.dart';
import 'package:navalgo/widgets/navalgo_logo.dart';
import 'package:provider/provider.dart';

import 'login_screen.dart';
import 'privacy_policy_screen.dart';

const String completeRegistrationQueryKey = 'screen';
const String completeRegistrationQueryValue = 'complete-registration';

bool isCompleteRegistrationEntryUri(Uri uri) {
  final screen = uri.queryParameters[completeRegistrationQueryKey];
  return screen == completeRegistrationQueryValue;
}

class CompleteRegistrationScreen extends StatefulWidget {
  const CompleteRegistrationScreen({super.key, required this.token});

  final String token;

  @override
  State<CompleteRegistrationScreen> createState() =>
      _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState
    extends State<CompleteRegistrationScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  RegistrationInvitationInfo? _invitationInfo;
  String? _loadError;
  String? _submitError;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _completed = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitation() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final info = await context
          .read<AuthService>()
          .getRegistrationInvitationStatus(widget.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _invitationInfo = info;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = _describeError(error);
      });
    }
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final validationError = _validatePassword(password, confirmPassword);
    if (validationError != null) {
      setState(() {
        _submitError = validationError;
      });
      return;
    }

    setState(() {
      _submitError = null;
      _isSubmitting = true;
    });

    try {
      final vesselPrompt = await showClientVesselPromptDialog(
        context,
        title: 'Registra tu embarcación',
        message:
            'Puedes registrar tu embarcación ahora para que presupuestos, trabajos y documentación queden asociados desde el principio. Si prefieres, puedes hacerlo más tarde.',
        actionLabel: 'Continuar',
      );
      if (!mounted) {
        return;
      }

      await context.read<AuthService>().completeRegistration(
        token: widget.token,
        password: password,
        vesselName: vesselPrompt?.name,
        vesselRegistrationNumber: vesselPrompt?.registrationNumber,
        vesselModel: vesselPrompt?.model,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _completed = true;
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = _describeError(error);
      });
    }
  }

  String? _validatePassword(String password, String confirmPassword) {
    if (password.length < 12) {
      return 'La contraseña debe tener al menos 12 caracteres.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Incluye mayúsculas, minúsculas, números y un símbolo.';
    }
    if (password != confirmPassword) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.userMessage;
    }
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : 'No se pudo completar el registro.';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: NavalgoColors.foam,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PublicBrandMark(),
                  const SizedBox(height: 28),
                  Text(
                    _completed
                        ? 'Registro completado'
                        : 'Completa tu acceso a Naval-GO',
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_loadError != null)
                    _ErrorCard(message: _loadError!, onRetry: _loadInvitation)
                  else if (_completed)
                    _SuccessCard(email: _invitationInfo?.email ?? '')
                  else
                    _RegistrationCard(
                      invitationInfo: _invitationInfo!,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      obscurePassword: _obscurePassword,
                      obscureConfirmPassword: _obscureConfirmPassword,
                      isSubmitting: _isSubmitting,
                      submitError: _submitError,
                      onTogglePassword: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onToggleConfirmPassword: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      onSubmit: _submit,
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const PrivacyPolicyScreen(isPublicEntry: true),
                        ),
                      );
                    },
                    child: const Text('Consultar Política de Privacidad'),
                  ),
                  if (_completed)
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      child: const Text('Ir a iniciar sesión'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicBrandMark extends StatelessWidget {
  const _PublicBrandMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: NavalgoColors.deepSea.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const NavalgoLogo(
          variant: NavalgoLogoVariant.colorBadge,
          width: 104,
          height: 104,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No pudimos validar el enlace',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          email.isEmpty
              ? 'Tu cuenta ya está lista. Ya puedes iniciar sesión con tu nueva contraseña.'
              : 'Tu cuenta ya está lista. Ya puedes iniciar sesión con $email y tu nueva contraseña.',
        ),
      ),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.invitationInfo,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.isSubmitting,
    required this.submitError,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSubmit,
  });

  final RegistrationInvitationInfo invitationInfo;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isSubmitting;
  final String? submitError;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invitationInfo.fullName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(invitationInfo.email),
            const SizedBox(height: 6),
            Text(
              'Enlace válido hasta ${_formatDateTime(invitationInfo.expiresAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              enabled: !isSubmitting,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                helperText:
                    'Mínimo 12 caracteres con mayúsculas, minúsculas, números y símbolo.',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,
              enabled: !isSubmitting,
              onSubmitted: (_) => isSubmitting ? null : onSubmit(),
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                suffixIcon: IconButton(
                  onPressed: onToggleConfirmPassword,
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (submitError != null) ...[
              const SizedBox(height: 12),
              Text(
                submitError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar contraseña'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
