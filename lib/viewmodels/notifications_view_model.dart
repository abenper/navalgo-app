import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'session_view_model.dart';

class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    required NotificationService notificationService,
    required SessionViewModel session,
  })  : _notificationService = notificationService,
        _session = session;

  final NotificationService _notificationService;
  final SessionViewModel _session;

  bool _isLoading = false;
  String? _error;
  List<AppNotification> _notifications = <AppNotification>[];
  int _unreadCount = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> refresh() async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      _error = 'No hay sesion activa.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await _notificationService.getNotifications(token);
      _unreadCount = await _notificationService.getUnreadCount(token);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      return;
    }

    await _notificationService.markAsRead(token, notificationId: notificationId);
    await refresh();
  }

  Future<void> markAllAsRead() async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      return;
    }

    await _notificationService.markAllAsRead(token);
    await refresh();
  }
}
