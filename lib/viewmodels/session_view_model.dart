import 'package:flutter/material.dart';

import '../models/user.dart';

class SessionViewModel extends ChangeNotifier {
  User? _user;

  User? get user => _user;
  String? get token => _user?.token;
  bool get isAuthenticated => _user?.token != null && _user!.token!.isNotEmpty;

  void setSession(User user) {
    _user = user;
    notifyListeners();
  }

  void clearSession() {
    _user = null;
    notifyListeners();
  }
}
