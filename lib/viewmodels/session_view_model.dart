import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/network/api_client.dart';

class SessionViewModel extends ChangeNotifier {
  static const _rememberMeKey = 'remember_me';
  static const _rememberedEmailKey = 'remembered_email';
  static const _userSessionKey = 'user_session';
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
      _pendingNotice = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
      await _clearPersistedSession(prefs, clearRememberedEmail: false);
      _user = null;
      _isReady = true;
      notifyListeners();
      return;
    }

    _user = _rememberMeEnabled ? _restorePersistedUser(prefs) : null;

    if (_user == null) {
      await prefs.remove(_userSessionKey);
    } else if (ApiClient.isJwtExpired(_user!.token ?? '')) {
      _pendingNotice = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
      _user = null;
      await _clearPersistedSession(prefs, clearRememberedEmail: false);
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
      await prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
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
    _pendingNotice = message ?? 'Tu sesión ha expirado. Inicia sesión de nuevo.';

    final prefs = await SharedPreferences.getInstance();
    await _clearPersistedSession(prefs, clearRememberedEmail: false);

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
    if (_rememberMeEnabled) {
      await prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
    } else {
      await prefs.remove(_userSessionKey);
    }

    _rememberedEmail = user.email;
    notifyListeners();
  }

  User? _restorePersistedUser(SharedPreferences prefs) {
    final rawUser = prefs.getString(_userSessionKey);
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final user = User.fromJson(decoded);
      if ((user.token ?? '').isEmpty) {
        return null;
      }

      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPersistedSession(
    SharedPreferences prefs, {
    required bool clearRememberedEmail,
  }) async {
    await prefs.remove(_userSessionKey);
    await prefs.remove(_sessionStartedAtKey);
    if (clearRememberedEmail) {
      await prefs.setBool(_rememberMeKey, false);
      await prefs.remove(_rememberedEmailKey);
    }
  }
}
