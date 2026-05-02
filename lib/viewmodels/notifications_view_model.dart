import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../utils/browser_notification.dart';
import 'session_view_model.dart';

class NotificationsViewModel extends ChangeNotifier {
  NotificationsViewModel({
    required NotificationService notificationService,
    required SessionViewModel session,
  }) : _notificationService = notificationService,
       _session = session {
    _session.addListener(_handleSessionChanged);
    _syncAutoRefreshWithSession();
  }

  final NotificationService _notificationService;
  final SessionViewModel _session;
  static const Duration _pollInterval = Duration(seconds: 15);

  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  List<AppNotification> _notifications = <AppNotification>[];
  int _unreadCount = 0;
  Timer? _pollTimer;
  String? _lastSessionToken;
  bool _webNotificationsPrimed = false;
  final Set<int> _webNotifiedIds = <int>{};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> refresh() async {
    await _refresh(showLoading: true);
  }

  Future<void> _refresh({required bool showLoading}) async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      final hadState =
          _error != 'No hay sesion activa.' ||
          _notifications.isNotEmpty ||
          _unreadCount != 0 ||
          _isLoading;
      _error = 'No hay sesion activa.';
      _notifications = <AppNotification>[];
      _unreadCount = 0;
      _isLoading = false;
      if (hadState) {
        notifyListeners();
      }
      return;
    }

    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final previousNotifications = _notifications;
      final notifications = await _notificationService.getNotifications(token);
      final unreadCount = await _notificationService.getUnreadCount(token);
      final changed =
          !_sameNotifications(_notifications, notifications) ||
          _unreadCount != unreadCount ||
          _error != null ||
          _isLoading;
      _showWebNotificationFallback(
        previous: previousNotifications,
        next: notifications,
      );
      _notifications = notifications;
      _unreadCount = unreadCount;
      _error = null;
      if (changed || showLoading) {
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      if (showLoading) {
        notifyListeners();
      }
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      return;
    }

    await _notificationService.markAsRead(
      token,
      notificationId: notificationId,
    );
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

  void _handleSessionChanged() {
    _syncAutoRefreshWithSession();
  }

  void _syncAutoRefreshWithSession() {
    final currentToken = _session.token;
    if (currentToken == _lastSessionToken) {
      return;
    }

    _lastSessionToken = currentToken;
    _pollTimer?.cancel();

    if (currentToken == null || currentToken.isEmpty) {
      _notifications = <AppNotification>[];
      _unreadCount = 0;
      _error = null;
      _isLoading = false;
      _webNotificationsPrimed = false;
      _webNotifiedIds.clear();
      notifyListeners();
      return;
    }

    _webNotificationsPrimed = false;
    _webNotifiedIds.clear();
    unawaited(_refresh(showLoading: false));
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_refresh(showLoading: false));
    });
  }

  void _showWebNotificationFallback({
    required List<AppNotification> previous,
    required List<AppNotification> next,
  }) {
    if (!kIsWeb) {
      return;
    }

    if (!_webNotificationsPrimed) {
      _webNotificationsPrimed = true;
      _webNotifiedIds.addAll(next.map((notification) => notification.id));
      return;
    }

    final previousIds = previous.map((notification) => notification.id).toSet();
    final freshNotifications = next.where((notification) {
      return !notification.isRead &&
          !previousIds.contains(notification.id) &&
          !_webNotifiedIds.contains(notification.id);
    });

    for (final notification in freshNotifications) {
      _webNotifiedIds.add(notification.id);
      unawaited(
        showBrowserNotification(
          title: notification.title,
          body: notification.message,
          tag: 'notification-${notification.id}',
        ),
      );
    }
  }

  bool _sameNotifications(
    List<AppNotification> previous,
    List<AppNotification> next,
  ) {
    if (identical(previous, next)) {
      return true;
    }
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index += 1) {
      final a = previous[index];
      final b = next[index];
      if (a.id != b.id ||
          a.isRead != b.isRead ||
          a.title != b.title ||
          a.message != b.message ||
          a.actionRoute != b.actionRoute ||
          a.type != b.type ||
          a.createdAt != b.createdAt) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _session.removeListener(_handleSessionChanged);
    super.dispose();
  }
}
