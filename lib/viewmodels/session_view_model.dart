import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class SessionViewModel extends ChangeNotifier {
  static const _rememberMeKey = 'remember_me';
  static const _rememberedEmailKey = 'remembered_email';
  static const _legacyUserSessionKey = 'user_session';
  static const _sessionStartedAtKey = 'session_started_at';
  static const _refreshCookieStorageKey = 'auth_refresh_cookie';
  static const _maxSessionAge = Duration(days: 90);

  SessionViewModel({AuthService? authService}) : _authService = authService;

  final AuthService? _authService;

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
      _pendingNotice = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
      await _clearPersistedSession(prefs, clearRememberedEmail: false);
      _user = null;
      _isReady = true;
      notifyListeners();
      return;
    }

    _user = null;
    await _clearLegacyUserSnapshot(prefs);

    if (_rememberMeEnabled) {
      final refreshed = await _tryRefreshStoredSession(prefs);
      if (!refreshed) {
        _pendingNotice = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
        _user = null;
        await _clearPersistedSession(prefs, clearRememberedEmail: false);
      }
    }

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

    if (rememberMe) {
      await prefs.setInt(
        _sessionStartedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      await _clearPersistedSession(prefs, clearRememberedEmail: false);
    }

    notifyListeners();
  }

  Future<void> clearSession() async {
    _user = null;
    _pendingNotice = null;

    final prefs = await SharedPreferences.getInstance();
    await _clearPersistedSession(prefs, clearRememberedEmail: true);

    _rememberMeEnabled = false;
    _rememberedEmail = '';
    notifyListeners();
  }

  Future<void> expireSession({String? message}) async {
    _user = null;
    _pendingNotice =
        message ?? 'Tu sesión ha expirado. Inicia sesión de nuevo.';

    final prefs = await SharedPreferences.getInstance();
    await _clearPersistedSession(prefs, clearRememberedEmail: false);

    notifyListeners();
  }

  Future<bool> refreshSession() async {
    final authService = _authService;
    if (authService == null) {
      return false;
    }

    try {
      final refreshedUser = await authService.refreshSession();
      await updateUser(refreshedUser);
      return true;
    } catch (_) {
      return false;
    }
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
    _rememberedEmail = user.email;
    notifyListeners();
  }

  Future<void> _clearPersistedSession(
    SharedPreferences prefs, {
    required bool clearRememberedEmail,
  }) async {
    await _clearLegacyUserSnapshot(prefs);
    await prefs.remove(_sessionStartedAtKey);
    await prefs.remove(_refreshCookieStorageKey);
    if (clearRememberedEmail) {
      await prefs.setBool(_rememberMeKey, false);
      await prefs.remove(_rememberedEmailKey);
    }
  }

  Future<bool> _tryRefreshStoredSession(SharedPreferences prefs) async {
    final authService = _authService;
    if (authService == null) {
      return false;
    }

    try {
      final refreshedUser = await authService.refreshSession();
      _user = refreshedUser;
      _pendingNotice = null;
      await prefs.setString(_rememberedEmailKey, refreshedUser.email);
      _rememberedEmail = refreshedUser.email;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearLegacyUserSnapshot(SharedPreferences prefs) async {
    await prefs.remove(_legacyUserSessionKey);
  }
}
