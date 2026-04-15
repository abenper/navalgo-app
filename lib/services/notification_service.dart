import '../config/api_config.dart';
import '../models/app_notification.dart';
import 'network/api_client.dart';

class NotificationService {
  NotificationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<List<AppNotification>> getNotifications(String token) async {
    final data = await _apiClient.get(
      '/notifications',
      headers: {'Authorization': 'Bearer $token'},
    );

    if (data is! List) {
      return <AppNotification>[];
    }

    return data
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount(String token) async {
    final data = await _apiClient.get(
      '/notifications/unread-count',
      headers: {'Authorization': 'Bearer $token'},
    );

    final map = data as Map<String, dynamic>;
    return map['unreadCount'] as int? ?? 0;
  }

  Future<void> markAsRead(String token, {required int notificationId}) async {
    await _apiClient.patch(
      '/notifications/$notificationId/read',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> markAllAsRead(String token) async {
    await _apiClient.patch(
      '/notifications/read-all',
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
