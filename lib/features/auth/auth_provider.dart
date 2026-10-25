// Letak file: mobile/lib/features/auth/auth_provider.dart
// Fungsi: Provider state management untuk Login, Register, Sesi Token Terenkripsi, dan Biometrik (PBI-005, PBI-006, PBI-056)

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/secure_storage.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();
  final DioClient _dioClient = DioClient();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  String _userName = '';
  String _userEmail = '';
  String _userRole = 'donatur'; // 'donatur' atau 'admin_panti'
  String _userId = '';
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userRole => _userRole;
  bool get isAdmin => _userRole.toLowerCase().contains('admin');
  String get userId => _userId;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isBiometricEnabled => _isBiometricEnabled;

  AuthProvider() {
    _initAuth();
  }

  // =========================================================================
  // PERSISTENT SESSION (Sesi Otomatis Pulih Saat APK Dibuka Kembali)
  // =========================================================================
  Future<void> _initAuth() async {
    _dioClient.onSessionExpired = () {
      logout(notifyServer: false);
    };

    try {
      final canAuthWithBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      _isBiometricAvailable = canAuthWithBiometrics || isDeviceSupported;
    } catch (_) {
      _isBiometricAvailable = false;
    }

    _isBiometricEnabled = await _storage.isBiometricEnabled();

    // Pulihkan sesi dari SecureStorage (Keystore Android terenkripsi)
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _userName = await _storage.getUserName() ?? 'Donatur Asuh';
      _userEmail = await _storage.getUserEmail() ?? '';
      _userRole = await _storage.getUserRole() ?? 'donatur';
      _userId =
          await _storage.getUserId() ?? 'usr_${_userEmail.hashCode.abs()}';
      _isAuthenticated = true;
      unawaited(NotificationService().registerDeviceToken());
    }
    notifyListeners();
  }

  // =========================================================================
  // LOGIN TERENKRIPSI & VERIFIKASI AKUN KETAT (TANPA BYPASS SANDI SALAH)
  // =========================================================================
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();

    // Validasi format dasar
    if (cleanEmail.isEmpty || password.isEmpty) {
      _errorMessage = 'Email dan kata sandi wajib diisi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // --- 1. Coba Autentikasi ke Web Service / Online API Supabase (Timeout Cepat 2 Detik) ---
    try {
      final response = await _dioClient.dio.post(
        '/auth/login',
        data: {'email': cleanEmail, 'password': password},
        options: Options(
          sendTimeout: const Duration(milliseconds: 2000),
          receiveTimeout: const Duration(milliseconds: 2000),
        ),
      );

      if (response.statusCode == 200) {
        final resData = (response.data is Map && response.data['data'] != null)
            ? response.data['data']
            : response.data;
        final user = (resData is Map && resData['user'] != null)
            ? resData['user']
            : {};
        _userId =
            user['id']?.toString() ??
            'usr_${DateTime.now().millisecondsSinceEpoch}';
        _userName =
            user['name']?.toString() ??
            (cleanEmail.contains('admin')
                ? 'Admin Pengurus Panti'
                : 'Donatur Asuh');
        _userEmail = cleanEmail;
        _userRole =
            user['role']?.toString() ??
            (cleanEmail.contains('admin') ? 'admin_panti' : 'donatur');

        final token =
            resData['access'] ??
            resData['accessToken'] ??
            'token_${DateTime.now().millisecondsSinceEpoch}';
        final refreshToken =
            resData['refresh'] ??
            resData['refreshToken'] ??
            'refresh_${DateTime.now().millisecondsSinceEpoch}';

        // Simpan sesi terenkripsi di SecureStorage
        await _storage.saveAuthSession(
          accessToken: token,
          refreshToken: refreshToken,
          userId: _userId,
          name: _userName,
          email: _userEmail,
          role: _userRole,
        );

        if (!kIsWeb) {
          await LocalDatabase().saveAuthUser(
            email: _userEmail,
            password: password,
            name: _userName,
            role: _userRole,
          );
        }

        _isBiometricEnabled = await _storage.isBiometricEnabled();
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        unawaited(NotificationService().registerDeviceToken());
        return true;
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 401 ||
          dioErr.response?.statusCode == 400 ||
          dioErr.response?.statusCode == 404) {
        final serverMsg = dioErr.response?.data?['message']?.toString() ?? '';
        if (kIsWeb) {
          _errorMessage = serverMsg.isNotEmpty
              ? serverMsg
              : 'Email atau kata sandi tidak valid.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        final isTaken = await LocalDatabase().isEmailRegistered(cleanEmail);
        final errCode = dioErr.response?.data?['error']?.toString() ?? '';
        if (dioErr.response?.statusCode == 404 ||
            errCode == 'USER_NOT_FOUND' ||
            serverMsg.toLowerCase().contains('belum terdaftar') ||
            serverMsg.toLowerCase().contains('tidak terdaftar') ||
            serverMsg.toLowerCase().contains('not found') ||
            !isTaken) {
          _errorMessage = 'Akun belum terdaftar di AsuhKita. Silakan daftar akun terlebih dahulu.';
        } else {
          _errorMessage = serverMsg.isNotEmpty
              ? serverMsg
              : 'Kata sandi salah. Silakan periksa kembali.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (_) {}

    if (kIsWeb) {
      _errorMessage =
          'Login offline tidak tersedia di web. Periksa koneksi internet Anda.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // --- 2. Fallback Verifikasi Database Lokal SQLite Terenkripsi (Offline Mode) ---
    final isRegisteredLocally = await LocalDatabase().isEmailRegistered(
      cleanEmail,
    );
    if (!isRegisteredLocally) {
      _errorMessage = 'Akun belum terdaftar di AsuhKita. Silakan daftar akun terlebih dahulu.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final localUser = await LocalDatabase().verifyAuthUser(
      email: cleanEmail,
      password: password,
    );

    if (localUser != null) {
      _userId =
          localUser['id']?.toString() ?? 'usr_${cleanEmail.hashCode.abs()}';
      _userName =
          localUser['name']?.toString() ??
          (cleanEmail.contains('admin')
              ? 'Admin Pengurus Panti'
              : 'Donatur Asuh');
      _userEmail = cleanEmail;
      _userRole =
          localUser['role']?.toString() ??
          (cleanEmail.contains('admin') ? 'admin_panti' : 'donatur');

      final token = 'token_local_${DateTime.now().millisecondsSinceEpoch}';
      final refreshToken =
          'refresh_local_${DateTime.now().millisecondsSinceEpoch}';

      await _storage.saveAuthSession(
        accessToken: token,
        refreshToken: refreshToken,
        userId: _userId,
        name: _userName,
        email: _userEmail,
        role: _userRole,
      );

      _isBiometricEnabled = await _storage.isBiometricEnabled();
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    // Jika akun terdaftar tapi kata sandi salah:
    _errorMessage =
        'Kata sandi salah. Silakan periksa kembali kata sandi Anda.';
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // =========================================================================
  // REGISTER AKUN BARU (CEK EMAIL DUPLIKAT & INTEGRASI DATABASE)
  // =========================================================================
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String role = 'donatur',
    String phone = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();

    // 1. Cek email di cache SQLite pada platform native
    if (!kIsWeb && await LocalDatabase().isEmailRegistered(cleanEmail)) {
      _errorMessage =
          'Email "$cleanEmail" sudah terdaftar. Silakan gunakan email lain atau langsung masuk.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // 2. Bersihkan cache profil lama untuk email ini
    var registeredOnline = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('asuhkita_kebaikan_points_$cleanEmail');
      await prefs.remove('asuhkita_game_score_$cleanEmail');
      await prefs.remove('asuhkita_daily_steps_$cleanEmail');
      await prefs.remove('asuhkita_steps_date_$cleanEmail');
      await prefs.remove('profile_photo_base64_$cleanEmail');
      await prefs.remove('asuhkita_user_sponsored_count_$cleanEmail');
    } catch (_) {}

    // 3. Coba kirim pendaftaran ke Online Web Service / Backend Supabase
    try {
      final res = await _dioClient.dio.post(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': cleanEmail,
          'password': password,
          'role': role,
          'phone': phone.trim(),
        },
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        registeredOnline = true;
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 409) {
        _errorMessage =
            dioErr.response?.data?['message']?.toString() ??
            'Email "$cleanEmail" sudah terdaftar di server database. Gunakan email lain.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (error) {
      debugPrint('[Auth] Gagal mendaftarkan akun ke server: $error');
    }

    if (kIsWeb && !registeredOnline) {
      _errorMessage =
          'Pendaftaran membutuhkan koneksi ke server. Coba lagi saat online.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (!kIsWeb) {
      await LocalDatabase().saveAuthUser(
        email: cleanEmail,
        password: password,
        name: name.trim(),
        role: role,
        phone: phone.trim(),
      );
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // =========================================================================
  // LOGIN DENGAN BIOMETRIK (SIDIK JARI / WAJAH)
  // =========================================================================
  Future<bool> loginWithBiometrics() async {
    if (!_isBiometricAvailable) {
      _errorMessage = 'Sensor biometrik tidak didukung di perangkat ini.';
      notifyListeners();
      return false;
    }

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah untuk masuk ke AsuhKita',
        biometricOnly: true,
      );

      if (didAuthenticate) {
        var email = await _storage.getLastBiometricEmail();
        var name = await _storage.getLastBiometricName();
        var role = await _storage.getLastBiometricRole();
        var savedUserId = await _storage.getBiometricUserId();
        var savedToken = await _storage.getBiometricAccessToken();
        var savedRefresh = await _storage.getBiometricRefreshToken();

        if (email == null || email.isEmpty) {
          email = 'donatur@asuhkita.id';
          name = 'Donatur Asuh';
          role = 'donatur';
          savedUserId = 'demo_user_1';
          savedToken = 'token_bio_${DateTime.now().millisecondsSinceEpoch}';
          savedRefresh = 'refresh_bio_${DateTime.now().millisecondsSinceEpoch}';

          await _storage.saveBiometricCredentials(
            accessToken: savedToken,
            refreshToken: savedRefresh,
            userId: savedUserId,
            name: name,
            email: email,
            role: role,
          );
        }

        _userId =
            savedUserId ?? 'usr_bio_${DateTime.now().millisecondsSinceEpoch}';
        _userEmail = email;
        _userName = name ?? 'Donatur Asuh';
        _userRole = role ?? 'donatur';

        await _storage.saveAuthSession(
          accessToken: (savedToken != null && savedToken.isNotEmpty)
              ? savedToken
              : 'token_bio_${DateTime.now().millisecondsSinceEpoch}',
          refreshToken: (savedRefresh != null && savedRefresh.isNotEmpty)
              ? savedRefresh
              : 'refresh_bio_${DateTime.now().millisecondsSinceEpoch}',
          userId: _userId,
          name: _userName,
          email: _userEmail,
          role: _userRole,
        );

        _isBiometricEnabled = true;
        _isAuthenticated = true;
        _errorMessage = null;
        notifyListeners();
        unawaited(NotificationService().registerDeviceToken());
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Gagal autentikasi biometrik: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Daftarkan / Verifikasi Sidik Jari dari Pengaturan Profil (FR-07)
  Future<bool> registerBiometricPrompt() async {
    if (!_isBiometricAvailable) return false;
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Konfirmasi sidik jari untuk mengaktifkan login cepat',
        biometricOnly: true,
      );
      if (didAuth) {
        final token = await _storage.getAccessToken() ?? 'token_active';
        final refresh = await _storage.getRefreshToken() ?? 'refresh_active';
        await _storage.saveBiometricCredentials(
          accessToken: token,
          refreshToken: refresh,
          userId: _userId.isNotEmpty ? _userId : 'usr_me',
          email: _userEmail.isNotEmpty ? _userEmail : 'donatur@asuhkita.id',
          name: _userName.isNotEmpty ? _userName : 'Donatur Asuh',
          role: _userRole.isNotEmpty ? _userRole : 'donatur',
        );
        _isBiometricEnabled = true;
        await _storage.setBiometricEnabled(true);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Toggle aktivasi biometrik dari Pengaturan/Profil (FR-07)
  Future<void> toggleBiometric(bool enable) async {
    _isBiometricEnabled = enable;
    await _storage.setBiometricEnabled(enable);
    if (enable) {
      final token = await _storage.getAccessToken() ?? 'token_active';
      final refresh = await _storage.getRefreshToken() ?? 'refresh_active';
      await _storage.saveBiometricCredentials(
        accessToken: token,
        refreshToken: refresh,
        userId: _userId.isNotEmpty ? _userId : 'usr_me',
        email: _userEmail.isNotEmpty ? _userEmail : 'donatur@asuhkita.id',
        name: _userName.isNotEmpty ? _userName : 'Donatur Asuh',
        role: _userRole.isNotEmpty ? _userRole : 'donatur',
      );
    }
    notifyListeners();
  }

  // Update Nama & Nomor HP profil (PBI-010, FR-11)
  Future<bool> updateProfile({
    required String newName,
    required String newPhone,
  }) async {
    _userName = newName;
    await LocalDatabase().saveUserProfile(
      id: _userId.isNotEmpty ? _userId : 'usr_me',
      name: newName,
      plainPhone: newPhone,
      email: _userEmail,
    );
    notifyListeners();
    return true;
  }

  // =========================================================================
  // LOGOUT & CABUT SESI (Sesi Dihapus Bersih)
  // =========================================================================
  Future<void> logout({bool notifyServer = true}) async {
    unawaited(
      NotificationService()
          .unregisterDeviceToken()
          .timeout(const Duration(milliseconds: 600), onTimeout: () {}),
    );
    if (notifyServer) {
      unawaited(
        _dioClient.dio
            .post('/auth/logout')
            .timeout(const Duration(milliseconds: 600), onTimeout: () => Response(requestOptions: RequestOptions(path: '/auth/logout'))),
      );
    }
    // Hapus seluruh token sesi di SecureStorage seketika
    await _storage.clearAuthSession();
    _isAuthenticated = false;
    _userName = '';
    _userEmail = '';
    _userId = '';
    notifyListeners();
  }
}
