import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../repositories/auth_repository.dart';

enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  final _repo = AuthRepository();

  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;
  bool _isInitialized = false;

  static const _kUserKey = 'saved_user';

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;

  AuthController() {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUserKey);
      if (raw != null) {
        _currentUser = Map<String, dynamic>.from(jsonDecode(raw));
        _status = AuthStatus.success;
      }
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(user));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'Нэвтрэх нэр болон нууц үгээ оруулна уу';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repo.login(
        username: username.trim(),
        password: password,
      );
      _currentUser = user;
      _status = AuthStatus.success;
      await _saveSession(user);
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _clearSession();
    _currentUser = null;
    _status = AuthStatus.idle;
    notifyListeners();
  }

  String _parseError(String error) {
    if (error.contains('No rows') || error.contains('0 rows')) {
      return 'Нэвтрэх нэр эсвэл нууц үг буруу байна';
    } else if (error.contains('network') || error.contains('socket')) {
      return 'Интернэт холболт шалгана уу';
    }
    return 'Алдаа гарлаа. Дахин оролдоно уу';
  }
}
