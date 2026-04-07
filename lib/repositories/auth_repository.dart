import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final passwordHash = sha256.convert(utf8.encode(password)).toString();

    final result = await _client
        .from('Users')
        .select('id, username, last_name, first_name, email, role, phone')
        .eq('username', username)
        .eq('password_hash', passwordHash)
        .single();

    return result;
  }

  void logout() {}
}
