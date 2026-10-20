// Letak file: mobile/lib/core/dio_client.dart
// Fungsi: Klien HTTP Dio dengan Interceptor untuk otomatis menyisipkan Token JWT, Auto-Refresh Token, dan Auto-Logout (PBI-006)

import 'package:dio/dio.dart';
import 'constants.dart';
import 'secure_storage.dart';

typedef VoidCallback = void Function();

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  final SecureStorageService _storage = SecureStorageService();

  // Callback yang dipanggil saat sesi benar-benar berakhir/expired untuk navigasi kembali ke login
  VoidCallback? onSessionExpired;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Sisipkan Access Token jika ada
          final token = await _storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Tangani jika terjadi 401 Unauthorized (token kedaluwarsa)
          if (error.response?.statusCode == 401) {
            final refreshToken = await _storage.getRefreshToken();

            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                // Buat client terpisah agar tidak loop interceptor
                final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
                final response = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if (response.statusCode == 200 && response.data != null) {
                  final newAccessToken = response.data['access'] ?? response.data['accessToken'];
                  final newRefreshToken = response.data['refresh'] ?? response.data['refreshToken'] ?? refreshToken;

                  // Simpan token baru
                  final role = await _storage.getUserRole() ?? 'donatur';
                  final name = await _storage.getUserName() ?? '';
                  final email = await _storage.getUserEmail() ?? '';

                  await _storage.saveAuthSession(
                    accessToken: newAccessToken,
                    refreshToken: newRefreshToken,
                    userId: response.data['userId'] ?? '',
                    name: name,
                    email: email,
                    role: role,
                  );

                  // Ulangi request sebelumnya dengan token baru
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newAccessToken';

                  final clonedRequest = await dio.request(
                    opts.path,
                    options: Options(
                      method: opts.method,
                      headers: opts.headers,
                    ),
                    data: opts.data,
                    queryParameters: opts.queryParameters,
                  );

                  return handler.resolve(clonedRequest);
                }
              } catch (refreshErr) {
                // Refresh token gagal atau kedaluwarsa -> Sesi Habis -> Auto-Logout
                await _storage.clearAuthSession();
                onSessionExpired?.call();
                return handler.reject(error);
              }
            } else {
              // Tidak ada refresh token -> Auto-Logout
              await _storage.clearAuthSession();
              onSessionExpired?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
