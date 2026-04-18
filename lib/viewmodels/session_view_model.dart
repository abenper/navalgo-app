import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class SessionViewModel extends ChangeNotifier {
  static const _rememberMeKey = 'remember_me';
  static const _rememberedEmailKey = 'remembered_email';
  static const _userSessionKey = 'user_session';

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

    if (_rememberMeEnabled) {
      final rawSession = prefs.getString(_userSessionKey);
      if (rawSession != null && rawSession.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawSession) as Map<String, dynamic>;
          _user = User.fromJson(decoded);
          if (_isJwtExpired(_user?.token)) {
            _user = null;
            _pendingNotice = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
            await prefs.remove(_userSessionKey);
          }
        } catch (_) {
          _user = null;
          await prefs.remove(_userSessionKey);
        }
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
      await prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
    } else {
      await prefs.remove(_userSessionKey);
    }

    notifyListeners();
  }

  Future<void> clearSession() async {
    _user = null;
    _pendingNotice = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userSessionKey);
    await prefs.setBool(_rememberMeKey, false);
    await prefs.remove(_rememberedEmailKey);

    _rememberMeEnabled = false;
    _rememberedEmail = '';
    notifyListeners();
  }

  Future<void> expireSession({String? message}) async {
    _user = null;
    _pendingNotice =
        message ?? 'Tu sesión ha expirado. Inicia sesión de nuevo.';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userSessionKey);

    notifyListeners();
  }

  Future<void> updateUser(User user) async {
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    if (_rememberMeEnabled) {
      await prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
      await prefs.setString(_rememberedEmailKey, user.email);
    }

    _rememberedEmail = user.email;
    notifyListeners();
  }

  bool _isJwtExpired(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return false;
      }

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final rawExp = decoded['exp'];
      final expSeconds = rawExp is num
          ? rawExp.toInt()
          : int.tryParse('$rawExp');
      if (expSeconds == null) {
        return false;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        expSeconds * 1000,
        isUtc: true,
      );
      return !expiry.isAfter(DateTime.now().toUtc());
    } catch (_) {
      return false;
    }
  }
}
