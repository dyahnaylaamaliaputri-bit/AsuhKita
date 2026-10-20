// Letak file: mobile/lib/core/constants.dart
// Fungsi: Berisi konstanta global aplikasi (URL API, warna tema, key penyimpanan)

class AppConstants {
  // Ganti dengan IP backend komputer Anda saat pengujian fisik di HP (misal: 'http://192.168.1.X:3000')
  // Untuk emulator Android gunakan 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // Storage Keys untuk flutter_secure_storage
  static const String keyAccessToken = 'asuhkita_access_token';
  static const String keyRefreshToken = 'asuhkita_refresh_token';
  static const String keyUserRole = 'asuhkita_user_role';
  static const String keyUserId = 'asuhkita_user_id';
  static const String keyUserName = 'asuhkita_user_name';
  static const String keyUserEmail = 'asuhkita_user_email';
  static const String keyBiometricEnabled = 'asuhkita_biometric_enabled';

  // Kunci enkripsi AES-256 (32 karakter string) untuk mengamankan data lokal sensitif (misal nomor HP)
  static const String aesSecretKey = 'AsuhKitaSecureKey2026SuperSafe32'; 
}
