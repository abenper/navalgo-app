import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

// VAPID public key from Firebase Console > Project Settings > Cloud Messaging
// > Web Push certificates. Required for getToken() on web.
const String _firebaseWebVapidKey =
    'BDi2-Q05VzIhbIm73QBGbteqMoYDeVNEoLnmiQWqvjdLiiI6XyvK8i8SXHv9krSJbgcpVTcwnbvKc5bf0AvkCuM';

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
    debugPrint(
      'Push syncSession authChanged: previous=${_maskToken(previousAuthToken)} current=${_maskToken(currentAuthToken)}',
    );

    await _ensureInitialized();
    if (!_firebaseAvailable) {
      debugPrint('Push unavailable: Firebase no inicializado en cliente.');
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

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Local notifications and onBackgroundMessage only apply to mobile.
      // On web, the browser + firebase-messaging-sw.js handle background
      // notifications natively.
      if (!kIsWeb) {
        await _localNotifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );

        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      }

      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final settings = await _messaging.getNotificationSettings();
      debugPrint(
        'Push permission status: ${settings.authorizationStatus.name}',
      );

      if (!kIsWeb) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_handleForegroundMessage(message));
      });
      _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        debugPrint(
          'Push messageOpenedApp notificationId=${message.messageId} data=${message.data}',
        );
        final refreshNotifications = _refreshNotifications;
        if (refreshNotifications != null) {
          unawaited(refreshNotifications());
        }
      });
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
        debugPrint('Push token refreshed: ${_maskToken(token)}');
        unawaited(_registerCurrentToken(explicitToken: token, force: true));
      });

      _firebaseAvailable = true;
      debugPrint('Push Firebase inicializado correctamente en cliente.');
    } on UnsupportedError {
      _firebaseAvailable = false;
      debugPrint('Push Firebase no soportado en esta plataforma.');
    } catch (error, stackTrace) {
      _firebaseAvailable = false;
      debugPrint('Push Firebase init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'Push foreground message id=${message.messageId} title=${message.notification?.title} data=${message.data}',
    );
    final refreshNotifications = _refreshNotifications;
    if (refreshNotifications != null) {
      await refreshNotifications();
    }

    // On web the browser surfaces foreground messages itself when the SW is
    // registered; flutter_local_notifications doesn't support web.
    if (kIsWeb) {
      return;
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

    final pushToken =
        explicitToken ??
        await _messaging.getToken(
          vapidKey: kIsWeb ? _firebaseWebVapidKey : null,
        );
    if (pushToken == null || pushToken.isEmpty) {
      debugPrint('Push getToken devolvio null o vacio.');
      return;
    }
    debugPrint(
      'Push token obtenido para ${_platformLabel()}: ${_maskToken(pushToken)}',
    );
    if (!force && pushToken == _registeredPushToken) {
      debugPrint('Push token ya estaba registrado, se reutiliza.');
      return;
    }

    try {
      await notificationApi.registerPushToken(
        authToken,
        pushToken: pushToken,
        platform: _platformLabel(),
      );
      _registeredPushToken = pushToken;
      debugPrint('Push token registrado en backend correctamente.');
    } catch (error, stackTrace) {
      debugPrint('Push token register failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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
      debugPrint('Push token desregistrado del backend.');
    } catch (error, stackTrace) {
      debugPrint('Push token unregister failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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

  String _maskToken(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value.length <= 12) {
      return value;
    }
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }
}
