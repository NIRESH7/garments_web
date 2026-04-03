import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _roleKey = 'user_role';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> saveRole(String role) async {
    await _storage.write(key: _roleKey, value: role);
  }

  Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> userData) async {
    // Normally you'd stringify or use separate keys
    await _storage.write(key: _userKey, value: userData.toString());
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<void> writeValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readValue(String key) async {
    return await _storage.read(key: key);
  }

  // --- Task Assignments ---
  static const String _assignOptionsKey = 'task_assign_options';

  Future<void> saveAssignmentOptions(List<String> options) async {
    final jsonStr = jsonEncode(options);
    await _storage.write(key: _assignOptionsKey, value: jsonStr);
  }

  Future<List<String>?> getAssignmentOptions() async {
    final jsonStr = await _storage.read(key: _assignOptionsKey);
    if (jsonStr == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      return null;
    }
  }
}
