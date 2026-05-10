import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/network/api_exception.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../common/login_screen.dart';
import '../common/privacy_policy_screen.dart';

class ClientAccountScreen extends StatefulWidget {
  const ClientAccountScreen({super.key});

  @override
  State<ClientAccountScreen> createState() => _ClientAccountScreenState();
}

class _ClientAccountScreenState extends State<ClientAccountScreen> {
  bool _deleting = false;
  String? _deleteError;

  Future<void> _openLegal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const PrivacyPolicyScreen(initialAudience: PrivacyAudience.client),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: const Text(
            'Tu acceso al area cliente se desactivara. Las embarcaciones, presupuestos y trazas necesarias para la operativa o para obligaciones legales pueden mantenerse archivados. Esta accion no se puede deshacer desde la app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NavalgoColors.alert,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar cuenta'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final session = context.read<SessionViewModel>();
    final token = session.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _deleteError = 'No se ha podido validar tu sesion.';
      });
      return;
    }

    setState(() {
      _deleting = true;
      _deleteError = null;
    });

    try {
      await context.read<AuthService>().deleteClientAccount(token: token);
      await session.clearSession();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deleting = false;
        _deleteError = _describeError(error);
      });
    }
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.userMessage;
    }
    final text = error.toString();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : 'No se ha podido eliminar la cuenta.';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final user = session.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: NavalgoColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'TU CUENTA CLIENTE',
                    style: textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user == null ? 'Gestiona tu cuenta' : 'Gestiona tu cuenta y tu acceso',
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Desde aqui puedes revisar la documentacion legal de Naval-GO y, si lo necesitas, solicitar la baja de tu cuenta desde la propia app.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de cuenta',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _AccountRow(
                    label: 'Nombre',
                    value: user?.name ?? 'No disponible',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _AccountRow(
                    label: 'Correo',
                    value: user?.email ?? 'No disponible',
                    icon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 12),
                  _AccountRow(
                    label: 'Rol',
                    value: 'Cliente',
                    icon: Icons.badge_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacidad y condiciones',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Consulta en cualquier momento el detalle de tratamiento de datos y las reglas de uso del area cliente.',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openLegal,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Abrir documentacion legal'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFFFF5F1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zona sensible',
                    style: textTheme.titleLarge?.copyWith(
                      color: NavalgoColors.alert,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si eliminas tu cuenta, el acceso se desactivara inmediatamente. La informacion necesaria para historial, presupuestos, trazabilidad o cumplimiento puede mantenerse archivada, pero dejara de estar operativa para ti.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: NavalgoColors.deepSea,
                    ),
                  ),
                  if (_deleteError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _deleteError!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: NavalgoColors.alert,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _deleting ? null : _deleteAccount,
                    style: FilledButton.styleFrom(
                      backgroundColor: NavalgoColors.alert,
                    ),
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(
                      _deleting ? 'Eliminando cuenta...' : 'Eliminar cuenta',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: NavalgoColors.mist,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: NavalgoColors.tide),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NavalgoColors.storm,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
