import 'package:flutter/material.dart';
import '../../repositories/auth_repository.dart';

enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  final _repo = AuthRepository();

  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

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
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  void logout() {
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
