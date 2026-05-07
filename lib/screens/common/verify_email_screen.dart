import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/network/api_exception.dart';
import '../../theme/navalgo_theme.dart';
import '../../widgets/navalgo_logo.dart';
import 'login_screen.dart';

const String verifyEmailQueryKey = 'screen';
const String verifyEmailQueryValue = 'verify-email';

bool isVerifyEmailEntryUri(Uri uri) {
  final screen = uri.queryParameters[verifyEmailQueryKey];
  return screen == verifyEmailQueryValue;
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String token;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  EmailVerificationInfo? _info;
  bool _loading = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await context.read<AuthService>().getEmailVerificationStatus(
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

  Future<void> _confirm() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().confirmEmailVerification(
        token: widget.token,
      );
      if (!mounted) {
        return;
      }
      await _loadStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _verifying = false;
        _error = _describeError(error);
      });
    }
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.serverMessage ?? error.message;
    }
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : 'No se pudo confirmar el correo.';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _info?.alreadyVerified == true) {
      return EmailVerificationSuccessScreen(email: _info?.email ?? '');
    }

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
                        'Confirmar cuenta',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error != null)
                        Text(_error!, textAlign: TextAlign.center)
                      else ...[
                        Text(
                          _info?.fullName ?? '',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _info?.email ?? '',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _verifying ? null : _confirm,
                          child: _verifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Confirmar correo'),
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

class EmailVerificationSuccessScreen extends StatelessWidget {
  const EmailVerificationSuccessScreen({super.key, required this.email});

  final String email;

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
                        'Cuenta confirmada correctamente',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        email.isEmpty
                            ? 'Tu cuenta ya está activa. Ya puedes iniciar sesión.'
                            : 'La cuenta $email ya está activa. Ya puedes iniciar sesión.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
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
