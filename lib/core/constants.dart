// Letak file: mobile/lib/core/constants.dart
// Fungsi: Berisi konstanta global aplikasi (URL API, warna tema, key penyimpanan)

class AppConstants {
  // Endpoint backend API (mendukung USB adb reverse, Wi-Fi LAN, dan Android Emulator)
  static const String baseUrl = 'http://127.0.0.1:3000/api';
  static const List<String> candidateBaseUrls = [
    'http://127.0.0.1:3000/api', // USB via adb reverse
    'http://172.16.97.193:3000/api', // Wi-Fi LAN HP & Laptop
    'http://10.0.2.2:3000/api', // Android Emulator
  ];

  // Storage Keys untuk flutter_secure_storage
  static const String keyAccessToken = 'asuhkita_access_token';
  static const String keyRefreshToken = 'asuhkita_refresh_token';
  static const String keyUserRole = 'asuhkita_user_role';
  static const String keyUserId = 'asuhkita_user_id';
  static const String keyUserName = 'asuhkita_user_name';
  static const String keyUserEmail = 'asuhkita_user_email';
  static const String keyBiometricEnabled = 'asuhkita_biometric_enabled';
  static const String keyBiometricEmail = 'asuhkita_bio_email';
  static const String keyBiometricName = 'asuhkita_bio_name';
  static const String keyBiometricRole = 'asuhkita_bio_role';

  // Kunci enkripsi AES-256 (32 karakter string) untuk mengamankan data lokal sensitif (misal nomor HP)
  static const String aesSecretKey = 'AsuhKitaSecureKey2026SuperSafe32';
}
