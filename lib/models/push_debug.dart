class PushDebugStatus {
  const PushDebugStatus({
    required this.firebaseEnabled,
    required this.credentialSource,
    required this.credentialsReadable,
    required this.initializationAttempted,
    required this.firebaseInitialized,
    required this.lastInitializationAttemptAt,
    required this.lastInitializationSuccessAt,
    required this.lastInitializationError,
    required this.lastSendAttemptAt,
    required this.lastSendSuccessAt,
    required this.lastSendError,
    required this.lastRequestedTokenCount,
    required this.lastInvalidTokenCount,
    required this.activeTokenCount,
    required this.activeTokensByPlatform,
  });

  final bool firebaseEnabled;
  final String credentialSource;
  final bool credentialsReadable;
  final bool initializationAttempted;
  final bool firebaseInitialized;
  final DateTime? lastInitializationAttemptAt;
  final DateTime? lastInitializationSuccessAt;
  final String? lastInitializationError;
  final DateTime? lastSendAttemptAt;
  final DateTime? lastSendSuccessAt;
  final String? lastSendError;
  final int lastRequestedTokenCount;
  final int lastInvalidTokenCount;
  final int activeTokenCount;
  final List<PushDebugPlatformCount> activeTokensByPlatform;

  factory PushDebugStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final platformItems = json['activeTokensByPlatform'];
    return PushDebugStatus(
      firebaseEnabled: json['firebaseEnabled'] as bool? ?? false,
      credentialSource: json['credentialSource'] as String? ?? 'NONE',
      credentialsReadable: json['credentialsReadable'] as bool? ?? false,
      initializationAttempted:
          json['initializationAttempted'] as bool? ?? false,
      firebaseInitialized: json['firebaseInitialized'] as bool? ?? false,
      lastInitializationAttemptAt: parseDate(
        json['lastInitializationAttemptAt'],
      ),
      lastInitializationSuccessAt: parseDate(
        json['lastInitializationSuccessAt'],
      ),
      lastInitializationError: json['lastInitializationError'] as String?,
      lastSendAttemptAt: parseDate(json['lastSendAttemptAt']),
      lastSendSuccessAt: parseDate(json['lastSendSuccessAt']),
      lastSendError: json['lastSendError'] as String?,
      lastRequestedTokenCount:
          (json['lastRequestedTokenCount'] as num?)?.toInt() ?? 0,
      lastInvalidTokenCount:
          (json['lastInvalidTokenCount'] as num?)?.toInt() ?? 0,
      activeTokenCount: (json['activeTokenCount'] as num?)?.toInt() ?? 0,
      activeTokensByPlatform: platformItems is List
          ? platformItems
                .whereType<Map<String, dynamic>>()
                .map(PushDebugPlatformCount.fromJson)
                .toList()
          : const <PushDebugPlatformCount>[],
    );
  }
}

class PushDebugPlatformCount {
  const PushDebugPlatformCount({required this.platform, required this.count});

  final String platform;
  final int count;

  factory PushDebugPlatformCount.fromJson(Map<String, dynamic> json) {
    return PushDebugPlatformCount(
      platform: json['platform'] as String? ?? 'UNKNOWN',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PushDebugToken {
  const PushDebugToken({
    required this.workerId,
    required this.workerName,
    required this.workerEmail,
    required this.platform,
    required this.active,
    required this.maskedToken,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final int? workerId;
  final String workerName;
  final String workerEmail;
  final String platform;
  final bool active;
  final String maskedToken;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  factory PushDebugToken.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final rawWorkerId = json['workerId'];
    return PushDebugToken(
      workerId: rawWorkerId is num ? rawWorkerId.toInt() : null,
      workerName: json['workerName'] as String? ?? 'Sin nombre',
      workerEmail: json['workerEmail'] as String? ?? '',
      platform: json['platform'] as String? ?? 'UNKNOWN',
      active: json['active'] as bool? ?? false,
      maskedToken: json['maskedToken'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
      lastSeenAt: parseDate(json['lastSeenAt']),
    );
  }
}
