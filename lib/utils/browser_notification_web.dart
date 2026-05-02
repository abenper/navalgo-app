// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

const String _firebaseMessagingScope = '/firebase-cloud-messaging-push-scope';

String browserNotificationPermissionStatus() {
  if (!html.Notification.supported) {
    return 'unsupported';
  }
  return html.Notification.permission ?? 'default';
}

Future<void> showBrowserNotification({
  required String title,
  String? body,
  String? tag,
}) async {
  if (!html.Notification.supported) {
    return;
  }
  if (html.Notification.permission != 'granted') {
    return;
  }

  final serviceWorker = html.window.navigator.serviceWorker;
  if (serviceWorker != null) {
    try {
      final registration = await serviceWorker.getRegistration(
        _firebaseMessagingScope,
      );
      await registration.showNotification(title, {
        'body': body,
        'icon': '/icons/Icon-192.png',
        'badge': '/icons/Icon-192.png',
        'tag': tag ?? 'navalgo-web-push',
      });
      return;
    } catch (_) {}
  }

  final notification = html.Notification(
    title,
    body: body,
    icon: '/icons/Icon-192.png',
    tag: tag ?? 'navalgo-web-push',
  );
  notification.onClick.listen((_) {
    notification.close();
  });
}
