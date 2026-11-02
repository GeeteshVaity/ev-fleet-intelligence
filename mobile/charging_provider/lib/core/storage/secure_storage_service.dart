import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: 'access_token');
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: 'access_token');
  }
}
