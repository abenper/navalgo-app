import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class SessionViewModel extends ChangeNotifier {
  static const _rememberMeKey = 'remember_me';
  static const _rememberedEmailKey = 'remembered_email';
  static const _legacyUserSessionKey = 'user_session';
  static const _sessionStartedAtKey = 'session_started_at';
  static const _maxSessionAge = Duration(days: 30);

  User? _user;
  bool _isReady = false;
  bool _rememberMeEnabled = false;
  String _rememberedEmail = '';
  String? _pendingNotice;

  User? get user => _user;
  String? get token => _user?.token;
  bool get isAuthenticated => _user?.token != null && _user!.token!.isNotEmpty;
  bool get isReady => _isReady;
  bool get rememberMeEnabled => _rememberMeEnabled;
  String get rememberedEmail => _rememberedEmail;

  String? consumePendingNotice() {
    final notice = _pendingNotice;
    _pendingNotice = null;
    return notice;
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberMeEnabled = prefs.getBool(_rememberMeKey) ?? false;
    _rememberedEmail = prefs.getString(_rememberedEmailKey) ?? '';

    if (_rememberMeEnabled && _isMaxAgeExpired(prefs)) {
      _pendingNotice = 'Tu sesiÃ³n ha expirado. Inicia sesiÃ³n de nuevo.';
      await prefs.remove(_sessionStartedAtKey);
    }

    _user = null;
    await prefs.remove(_legacyUserSessionKey);

    _isReady = true;
    notifyListeners();
  }

  Future<void> setSession(User user, {required bool rememberMe}) async {
    _user = user;
    _rememberMeEnabled = rememberMe;
    _rememberedEmail = user.email;
    _pendingNotice = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);
    await prefs.setString(_rememberedEmailKey, user.email);
    await prefs.remove(_legacyUserSessionKey);

    if (rememberMe) {
      await prefs.setInt(
        _sessionStartedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_sessionStartedAtKey);
    }

    notifyListeners();
  }

  Future<void> clearSession() async {
    _user = null;
    _pendingNotice = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyUserSessionKey);
    await prefs.remove(_sessionStartedAtKey);
    await prefs.setBool(_rememberMeKey, false);
    await prefs.remove(_rememberedEmailKey);

    _rememberMeEnabled = false;
    _rememberedEmail = '';
    notifyListeners();
  }

  Future<void> expireSession({String? message}) async {
    _user = null;
    _pendingNotice =
        message ?? 'Tu sesiÃ³n ha expirado. Inicia sesiÃ³n de nuevo.';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyUserSessionKey);
    await prefs.remove(_sessionStartedAtKey);

    notifyListeners();
  }

  bool _isMaxAgeExpired(SharedPreferences prefs) {
    final startedAt = prefs.getInt(_sessionStartedAtKey);
    if (startedAt == null) {
      return false;
    }
    final started = DateTime.fromMillisecondsSinceEpoch(startedAt);
    return DateTime.now().difference(started) >= _maxSessionAge;
  }

  Future<void> updateUser(User user) async {
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedEmailKey, user.email);
    await prefs.remove(_legacyUserSessionKey);

    _rememberedEmail = user.email;
    notifyListeners();
  }
}
