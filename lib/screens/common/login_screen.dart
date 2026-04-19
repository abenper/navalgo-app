import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/network/api_exception.dart';
import 'package:navalgo/theme/navalgo_theme.dart';
import 'package:navalgo/utils/app_toast.dart';
import 'package:navalgo/viewmodels/login_view_model.dart';
import 'package:navalgo/viewmodels/session_view_model.dart';
import 'package:navalgo/widgets/navalgo_ui.dart';

import '../admin/admin_shell_screen.dart';
import '../worker/worker_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Controladores: Estas variables "escuchan" lo que el usuario escribe.
  // Los usaremos más adelante para enviar el usuario y contraseña a tu API en SpringBoot.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _recuerdame = false; // Se mantiene para la funcionalidad de "Recuérdame"
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

    // If session was restored via remember-me, skip the login form
    // and navigate directly to the appropriate shell screen.
    if (session.isAuthenticated && session.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openShellForRole(session.user!.role);
        }
      });
    }
  }

  // Es buena práctica "destruir" los controladores cuando la pantalla se cierra para liberar memoria.
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
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

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
                  title: const Text('Cambio obligatorio de contraseña'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tu cuenta requiere una nueva contraseña antes de continuar.',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Usa al menos 12 caracteres con mayúsculas, minúsculas, números y un símbolo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: newPasswordController,
                          obscureText: true,
                          enabled: !isSaving,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
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
                          : const Text('Guardar y continuar'),
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

  Widget _buildFeatureChip(IconData icon, String label) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: NavalgoColors.sand),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcasePanel(BuildContext context, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavalgoPageIntro(
          eyebrow: 'GESTIÓN OPERATIVA NAVAL',
          stackTrailingBreakpoint: 560,
          title:
              'Coordina partes, personal y actividad diaria desde una sola plataforma.',
          subtitle:
              'Accede a la operativa de taller y administración con un entorno preparado para registrar trabajos, controlar jornadas y gestionar ausencias.',
          footer: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFeatureChip(
                Icons.assignment_turned_in,
                'Partes con firma y evidencias',
              ),
              _buildFeatureChip(
                Icons.access_time_rounded,
                'Control horario y ausencias',
              ),
              _buildFeatureChip(Icons.radar, 'Flota y equipo actualizados'),
            ],
          ),
          trailing: compact
              ? null
              : SizedBox(
                  width: 260,
                  child: Column(
                    children: const [
                      _LoginMetricCard(
                        label: 'Acceso',
                        value: 'Unificado',
                        note:
                            'Partes, equipo, fichajes y ausencias desde una única sesión.',
                      ),
                      SizedBox(height: 12),
                      _LoginMetricCard(
                        label: 'Seguimiento',
                        value: 'Diario',
                        note:
                            'Consulta actividad pendiente y estado operativo en el mismo entorno.',
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 18),
        NavalgoPanel(
          tint: Colors.white.withValues(alpha: 0.78),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackItems = constraints.maxWidth < 520;
              if (stackItems) {
                return const Column(
                  children: [
                    _BrandPromise(
                      icon: Icons.anchor,
                      title: 'Registro centralizado',
                      description:
                          'La actividad diaria queda reunida en un único acceso para administración y taller.',
                    ),
                    SizedBox(height: 16),
                    _BrandPromise(
                      icon: Icons.waves,
                      title: 'Consulta rápida',
                      description:
                          'Localiza la información relevante sin cambiar entre pantallas y herramientas.',
                    ),
                  ],
                );
              }

              return const Row(
                children: [
                  Expanded(
                    child: _BrandPromise(
                      icon: Icons.anchor,
                      title: 'Registro centralizado',
                      description:
                          'La actividad diaria queda reunida en un único acceso para administración y taller.',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _BrandPromise(
                      icon: Icons.waves,
                      title: 'Consulta rápida',
                      description:
                          'Localiza la información relevante sin cambiar entre pantallas y herramientas.',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthPanel(BuildContext context, LoginViewModel loginViewModel) {
    final textTheme = Theme.of(context).textTheme;
    return NavalgoPanel(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: NavalgoColors.heroGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.navigation, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            'Acceso a NavalGO',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Introduce tus credenciales para continuar con la operativa diaria.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
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
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _recuerdame,
                onChanged: (bool? newValue) {
                  setState(() {
                    _recuerdame = newValue ?? false;
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Mantener sesión iniciada en este equipo',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loginViewModel.isLoading
                  ? null
                  : () async {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text;

                      if (email.isEmpty || password.isEmpty) {
                        AppToast.warning(
                          context,
                          'Completa correo y contraseña antes de iniciar sesión.',
                        );
                        return;
                      }

                      final success = await loginViewModel.login(
                        email,
                        password,
                        rememberMe: _recuerdame,
                      );

                      if (!context.mounted) {
                        return;
                      }

                      if (success) {
                        final currentUser = loginViewModel.currentUser;
                        if (currentUser == null) {
                          AppToast.error(
                            context,
                            'No se pudo obtener el usuario autenticado',
                          );
                          return;
                        }

                        if (currentUser.mustChangePassword) {
                          final changed = await _enforcePasswordChange(
                            token: currentUser.token ?? '',
                            currentPassword: _passwordController.text,
                          );
                          if (!context.mounted || !changed) {
                            return;
                          }

                          await context.read<SessionViewModel>().updateUser(
                            currentUser.copyWith(mustChangePassword: false),
                          );

                          if (!context.mounted) {
                            return;
                          }
                        }

                        _openShellForRole(currentUser.role);
                      } else {
                        _showLoginFeedback(
                          loginViewModel.errorMessage ??
                              'No se pudo iniciar sesión.',
                        );
                      }
                    },
              icon: loginViewModel.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                loginViewModel.isLoading
                    ? 'Verificando acceso...'
                    : 'Iniciar sesión',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NavalgoColors.foam,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NavalgoColors.sand.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: NavalgoColors.deepSea,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Acceso seguro para personal autorizado de administración y operativa.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loginViewModel = context.watch<LoginViewModel>();

    return Scaffold(
      body: NavalgoPageBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 940;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: compact
                        ? Column(
                            children: [
                              _buildShowcasePanel(context, compact: true),
                              const SizedBox(height: 24),
                              _buildAuthPanel(context, loginViewModel),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 11,
                                child: _buildShowcasePanel(
                                  context,
                                  compact: false,
                                ),
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 9,
                                child: _buildAuthPanel(context, loginViewModel),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandPromise extends StatelessWidget {
  const _BrandPromise({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: NavalgoColors.mist,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: NavalgoColors.harbor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginMetricCard extends StatelessWidget {
  const _LoginMetricCard({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: NavalgoColors.sand),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
