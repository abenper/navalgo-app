import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AndroidUpdateDownloadEvent {
  const AndroidUpdateDownloadEvent({
    required this.status,
    required this.message,
    this.progress,
  });

  final String status;
  final String message;
  final double? progress;

  bool get isFinal =>
      status == 'success' ||
      status == 'failed' ||
      status == 'installer_opened' ||
      status == 'permission_required' ||
      status == 'browser_opened';

  factory AndroidUpdateDownloadEvent.fromMap(Map<dynamic, dynamic> map) {
    final rawProgress = map['progress'];
    return AndroidUpdateDownloadEvent(
      status: map['status']?.toString() ?? 'info',
      message: map['message']?.toString() ?? 'Actualizando NavalGO',
      progress: rawProgress is num ? rawProgress.toDouble() : null,
    );
  }
}

class AndroidAppUpdate {
  const AndroidAppUpdate({
    required this.versionName,
    required this.buildNumber,
    required this.apkUrl,
    required this.fileName,
    this.releaseNotes,
  });

  final String versionName;
  final int buildNumber;
  final String apkUrl;
  final String fileName;
  final String? releaseNotes;
}

class AppUpdateService {
  AppUpdateService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'downloadStatus') {
        return;
      }
      final arguments = call.arguments;
      if (arguments is Map) {
        _downloadEvents.add(AndroidUpdateDownloadEvent.fromMap(arguments));
      }
    });
  }

  static const String versionUrl =
      'https://naval-go.com/downloads/navalgo-android-version.json';
  static const MethodChannel _channel = MethodChannel(
    'com.example.navalgo/app_update',
  );

  final http.Client _httpClient;
  final StreamController<AndroidUpdateDownloadEvent> _downloadEvents =
      StreamController<AndroidUpdateDownloadEvent>.broadcast();

  Stream<AndroidUpdateDownloadEvent> get downloadEvents =>
      _downloadEvents.stream;

  Future<AndroidAppUpdate?> checkAndroidUpdate() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final currentVersion = packageInfo.version;

    final versionUri = Uri.parse(versionUrl).replace(
      queryParameters: <String, String>{
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final response = await _httpClient
        .get(versionUri)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final remoteVersion = (payload['versionName'] as String?)?.trim() ?? '';
    final remoteBuild = payload['buildNumber'] is num
        ? (payload['buildNumber'] as num).toInt()
        : int.tryParse('${payload['buildNumber']}') ?? 0;
    final apkUrl =
        (payload['apkUrl'] as String?)?.trim() ??
        'https://naval-go.com/downloads/navalgo-android.apk';

    if (!_isRemoteNewer(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      remoteVersion: remoteVersion,
      remoteBuild: remoteBuild,
    )) {
      return null;
    }

    return AndroidAppUpdate(
      versionName: remoteVersion.isEmpty ? 'nueva' : remoteVersion,
      buildNumber: remoteBuild,
      apkUrl: apkUrl,
      fileName: (payload['fileName'] as String?)?.trim().isNotEmpty == true
          ? (payload['fileName'] as String).trim()
          : 'navalgo-android.apk',
      releaseNotes: (payload['releaseNotes'] as String?)?.trim(),
    );
  }

  Future<void> downloadAndroidApk(AndroidAppUpdate update) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    _downloadEvents.add(
      const AndroidUpdateDownloadEvent(
        status: 'queued',
        message: 'Preparando descarga de NavalGO',
      ),
    );

    try {
      await _channel
          .invokeMethod<Object?>('downloadApk', <String, Object?>{
            'url': update.apkUrl,
            'fileName': update.fileName,
            'title': 'NavalGO ${update.versionName}',
          })
          .timeout(const Duration(seconds: 8));
    } on PlatformException catch (error) {
      _downloadEvents.add(
        AndroidUpdateDownloadEvent(
          status: 'failed',
          message:
              error.message ?? 'Android no pudo iniciar la descarga interna',
        ),
      );
      await _openApkUrl(update.apkUrl);
    } on MissingPluginException {
      _downloadEvents.add(
        const AndroidUpdateDownloadEvent(
          status: 'failed',
          message: 'El instalador interno no esta disponible',
        ),
      );
      await _openApkUrl(update.apkUrl);
    } on TimeoutException {
      _downloadEvents.add(
        const AndroidUpdateDownloadEvent(
          status: 'failed',
          message: 'Android no respondio al iniciar la descarga interna',
        ),
      );
      await _openApkUrl(update.apkUrl);
    }
  }

  Future<void> openAndroidApkUrl(AndroidAppUpdate update) {
    return _openApkUrl(update.apkUrl);
  }

  Future<void> _openApkUrl(String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    _downloadEvents.add(
      const AndroidUpdateDownloadEvent(
        status: 'browser_opened',
        message: 'Abriendo descarga en el navegador',
      ),
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw PlatformException(
        code: 'download_failed',
        message: 'No se pudo abrir la descarga de la APK',
      );
    }
  }

  bool _isRemoteNewer({
    required String currentVersion,
    required int currentBuild,
    required String remoteVersion,
    required int remoteBuild,
  }) {
    if (remoteBuild > currentBuild) {
      return true;
    }
    if (remoteBuild < currentBuild) {
      return false;
    }
    return _compareVersions(remoteVersion, currentVersion) > 0;
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final bParts = b.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final maxLength = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;
    for (var i = 0; i < maxLength; i += 1) {
      final aValue = i < aParts.length ? aParts[i] : 0;
      final bValue = i < bParts.length ? bParts[i] : 0;
      if (aValue != bValue) {
        return aValue.compareTo(bValue);
      }
    }
    return 0;
  }
}
