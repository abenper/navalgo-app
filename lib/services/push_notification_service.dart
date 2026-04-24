import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on UnsupportedError {
    return;
  } catch (_) {}
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messagingOverride = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging? _messagingOverride;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  NotificationService? _notificationApi;
  Future<void> Function()? _refreshNotifications;

  String? _authToken;
  String? _registeredPushToken;
  bool _setupAttempted = false;
  bool _firebaseAvailable = false;

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }

  Future<void> syncSession({
    required String? previousAuthToken,
    required String? currentAuthToken,
    required NotificationService notificationApi,
    required Future<void> Function() refreshNotifications,
  }) async {
    _notificationApi = notificationApi;
    _refreshNotifications = refreshNotifications;
    _authToken = currentAuthToken;

    if (kIsWeb) {
      return;
    }

    await _ensureInitialized();
    if (!_firebaseAvailable) {
      return;
    }

    if (currentAuthToken == null || currentAuthToken.isEmpty) {
      await _unregisterPushToken(previousAuthToken);
      return;
    }

    await _registerCurrentToken(force: previousAuthToken != currentAuthToken);
  }

  Future<void> _ensureInitialized() async {
    if (_setupAttempted) {
      return;
    }
    _setupAttempted = true;

    if (kIsWeb) {
      _firebaseAvailable = false;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_handleForegroundMessage(message));
      });
      _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((_) {
        final refreshNotifications = _refreshNotifications;
        if (refreshNotifications != null) {
          unawaited(refreshNotifications());
        }
      });
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
        unawaited(
          _registerCurrentToken(explicitToken: token, force: true),
        );
      });

      _firebaseAvailable = true;
    } on UnsupportedError {
      _firebaseAvailable = false;
    } catch (_) {
      _firebaseAvailable = false;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final refreshNotifications = _refreshNotifications;
    if (refreshNotifications != null) {
      await refreshNotifications();
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'navalgo_notifications',
          'Navalgo Notifications',
          channelDescription:
              'Avisos operativos, recordatorios y revisiones pendientes.',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _registerCurrentToken({
    String? explicitToken,
    bool force = false,
  }) async {
    final authToken = _authToken;
    final notificationApi = _notificationApi;
    if (!_firebaseAvailable || notificationApi == null) {
      return;
    }
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    final pushToken = explicitToken ?? await _messaging.getToken();
    if (pushToken == null || pushToken.isEmpty) {
      return;
    }
    if (!force && pushToken == _registeredPushToken) {
      return;
    }

    try {
      await notificationApi.registerPushToken(
        authToken,
        pushToken: pushToken,
        platform: _platformLabel(),
      );
      _registeredPushToken = pushToken;
    } catch (_) {}
  }

  Future<void> _unregisterPushToken(String? authToken) async {
    final notificationApi = _notificationApi;
    final registeredPushToken = _registeredPushToken;
    if (!_firebaseAvailable || notificationApi == null) {
      return;
    }
    if (authToken == null || authToken.isEmpty) {
      return;
    }
    if (registeredPushToken == null || registeredPushToken.isEmpty) {
      return;
    }

    try {
      await notificationApi.unregisterPushToken(
        authToken,
        pushToken: registeredPushToken,
      );
    } catch (_) {}
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'WEB';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ANDROID';
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.macOS:
        return 'MACOS';
      case TargetPlatform.windows:
        return 'WINDOWS';
      case TargetPlatform.linux:
        return 'LINUX';
      case TargetPlatform.fuchsia:
        return 'FUCHSIA';
    }
  }
}