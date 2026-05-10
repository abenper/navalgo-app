import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/network/api_exception.dart';
import '../../theme/navalgo_theme.dart';
import '../../widgets/navalgo_logo.dart';
import 'login_screen.dart';

const String resetPasswordQueryKey = 'screen';
const String resetPasswordQueryValue = 'reset-password';

bool isResetPasswordEntryUri(Uri uri) {
  final screen = uri.queryParameters[resetPasswordQueryKey];
  return screen == resetPasswordQueryValue;
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  PasswordResetInfo? _info;
  bool _loading = true;
  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await context.read<AuthService>().getPasswordResetStatus(
        widget.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _describeError(error);
      });
    }
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final validation = _validate(password, confirm);
    if (validation != null) {
      setState(() {
        _error = validation;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().completePasswordReset(
        token: widget.token,
        password: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _done = true;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = _describeError(error);
      });
    }
  }

  String? _validate(String password, String confirm) {
    if (password.length < 12 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'La contrasena debe tener 12 caracteres e incluir mayusculas, minusculas, numeros y simbolos.';
    }
    if (password != confirm) {
      return 'Las contrasenas no coinciden.';
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
        : 'No se pudo cambiar la contrasena.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavalgoColors.foam,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: NavalgoLogo(
                          variant: NavalgoLogoVariant.colorBadge,
                          width: 96,
                          height: 96,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _done ? 'Contrasena actualizada' : 'Nueva contrasena',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error != null && _info == null && !_done)
                        Text(_error!, textAlign: TextAlign.center)
                      else if (_done)
                        Text(
                          'Tu contrasena ya ha sido actualizada. Ya puedes iniciar sesion.',
                          textAlign: TextAlign.center,
                        )
                      else ...[
                        Text(_info?.email ?? '', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contrasena',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          onSubmitted: (_) => _submitting ? null : _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contrasena',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Guardar contrasena'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (_) => false,
                          );
                        },
                        child: const Text('Ir al login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
