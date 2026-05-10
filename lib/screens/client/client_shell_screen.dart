import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_logo.dart';
import '../admin/admin_shell_screen.dart';
import '../commercial/commercial_shell_screen.dart';
import '../common/login_screen.dart';
import '../worker/worker_shell_screen.dart';
import 'client_budgets_screen.dart';
import 'client_dashboard_screen.dart';
import 'client_vessels_screen.dart';

class ClientShellScreen extends StatefulWidget {
  const ClientShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen> {
  late int _selectedIndex;
  final Set<int> _loadedIndices = <int>{0};

  static const _titles = ['Inicio', 'Flota', 'Presupuestos'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.directions_boat_outlined,
    Icons.request_quote_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _titles.length - 1);
    _loadedIndices.add(_selectedIndex);
  }

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

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
      _loadedIndices.add(index);
    });
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NavalgoColors.border),
                    ),
                    child: const NavalgoLogo(
                      variant: NavalgoLogoVariant.colorBadge,
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Área cliente',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                itemCount: _titles.length,
                itemBuilder: (context, index) {
                  final selected = index == _selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: Icon(
                        _icons[index],
                        color: selected ? NavalgoColors.tide : null,
                      ),
                      title: Text(_titles[index]),
                      selected: selected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      selectedTileColor: NavalgoColors.mist,
                      onTap: () {
                        Navigator.of(context).pop();
                        _selectTab(index);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Cerrar sesión'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoadedScreens(List<Widget> screens) {
    return List<Widget>.generate(screens.length, (index) {
      if (_loadedIndices.contains(index)) {
        return screens[index];
      }
      return const SizedBox.shrink();
    });
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
      ClientDashboardScreen(
        onOpenBudgets: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedIndex = 2;
          });
        },
      ),
      const ClientVesselsScreen(),
      const ClientBudgetsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final showSectionBadge = constraints.maxWidth >= 360;
        final useRail = constraints.maxWidth >= 960;
        final loadedScreens = _buildLoadedScreens(screens);

        return Scaffold(
          drawer: useRail ? null : _buildMobileDrawer(),
          appBar: AppBar(
            toolbarHeight: compact ? 64 : 72,
            titleSpacing: compact ? 8 : 14,
            title: Row(
              children: [
                if (showSectionBadge) ...[
                  Container(
                    width: compact ? 40 : 42,
                    height: compact ? 40 : 42,
                    decoration: BoxDecoration(
                      color: NavalgoColors.mist,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _icons[_selectedIndex],
                      color: NavalgoColors.tide,
                      size: compact ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                ],
                Expanded(
                  child: Text(
                    _titles[_selectedIndex],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            decoration: const BoxDecoration(
              gradient: NavalgoColors.pageGradient,
            ),
            child: useRail
                ? Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: NavalgoColors.railGradient,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: NavalgoColors.border),
                          ),
                          child: SizedBox(
                            width: 128,
                            child: NavigationRail(
                              selectedIndex: _selectedIndex,
                              onDestinationSelected: _selectTab,
                              labelType: NavigationRailLabelType.all,
                              minWidth: 128,
                              destinations: const [
                                NavigationRailDestination(
                                  icon: Icon(Icons.dashboard_outlined),
                                  selectedIcon: Icon(Icons.dashboard),
                                  label: Text('Inicio'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.directions_boat_outlined),
                                  selectedIcon: Icon(Icons.directions_boat),
                                  label: Text('Flota'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.request_quote_outlined),
                                  selectedIcon: Icon(Icons.request_quote),
                                  label: Text('Presupuestos'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: loadedScreens,
                        ),
                      ),
                    ],
                  )
                : IndexedStack(index: _selectedIndex, children: loadedScreens),
          ),
        );
      },
    );
  }
}
