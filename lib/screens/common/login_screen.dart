import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/network/api_exception.dart';
import 'package:navalgo/theme/navalgo_theme.dart';
import 'package:navalgo/utils/app_toast.dart';
import 'package:navalgo/viewmodels/login_view_model.dart';
import 'package:navalgo/viewmodels/session_view_model.dart';

import '../admin/admin_shell_screen.dart';
import '../worker/worker_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _recuerdame = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionViewModel>();
    _recuerdame = session.rememberMeEnabled;
    if (session.rememberedEmail.isNotEmpty) {
      _emailController.text = session.rememberedEmail;
    }

    final pendingNotice = session.consumePendingNotice();
    if (pendingNotice != null && pendingNotice.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppToast.warning(context, pendingNotice);
        }
      });
    }

    if (session.isAuthenticated && session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openShellForRole(session.user!.role);
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _enforcePasswordChange({
    required String token,
    required String currentPassword,
  }) async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isSaving = false;
    String? errorMessage;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                Future<void> submit() async {
                  final newPassword = newPasswordController.text.trim();
                  final confirmPassword = confirmPasswordController.text.trim();
                  final validationMessage = _validateRequiredPasswordChange(
                    newPassword,
                    confirmPassword,
                  );

                  if (validationMessage != null) {
                    setState(() {
                      errorMessage = validationMessage;
                    });
                    return;
                  }

                  setState(() {
                    isSaving = true;
                    errorMessage = null;
                  });

                  try {
                    await context.read<AuthService>().changePassword(
                      token,
                      currentPassword: currentPassword,
                      newPassword: newPassword,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } catch (error) {
                    if (context.mounted) {
                      setState(() {
                        isSaving = false;
                        errorMessage = _describePasswordChangeError(error);
                      });
                    }
                  }
                }

                return AlertDialog(
                  title: const Text('Cambia tu contraseña'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          enabled: !isSaving,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contraseña',
                            helperText:
                                'Mín. 12 caracteres con mayúsculas, minúsculas, números y un símbolo.',
                            helperMaxLines: 2,
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          enabled: !isSaving,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => isSaving ? null : submit(),
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    FilledButton(
                      onPressed: isSaving ? null : submit,
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
      return result == true;
    } finally {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  String? _validateRequiredPasswordChange(
    String newPassword,
    String confirmPassword,
  ) {
    if (newPassword.length < 12) {
      return 'La contraseña debe tener al menos 12 caracteres.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(newPassword) ||
        !RegExp(r'[a-z]').hasMatch(newPassword) ||
        !RegExp(r'[0-9]').hasMatch(newPassword) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(newPassword)) {
      return 'Debe incluir mayúsculas, minúsculas, números y un símbolo.';
    }
    if (newPassword != confirmPassword) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  String _describePasswordChangeError(Object error) {
    if (error is ApiException) {
      return error.serverMessage ?? 'No se pudo cambiar la contraseña.';
    }

    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return 'No se pudo cambiar la contraseña.';
  }

  void _openShellForRole(String role) {
    if (role == 'ADMIN') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminShellScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WorkerShellScreen()),
      );
    }
  }

  void _showLoginFeedback(String message) {
    final isCredentialsError =
        message.contains('incorrectos') || message.contains('desactivada');
    if (isCredentialsError) {
      AppToast.error(context, message);
      return;
    }
    AppToast.info(context, message);
  }

  Future<void> _submit(LoginViewModel loginViewModel) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppToast.warning(
        context,
        'Completa correo y contraseña.',
      );
      return;
    }

    final success = await loginViewModel.login(
      email,
      password,
      rememberMe: _recuerdame,
    );

    if (!mounted) return;

    if (!success) {
      _showLoginFeedback(
        loginViewModel.errorMessage ?? 'No se pudo iniciar sesión.',
      );
      return;
    }

    final currentUser = loginViewModel.currentUser;
    if (currentUser == null) {
      AppToast.error(context, 'No se pudo obtener el usuario autenticado.');
      return;
    }

    if (currentUser.mustChangePassword) {
      final changed = await _enforcePasswordChange(
        token: currentUser.token ?? '',
        currentPassword: _passwordController.text,
      );
      if (!mounted || !changed) return;

      await context.read<SessionViewModel>().updateUser(
        currentUser.copyWith(mustChangePassword: false),
      );

      if (!mounted) return;
    }

    _openShellForRole(currentUser.role);
  }

  @override
  Widget build(BuildContext context) {
    final loginViewModel = context.watch<LoginViewModel>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: NavalgoColors.foam,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BrandMark(),
                  const SizedBox(height: 32),
                  Text(
                    'Acceso a NavalGO',
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => loginViewModel.isLoading
                        ? null
                        : _submit(loginViewModel),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _recuerdame = !_recuerdame),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _recuerdame,
                            onChanged: (v) =>
                                setState(() => _recuerdame = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              'Mantener sesión iniciada',
                              style: textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: loginViewModel.isLoading
                        ? null
                        : () => _submit(loginViewModel),
                    child: loginViewModel.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Iniciar sesión'),
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

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: NavalgoColors.heroGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: NavalgoColors.deepSea.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Icon(Icons.navigation, color: Colors.white, size: 32),
      ),
    );
  }
}
