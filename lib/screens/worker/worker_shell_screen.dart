import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/notifications_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../admin/partes_screen.dart';
import '../common/login_screen.dart';
import '../../services/worker_photo_service.dart';
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

  final List<Widget> _screens = const [
    WorkerDashboardScreen(),
    PartesScreen(),
    FichajeScreen(),
    AusenciasScreen(),
  ];

  final List<String> _titles = const [
    'Mi Resumen',
    'Mis Tareas',
    'Control Horario',
    'Mis Ausencias',
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
          'Tienes ${notificationsVm.unreadCount} notificacion(es) nuevas.',
        );
      }
    });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
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
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: notificationsVm.unreadCount == 0
                              ? null
                              : () async {
                                  await notificationsVm.markAllAsRead();
                                },
                          child: const Text('Marcar todas leidas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: notifications.isEmpty
                          ? const Center(child: Text('No hay notificaciones'))
                          : ListView.builder(
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final item = notifications[index];
                                return Card(
                                  color: item.isRead ? null : Colors.green.shade50,
                                  child: ListTile(
                                    leading: Icon(
                                      item.isRead ? Icons.notifications_none : Icons.notifications_active,
                                      color: item.isRead ? Colors.grey : Colors.green.shade900,
                                    ),
                                    title: Text(item.title),
                                    subtitle: Text(item.message),
                                    trailing: item.isRead
                                        ? null
                                        : const Icon(Icons.fiber_manual_record, size: 12, color: Colors.red),
                                    onTap: () async {
                                      await notificationsVm.markAsRead(item.id);
                                      if (!mounted) {
                                        return;
                                      }
                                      Navigator.of(this.context).pop();
                                      setState(() {
                                        _selectedIndex = _mapActionRouteToTab(item.actionRoute);
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
    final notificationsVm = context.watch<NotificationsViewModel>();

    return AppBar(
      title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: _openNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none),
              if (notificationsVm.unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      notificationsVm.unreadCount > 9 ? '9+' : '${notificationsVm.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          offset: const Offset(0, 50),
          onSelected: (value) async {
            if (value == 'logout') {
              await context.read<SessionViewModel>().clearSession();
              if (!mounted) return;
              Navigator.of(this.context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
              return;
            }
            if (value == 'profile') {
              await _showProfileDialog();
              return;
            }
            if (value == 'password') {
              await _showChangePasswordDialog();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatarWidget(context),
                const SizedBox(width: 8),
                if (MediaQuery.of(context).size.width > 400) ...[
                  Flexible(
                    child: Text(
                      context.watch<SessionViewModel>().user?.name ?? 'Trabajador',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ],
            ),
          ),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('Mi Perfil'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'password',
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Cambiar Contrasena'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Salir', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarWidget(BuildContext context) {
    final photoUrl = context.watch<SessionViewModel>().user?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: Colors.green.shade100,
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.green.shade100,
      child: Icon(Icons.person, size: 20, color: Colors.green.shade900),
    );
  }

  Future<void> _changeProfilePhoto() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final userId = session.user?.id;
    if (token == null || userId == null) return;
    final photoService = context.read<WorkerPhotoService>();

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 800,
    );
    if (picked == null) return;

    if (!mounted) return;
    final bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType ?? 'image/jpeg';
    final fileName = picked.name;

    try {
      await photoService.uploadPhoto(
        token,
        workerId: userId,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (mounted) AppToast.success(context, 'Foto de perfil actualizada.');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Error al subir foto: $e');
    }
  }

  Future<void> _showProfileDialog() async {
    final user = context.read<SessionViewModel>().user;
    if (user == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mi Perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nombre: ${user.name}'),
              const SizedBox(height: 6),
              Text('Correo: ${user.email}'),
              const SizedBox(height: 6),
              Text('Rol: ${user.role}'),
              const SizedBox(height: 6),
              Text('Puede editar partes: ${user.canEditWorkOrders ? 'SI' : 'NO'}'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await _changeProfilePhoto();
                },
                icon: const Icon(Icons.photo_camera),
                label: const Text('Cambiar foto de perfil'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null || token.isEmpty) {
      AppToast.warning(context, 'No hay sesion activa.');
      return;
    }

    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    try {
      final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cambiar Contrasena'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena actual',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contrasena',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nueva contrasena',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final current = currentCtrl.text.trim();
                  final next = newCtrl.text.trim();
                  final confirm = confirmCtrl.text.trim();

                  if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                    AppToast.warning(dialogContext, 'Completa todos los campos.');
                    return;
                  }
                  if (next.length < 8) {
                    AppToast.warning(dialogContext, 'La nueva contrasena debe tener al menos 8 caracteres.');
                    return;
                  }
                  if (next != confirm) {
                    AppToast.warning(dialogContext, 'Las contrasenas no coinciden.');
                    return;
                  }

                  try {
                    await context.read<AuthService>().changePassword(
                          token,
                          currentPassword: current,
                          newPassword: next,
                        );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      AppToast.error(dialogContext, 'No se pudo cambiar la contrasena: $e');
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      );

      if (changed == true && mounted) {
        AppToast.success(context, 'Contrasena actualizada correctamente.');
      }
    } finally {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: IconThemeData(color: Colors.green.shade900),
                  selectedLabelTextStyle: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: Text('Partes')),
                    NavigationRailDestination(icon: Icon(Icons.access_time_outlined), selectedIcon: Icon(Icons.access_time_filled), label: Text('Fichaje')),
                    NavigationRailDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: Text('Ausencias')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(context),
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            indicatorColor: Colors.green.shade100,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1B5E20)), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment, color: Color(0xFF1B5E20)), label: 'Partes'),
              NavigationDestination(icon: Icon(Icons.access_time_outlined), selectedIcon: Icon(Icons.access_time_filled, color: Color(0xFF1B5E20)), label: 'Fichaje'),
              NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note, color: Color(0xFF1B5E20)), label: 'Ausencias'),
            ],
          ),
        );
      },
    );
  }
}
