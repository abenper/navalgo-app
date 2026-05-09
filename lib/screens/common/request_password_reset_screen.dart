import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/network/api_exception.dart';
import '../../theme/navalgo_theme.dart';

class RequestPasswordResetScreen extends StatefulWidget {
  const RequestPasswordResetScreen({super.key});

  @override
  State<RequestPasswordResetScreen> createState() =>
      _RequestPasswordResetScreenState();
}

class _RequestPasswordResetScreenState
    extends State<RequestPasswordResetScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Introduce un correo electrónico válido.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().requestPasswordReset(email: email);
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

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.serverMessage ?? error.message;
    }
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : 'No se pudo procesar la solicitud.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavalgoColors.foam,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: NavalgoColors.pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 480;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 24,
                    vertical: compact ? 20 : 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _RecoveryCard(
                      compact: compact,
                      done: _done,
                      loading: _loading,
                      error: _error,
                      emailController: _emailCtrl,
                      onSubmit: _submit,
                      onBack: () => Navigator.of(context).pop(),
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

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.compact,
    required this.done,
    required this.loading,
    required this.error,
    required this.emailController,
    required this.onSubmit,
    required this.onBack,
  });

  final bool compact;
  final bool done;
  final bool loading;
  final String? error;
  final TextEditingController emailController;
  final Future<void> Function() onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              done ? 'Revisa tu correo' : 'Recupera tu contraseña',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              done
                  ? 'Si existe una cuenta con ese correo, ya hemos preparado el enlace de recuperación.'
                  : 'Introduce tu correo y te enviaremos instrucciones para restablecer el acceso.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: NavalgoColors.storm),
            ),
            const SizedBox(height: 22),
            if (done) ...[
              _SuccessPanel(email: emailController.text.trim()),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver al login'),
              ),
            ] else ...[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => loading ? null : onSubmit(),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'tu@empresa.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 14),
              _InfoPanel(compact: compact),
              if (error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NavalgoColors.coral.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: NavalgoColors.coral.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: NavalgoColors.coral,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: NavalgoColors.alert,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: loading ? null : onSubmit,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.mark_email_read_outlined),
                label: Text(loading ? 'Enviando enlace...' : 'Enviar enlace'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver al login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: NavalgoColors.mist.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: NavalgoColors.tide,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cómo funciona',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _InfoStep(
            icon: Icons.looks_one_rounded,
            text: 'Escribe el correo asociado a tu cuenta.',
          ),
          const SizedBox(height: 10),
          const _InfoStep(
            icon: Icons.looks_two_rounded,
            text: 'Te enviaremos un enlace temporal y seguro.',
          ),
          const SizedBox(height: 10),
          const _InfoStep(
            icon: Icons.looks_3_rounded,
            text: 'Crea una nueva contraseña desde tu email.',
          ),
        ],
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: NavalgoColors.harbor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NavalgoColors.deepSea),
          ),
        ),
      ],
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NavalgoColors.kelp.withValues(alpha: 0.12),
            NavalgoColors.foam,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NavalgoColors.kelp.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: NavalgoColors.kelp,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Comprueba tu bandeja de entrada',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: NavalgoColors.deepSea),
          ),
          const SizedBox(height: 8),
          Text(
            email.isEmpty
                ? 'Si el correo existe en NavalGO, recibirás un enlace para restablecer tu contraseña.'
                : 'Si $email pertenece a una cuenta válida, recibirás un enlace para restablecer tu contraseña.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          const _InfoStep(
            icon: Icons.schedule_rounded,
            text: 'El enlace caduca, así que conviene usarlo cuanto antes.',
          ),
          const SizedBox(height: 10),
          const _InfoStep(
            icon: Icons.forward_to_inbox_outlined,
            text: 'Si no lo ves, revisa spam o promociones.',
          ),
        ],
      ),
    );
  }
}
