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

  User? get user => _user;
  String? get token => _user?.token;
  bool get isAuthenticated => _user?.token != null && _user!.token!.isNotEmpty;
  bool get isReady => _isReady;
  bool get rememberMeEnabled => _rememberMeEnabled;
  String get rememberedEmail => _rememberedEmail;

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
        } catch (_) {
          _user = null;
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userSessionKey);
    await prefs.setBool(_rememberMeKey, false);
    await prefs.remove(_rememberedEmailKey);

    _rememberMeEnabled = false;
    _rememberedEmail = '';
    notifyListeners();
  }
}
