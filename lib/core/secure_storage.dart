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

  // Hapus token aktif saat logout namun pertahankan kredensial biometrik yang didaftarkan
  Future<void> clearAuthSession() async {
    final bioEmail = await getLastBiometricEmail();
    final bioName = await getLastBiometricName();
    final bioRole = await getLastBiometricRole();
    final bioStatus = await isBiometricEnabled();

    await _storage.deleteAll();

    // Pertahankan kredensial biometrik jika user masih ingin memakai biometrik di HP ini
    if (bioEmail != null && bioEmail.isNotEmpty) {
      await saveLastBiometricUser(
        email: bioEmail,
        name: bioName ?? 'Donatur Asuh',
        role: bioRole ?? 'donatur',
      );
    }
    if (bioStatus) {
      await setBiometricEnabled(true);
    }
  }
}
