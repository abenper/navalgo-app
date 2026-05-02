import 'browser_notification_stub.dart'
    if (dart.library.html) 'browser_notification_web.dart'
    as impl;

String browserNotificationPermissionStatus() {
  return impl.browserNotificationPermissionStatus();
}

Future<void> showBrowserNotification({
  required String title,
  String? body,
  String? tag,
}) {
  return impl.showBrowserNotification(title: title, body: body, tag: tag);
}
