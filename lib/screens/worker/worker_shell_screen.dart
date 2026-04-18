import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../utils/media_url.dart';
import '../../viewmodels/notifications_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/profile_dialogs.dart';
import '../admin/partes_screen.dart';
import '../common/login_screen.dart';
import 'fichaje_screen.dart';
import 'vacaciones_screen.dart';
import 'worker_dashboard_screen.dart';

class WorkerShellScreen extends StatefulWidget {
  const WorkerShellScreen({super.key});

  @override
  State<WorkerShellScreen> createState() => _WorkerShellScreenState();
}

class _WorkerShellScreenState extends State<WorkerShellScreen> {
  int _selectedIndex = 0;
  bool _shownUnreadToast = false;
  final Set<int> _loadedIndices = <int>{0};

  final List<Widget> _screens = const [
    WorkerDashboardScreen(),
    PartesScreen(),
    FichajeScreen(),
    AusenciasScreen(),
  ];

  final List<String> _titles = const [
    'Mi resumen',
    'Mis partes',
    'Control horario',
    'Mis ausencias',
  ];

  final List<String> _subtitles = const [
    'Tareas activas, jornada y estado del día.',
    'Seguimiento de trabajos, firmas y evidencias.',
    'Entradas, salidas y horas acumuladas.',
    'Solicitudes, saldo y respuesta de cada ausencia.',
  ];

  final List<IconData> _sectionIcons = const [
    Icons.dashboard_outlined,
    Icons.assignment_outlined,
    Icons.access_time_outlined,
    Icons.event_note_outlined,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notificationsVm = context.read<NotificationsViewModel>();
      await notificationsVm.refresh();
      if (!mounted || _shownUnreadToast) {
        return;
      }
      if (notificationsVm.unreadCount > 0) {
        _shownUnreadToast = true;
        AppToast.info(
          context,
          'Tienes ${notificationsVm.unreadCount} notificación(es) nuevas.',
        );
      }
    });
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
      _loadedIndices.add(index);
    });
  }

  int _mapActionRouteToTab(String actionRoute) {
    switch (actionRoute) {
      case 'PARTES':
        return 1;
      case 'AUSENCIAS':
        return 3;
      default:
        return 0;
    }
  }

  Future<void> _openNotifications() async {
    final vm = context.read<NotificationsViewModel>();
    await vm.refresh();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Consumer<NotificationsViewModel>(
          builder: (context, notificationsVm, _) {
            final notifications = notificationsVm.notifications;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Notificaciones',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: notificationsVm.unreadCount == 0
                              ? null
                              : () async {
                                  await notificationsVm.markAllAsRead();
                                },
                          child: const Text('Marcar todas como leídas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: notifications.isEmpty
                          ? const Center(
                              child: Text('No tienes notificaciones'),
                            )
                          : ListView.builder(
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final item = notifications[index];
                                return Card(
                                  color: item.isRead
                                      ? null
                                      : NavalgoColors.mist,
                                  child: ListTile(
                                    leading: Icon(
                                      item.isRead
                                          ? Icons.notifications_none
                                          : Icons.notifications_active,
                                      color: item.isRead
                                          ? Colors.grey
                                          : NavalgoColors.tide,
                                    ),
                                    title: Text(item.title),
                                    subtitle: Text(item.message),
                                    trailing: item.isRead
                                        ? null
                                        : const Icon(
                                            Icons.fiber_manual_record,
                                            size: 12,
                                            color: NavalgoColors.coral,
                                          ),
                                    onTap: () async {
                                      await notificationsVm.markAsRead(item.id);
                                      if (!mounted) {
                                        return;
                                      }
                                      Navigator.of(this.context).pop();
                                      setState(() {
                                        _selectedIndex = _mapActionRouteToTab(
                                          item.actionRoute,
                                        );
                                        _loadedIndices.add(_selectedIndex);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final unreadCount = context.select<NotificationsViewModel, int>(
      (vm) => vm.unreadCount,
    );
    final userName = context.select<SessionViewModel, String>(
      (session) => session.user?.name ?? 'Trabajador',
    );
    final photoUrl = context.select<SessionViewModel, String?>(
      (session) => session.user?.photoUrl,
    );
    final width = MediaQuery.of(context).size.width;
    final showSubtitle = width >= 760;
    final showName = width >= 1080;

    return AppBar(
      toolbarHeight: showSubtitle ? 86 : 74,
      titleSpacing: 14,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NavalgoColors.mist,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _sectionIcons[_selectedIndex],
              color: NavalgoColors.tide,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _titles[_selectedIndex],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (showSubtitle)
                  Text(
                    _subtitles[_selectedIndex],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Row(
            children: [
              _buildHeaderActionButton(
                tooltip: 'Notificaciones',
                onTap: _openNotifications,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: const BoxDecoration(
                            color: NavalgoColors.coral,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _openAccountMenu,
                  child: Container(
                    height: 46,
                    padding: EdgeInsets.symmetric(
                      horizontal: showName ? 8 : 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: NavalgoColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAvatarWidget(photoUrl),
                        if (showName) ...[
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              _shortDisplayName(userName),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.expand_more_rounded),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NavalgoColors.border),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  String _shortDisplayName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Cuenta';
    }
    return normalized.split(' ').first;
  }

  Future<void> _openAccountMenu() async {
    final user = context.read<SessionViewModel>().user;
    if (user == null) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.9;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: NavalgoColors.heroGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Área personal de NavalGO',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAccountAction(
                    context: sheetContext,
                    value: 'profile',
                    icon: Icons.person_outline_rounded,
                    title: 'Mi perfil',
                    subtitle: 'Consulta tus datos y permisos actuales.',
                  ),
                  const SizedBox(height: 10),
                  _buildAccountAction(
                    context: sheetContext,
                    value: 'password',
                    icon: Icons.lock_outline_rounded,
                    title: 'Cambiar contraseña',
                    subtitle: 'Actualiza tus credenciales de acceso.',
                  ),
                  const SizedBox(height: 10),
                  _buildAccountAction(
                    context: sheetContext,
                    value: 'logout',
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesión',
                    subtitle: 'Salir de NavalGO en este dispositivo.',
                    accent: NavalgoColors.coral,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'profile') {
      await _showProfileDialog();
      return;
    }

    if (action == 'password') {
      await _showChangePasswordDialog();
      return;
    }

    await context.read<SessionViewModel>().clearSession();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Widget _buildAccountAction({
    required BuildContext context,
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    Color accent = NavalgoColors.tide,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).pop(value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(String? photoUrl) {
    final resolvedPhotoUrl = resolveMediaUrl(photoUrl);
    if (resolvedPhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(resolvedPhotoUrl),
        backgroundColor: NavalgoColors.mist,
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: NavalgoColors.mist,
      child: const Icon(Icons.person, size: 20, color: NavalgoColors.tide),
    );
  }

  Future<void> _showProfileDialog() async {
    await showProfileEditorDialog(context);
  }

  Future<void> _showChangePasswordDialog() async {
    await showChangePasswordFormDialog(context);
  }

  List<Widget> _buildLoadedScreens() {
    return List<Widget>.generate(_screens.length, (index) {
      if (_loadedIndices.contains(index)) {
        return _screens[index];
      }
      return const SizedBox.shrink();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: Container(
              decoration: const BoxDecoration(
                gradient: NavalgoColors.pageGradient,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: NavalgoColors.railGradient,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: NavalgoColors.border),
                      ),
                      child: NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onDestinationSelected,
                        labelType: NavigationRailLabelType.all,
                        minWidth: 84,
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 18),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: NavalgoColors.heroGradient,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: Text('Inicio'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.assignment_outlined),
                            selectedIcon: Icon(Icons.assignment),
                            label: Text('Partes'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.access_time_outlined),
                            selectedIcon: Icon(Icons.access_time_filled),
                            label: Text('Fichaje'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.event_note_outlined),
                            selectedIcon: Icon(Icons.event_note),
                            label: Text('Ausencias'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _buildLoadedScreens(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(context),
          body: Container(
            decoration: const BoxDecoration(
              gradient: NavalgoColors.pageGradient,
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: _buildLoadedScreens(),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: const Border(
                  top: BorderSide(color: NavalgoColors.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: NavalgoColors.deepSea.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBar(
                height: 72,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: 'Partes',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.access_time_outlined),
                    selectedIcon: Icon(Icons.access_time_filled),
                    label: 'Fichaje',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: 'Ausencias',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
