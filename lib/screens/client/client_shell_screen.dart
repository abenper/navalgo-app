import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../admin/admin_shell_screen.dart';
import '../commercial/commercial_shell_screen.dart';
import '../common/login_screen.dart';
import '../worker/worker_shell_screen.dart';

class ClientShellScreen extends StatefulWidget {
  const ClientShellScreen({super.key});

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen> {
  int _selectedIndex = 0;

  static const _titles = ['Inicio', 'Flota', 'Presupuestos'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.directions_boat_outlined,
    Icons.request_quote_outlined,
  ];

  void _redirectForRole(String role) {
    if (!mounted) {
      return;
    }
    if (role == 'ADMIN') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminShellScreen()),
        (route) => false,
      );
      return;
    }
    if (role == 'COMERCIAL') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CommercialShellScreen()),
        (route) => false,
      );
      return;
    }
    if (role == 'WORKER') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkerShellScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _logout() async {
    final session = context.read<SessionViewModel>();
    try {
      await context.read<AuthService>().logout(token: session.token);
    } catch (_) {}
    await session.clearSession();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<SessionViewModel, String?>(
      (session) => session.user?.role,
    );
    if (role != 'CLIENT') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (role != null) {
          _redirectForRole(role);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      const _ClientPlaceholderScreen(
        title: 'Bienvenido a tu portal',
        body:
            'Desde aqui podras revisar el estado de tus embarcaciones, presupuestos y documentacion cuando terminemos de conectar el area de cliente.',
        icon: Icons.dashboard_customize_outlined,
      ),
      const _ClientPlaceholderScreen(
        title: 'Flota del cliente',
        body:
            'Aqui apareceran las embarcaciones asociadas a tu cuenta para poder consultar sus trabajos y documentacion.',
        icon: Icons.directions_boat_filled_outlined,
      ),
      const _ClientPlaceholderScreen(
        title: 'Presupuestos',
        body:
            'En esta seccion podras aceptar o rechazar presupuestos y dejar observaciones al astillero.',
        icon: Icons.request_quote,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NavalgoColors.mist,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icons[_selectedIndex], color: NavalgoColors.tide),
            ),
            const SizedBox(width: 12),
            Text(_titles[_selectedIndex]),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: NavalgoColors.pageGradient),
        child: screens[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_boat_outlined),
            selectedIcon: Icon(Icons.directions_boat),
            label: 'Flota',
          ),
          NavigationDestination(
            icon: Icon(Icons.request_quote_outlined),
            selectedIcon: Icon(Icons.request_quote),
            label: 'Presupuestos',
          ),
        ],
      ),
    );
  }
}

class _ClientPlaceholderScreen extends StatelessWidget {
  const _ClientPlaceholderScreen({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: NavalgoColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: NavalgoColors.tide.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: NavalgoColors.tide, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: NavalgoColors.deepSea,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
