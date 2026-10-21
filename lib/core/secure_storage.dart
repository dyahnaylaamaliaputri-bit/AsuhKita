// Letak file: mobile/lib/core/secure_storage.dart
// Fungsi: Mengelola penyimpanan aman token JWT (Keystore Android / Keychain iOS) dan session lokal

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Simpan Access Token dan Refresh Token setelah login berhasil
  Future<void> saveAuthSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String name,
    required String email,
    required String role,
  }) async {
    await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
    await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
    await _storage.write(key: AppConstants.keyUserId, value: userId);
    await _storage.write(key: AppConstants.keyUserName, value: name);
    await _storage.write(key: AppConstants.keyUserEmail, value: email);
    await _storage.write(key: AppConstants.keyUserRole, value: role);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.keyRefreshToken);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: AppConstants.keyUserRole);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: AppConstants.keyUserName);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: AppConstants.keyUserEmail);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.keyBiometricEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: AppConstants.keyBiometricEnabled);
    return val == 'true';
  }

  Future<void> saveBiometricCredentials({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String name,
    required String email,
    required String role,
  }) async {
    await _storage.write(key: AppConstants.keyBiometricAccessToken, value: accessToken);
    await _storage.write(key: AppConstants.keyBiometricRefreshToken, value: refreshToken);
    await _storage.write(key: AppConstants.keyBiometricUserId, value: userId);
    await _storage.write(key: AppConstants.keyBiometricName, value: name);
    await _storage.write(key: AppConstants.keyBiometricEmail, value: email);
    await _storage.write(key: AppConstants.keyBiometricRole, value: role);
    await setBiometricEnabled(true);
  }

  Future<void> saveLastBiometricUser({
    required String email,
    required String name,
    required String role,
  }) async {
    await _storage.write(key: AppConstants.keyBiometricEmail, value: email);
    await _storage.write(key: AppConstants.keyBiometricName, value: name);
    await _storage.write(key: AppConstants.keyBiometricRole, value: role);
    await setBiometricEnabled(true);
  }

  Future<String?> getLastBiometricEmail() async {
    return await _storage.read(key: AppConstants.keyBiometricEmail);
  }

  Future<String?> getLastBiometricName() async {
    return await _storage.read(key: AppConstants.keyBiometricName);
  }

  Future<String?> getLastBiometricRole() async {
    return await _storage.read(key: AppConstants.keyBiometricRole);
  }

  Future<String?> getBiometricUserId() async {
    return await _storage.read(key: AppConstants.keyBiometricUserId);
  }

  Future<String?> getBiometricAccessToken() async {
    return await _storage.read(key: AppConstants.keyBiometricAccessToken);
  }

  Future<String?> getBiometricRefreshToken() async {
    return await _storage.read(key: AppConstants.keyBiometricRefreshToken);
  }

  // Hapus HANYA token sesi aktif saat logout, biarkan kredensial biometrik tetap tersimpan di Keystore
  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: AppConstants.keyBiometricAccessToken);
    await _storage.delete(key: AppConstants.keyBiometricRefreshToken);
    await _storage.delete(key: AppConstants.keyBiometricUserId);
    await _storage.delete(key: AppConstants.keyBiometricName);
    await _storage.delete(key: AppConstants.keyBiometricEmail);
    await _storage.delete(key: AppConstants.keyBiometricRole);
    await setBiometricEnabled(false);
  }

  Future<void> clearAuthSession() async {
    await _storage.delete(key: AppConstants.keyAccessToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
    await _storage.delete(key: AppConstants.keyUserId);
    await _storage.delete(key: AppConstants.keyUserName);
    await _storage.delete(key: AppConstants.keyUserEmail);
    await _storage.delete(key: AppConstants.keyUserRole);
  }
}
