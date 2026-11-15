import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/constants/app_constants.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      wOptions: WindowsOptions(),
    ),
  );
});

/// Service for persisting sensitive credentials using OS-level secure keystore/keychain,
/// with memory fallback for test environments.
class SecureStorageService {
  final FlutterSecureStorage? _storage;
  final Map<String, String> _memoryStorage = {};

  SecureStorageService([this._storage]);

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    try {
      if (_storage != null) {
        await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
        await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
        return;
      }
    } catch (_) {}
    _memoryStorage[AppConstants.accessTokenKey] = accessToken;
    _memoryStorage[AppConstants.refreshTokenKey] = refreshToken;
  }

  Future<String?> getAccessToken() async {
    try {
      if (_storage != null) {
        return await _storage.read(key: AppConstants.accessTokenKey);
      }
    } catch (_) {}
    return _memoryStorage[AppConstants.accessTokenKey];
  }

  Future<String?> getRefreshToken() async {
    try {
      if (_storage != null) {
        return await _storage.read(key: AppConstants.refreshTokenKey);
      }
    } catch (_) {}
    return _memoryStorage[AppConstants.refreshTokenKey];
  }

  Future<void> clearAll() async {
    try {
      if (_storage != null) {
        await _storage.deleteAll();
      }
    } catch (_) {}
    _memoryStorage.clear();
  }
}
