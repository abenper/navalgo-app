import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/worker_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../utils/media_url.dart';
import '../../viewmodels/notifications_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_logo.dart';
import '../../widgets/profile_dialogs.dart';
import '../admin/flota_screen.dart';
import '../admin/admin_shell_screen.dart';
import '../common/login_screen.dart';
import '../common/privacy_policy_screen.dart';
import '../worker/fichaje_screen.dart';
import '../worker/vacaciones_screen.dart';
import '../worker/worker_dashboard_screen.dart';
import '../worker/worker_shell_screen.dart';

class CommercialShellScreen extends StatefulWidget {
  const CommercialShellScreen({super.key});

  @override
  State<CommercialShellScreen> createState() => _CommercialShellScreenState();
}

class _CommercialShellScreenState extends State<CommercialShellScreen> {
  int _selectedIndex = 0;
  bool _shownUnreadToast = false;
  final Set<int> _loadedIndices = <int>{0};

  final List<Widget> _screens = const [
    WorkerDashboardScreen(),
    FlotaScreen(),
    FichajeScreen(),
    AusenciasScreen(),
  ];

  final List<String> _titles = const [
    'Inicio',
    'Flota',
    'Fichaje',
    'Ausencias',
  ];

  final List<IconData> _sectionIcons = const [
    Icons.dashboard_outlined,
    Icons.directions_boat_outlined,
    Icons.access_time_outlined,
    Icons.event_note_outlined,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshCurrentUserProfile();
      if (!mounted) {
        return;
      }
      final notificationsVm = context.read<NotificationsViewModel>();
      await notificationsVm.refresh();
      if (!mounted || _shownUnreadToast) {
        return;
      }
      if (notificationsVm.unreadCount > 0) {
        _shownUnreadToast = true;
        AppToast.info(
          context,
          'Tienes ${notificationsVm.unreadCount} notificaciÃ³n(es) nuevas.',
        );
      }
    });
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

    if (role == 'WORKER') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkerShellScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _refreshCurrentUserProfile() async {
    final session = context.read<SessionViewModel>();
    final currentUser = session.user;
    final token = session.token;
    if (currentUser == null || token == null || token.isEmpty) {
      return;
    }

    try {
      final profile = await context.read<WorkerService>().getMyProfile(token);
      if (!mounted) {
        return;
      }
      await session.updateUser(
        currentUser.copyWith(
          name: profile.fullName,
          email: profile.email,
          role: profile.role,
          mustChangePassword: profile.mustChangePassword,
          canEditWorkOrders: profile.canEditWorkOrders,
          photoUrl: profile.photoUrl,
        ),
      );
      _redirectForRole(profile.role);
    } catch (_) {}
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
      case 'FICHAJES':
        return 2;
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
                        Text(
                          'Notificaciones',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: notificationsVm.unreadCount == 0
                              ? null
                              : () async {
                                  await notificationsVm.markAllAsRead();
                                },
                          child: const Text('Marcar todas como leÃ­das'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: notifications.isEmpty
                          ? Center(
                              child: Text(
                                'No tienes notificaciones',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                    child: Row(
                      children: [
                        _buildAvatarWidget(
                          user.photoUrl,
                          radius: 26,
                          iconSize: 24,
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
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildAccountAction(
                    context: sheetContext,
                    value: 'profile',
                    icon: Icons.person_outline_rounded,
                    title: 'Mi perfil',
                  ),
                  const SizedBox(height: 8),
                  _buildAccountAction(
                    context: sheetContext,
                    value: 'password',
                    icon: Icons.lock_outline_rounded,
                    title: 'Cambiar contraseÃ±a',
                  ),
                  const SizedBox(height: 8),
                  _buildAccountAction(
                    context: sheetContext,
                    value: 'privacy',
                    icon: Icons.privacy_tip_outlined,
                    title: 'PolÃ­tica de Privacidad',
                  ),
                  const SizedBox(height: 8),
                  _buildAccountAction(
                    context: sheetContext,
                    value: 'logout',
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesiÃ³n',
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
      await showProfileEditorDialog(context);
      return;
    }

    if (action == 'password') {
      await showChangePasswordFormDialog(context);
      return;
    }

    if (action == 'privacy') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
      return;
    }

    final session = context.read<SessionViewModel>();
    try {
      await context.read<AuthService>().logout(token: session.token);
    } catch (_) {}
    await session.clearSession();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  AppBar _buildAppBar(BuildContext context) {
    final unreadCount = context.select<NotificationsViewModel, int>(
      (vm) => vm.unreadCount,
    );
    final userName = context.select<SessionViewModel, String>(
      (session) => session.user?.name ?? 'Comercial',
    );
    final photoUrl = context.select<SessionViewModel, String?>(
      (session) => session.user?.photoUrl,
    );
    final width = MediaQuery.of(context).size.width;
    final showName = width >= 1080;

    return AppBar(
      toolbarHeight: 72,
      titleSpacing: 14,
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NavalgoColors.mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _sectionIcons[_selectedIndex],
              color: NavalgoColors.tide,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _titles[_selectedIndex],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
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
                    height: 48,
                    padding: EdgeInsets.symmetric(
                      horizontal: showName ? 10 : 6,
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
            width: 48,
            height: 48,
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

  Widget _buildAccountAction({
    required BuildContext context,
    required String value,
    required IconData icon,
    required String title,
    Color accent = NavalgoColors.tide,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NavalgoColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: NavalgoColors.storm,
              ),
            ],
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

  Widget _buildAvatarWidget(
    String? photoUrl, {
    double radius = 16,
    double iconSize = 18,
  }) {
    final resolvedPhotoUrl = resolveMediaUrl(photoUrl);
    final token = context.read<SessionViewModel>().token;
    if (resolvedPhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: NavalgoColors.mist,
        foregroundImage: NetworkImage(
          resolvedPhotoUrl,
          headers: buildMediaHeaders(token),
        ),
        child: Icon(Icons.person, size: iconSize, color: NavalgoColors.tide),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: NavalgoColors.mist,
      child: Icon(Icons.person, size: iconSize, color: NavalgoColors.tide),
    );
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
    final currentRole = context.select<SessionViewModel, String?>(
      (session) => session.user?.role,
    );
    if (currentRole == 'ADMIN' || currentRole == 'WORKER') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentRole != null) {
          _redirectForRole(currentRole);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final wideLayout = MediaQuery.of(context).size.width >= 600;

    if (wideLayout) {
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
                    scrollable: true,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 18),
                      child: Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: NavalgoColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: NavalgoColors.deepSea.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const NavalgoLogo(
                          variant: NavalgoLogoVariant.colorBadge,
                          width: 40,
                          height: 40,
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
                        icon: Icon(Icons.directions_boat_outlined),
                        selectedIcon: Icon(Icons.directions_boat),
                        label: Text('Flota'),
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
                icon: Icon(Icons.directions_boat_outlined),
                selectedIcon: Icon(Icons.directions_boat),
                label: 'Flota',
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
  }
}
