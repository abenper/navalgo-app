import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/network/api_exception.dart';
import '../../theme/navalgo_theme.dart';
import '../../widgets/navalgo_logo.dart';
import 'privacy_policy_screen.dart';

const String createAccountQueryKey = 'screen';
const String createAccountQueryValue = 'create-account';

bool isCreateAccountEntryUri(Uri uri) {
  final screen = uri.queryParameters[createAccountQueryKey];
  return screen == createAccountQueryValue;
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({
    super.key,
    this.prefilledName,
    this.prefilledEmail,
  });

  final String? prefilledName;
  final String? prefilledEmail;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vesselNameCtrl = TextEditingController();
  final _vesselRegistrationCtrl = TextEditingController();
  final _vesselModelCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _acceptedPrivacy = false;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.prefilledName ?? '';
    _emailCtrl.text = widget.prefilledEmail ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _vesselNameCtrl.dispose();
    _vesselRegistrationCtrl.dispose();
    _vesselModelCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final vesselName = _vesselNameCtrl.text.trim();
    final vesselRegistration = _vesselRegistrationCtrl.text.trim();
    final vesselModel = _vesselModelCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    final validation = _validate(
      name,
      email,
      vesselName,
      vesselRegistration,
      password,
      confirm,
    );
    if (validation != null) {
      setState(() {
        _error = validation;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().signupClient(
        fullName: name,
        email: email,
        password: password,
        phone: phone.isEmpty ? null : phone,
        vesselName: vesselName,
        vesselRegistrationNumber: vesselRegistration,
        vesselModel: vesselModel.isEmpty ? null : vesselModel,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _done = true;
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

  String? _validate(
    String name,
    String email,
    String vesselName,
    String vesselRegistration,
    String password,
    String confirm,
  ) {
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      return 'Completa los campos obligatorios.';
    }
    if (!email.contains('@')) {
      return 'Introduce un correo electrónico válido.';
    }
    if (vesselName.isEmpty || vesselRegistration.isEmpty) {
      return 'Indica el nombre y la matrícula de la embarcación.';
    }
    if (password.length < 12 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'La contraseña debe tener 12 caracteres e incluir mayúsculas, minúsculas, números y símbolos.';
    }
    if (password != confirm) {
      return 'Las contraseñas no coinciden.';
    }
    if (!_acceptedPrivacy) {
      return 'Debes aceptar la política de privacidad para crear la cuenta.';
    }
    return null;
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.serverMessage ?? error.message;
    }
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : 'No se pudo crear la cuenta.';
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
              constraints: const BoxConstraints(maxWidth: 440),
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
                        _done ? 'Revisa tu correo' : 'Crear cuenta',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_done)
                        const Text(
                          'Te hemos enviado un correo para confirmar tu dirección email. Hasta que no lo confirmes no podrás iniciar sesión.',
                          textAlign: TextAlign.center,
                        )
                      else ...[
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vesselNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la embarcación',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vesselRegistrationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Matrícula de la embarcación',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vesselModelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Modelo de la embarcación',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          onSubmitted: (_) => _loading ? null : _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                          ),
                        ),
                        const SizedBox(height: 14),
                        CheckboxListTile(
                          value: _acceptedPrivacy,
                          onChanged: _loading
                              ? null
                              : (value) {
                                  setState(() {
                                    _acceptedPrivacy = value ?? false;
                                  });
                                },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'He leído y acepto la política de privacidad',
                          ),
                          subtitle: TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PrivacyPolicyScreen(
                                              initialAudience:
                                                  PrivacyAudience.client,
                                            ),
                                      ),
                                    );
                                  },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Consultar política de privacidad',
                            ),
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
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Crear cuenta'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          _done ? 'Volver al login' : 'Ya tengo cuenta',
                        ),
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
