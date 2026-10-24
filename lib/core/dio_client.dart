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
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
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
          // Jangan buang waktu looping ke candidate URLs saat login/register agar proses loading cepat
          final reqPath = error.requestOptions.path;
          if (reqPath.contains('/auth/login') || reqPath.contains('/auth/register')) {
            return handler.next(error);
          }

          // Coba fallback ke kandidat baseUrl lain jika gagal koneksi/timeout
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout) {
            for (final candidate in AppConstants.candidateBaseUrls) {
              if (candidate != dio.options.baseUrl) {
                try {
                  final retryOptions = Options(
                    method: error.requestOptions.method,
                    headers: error.requestOptions.headers,
                    responseType: error.requestOptions.responseType,
                    contentType: error.requestOptions.contentType,
                  );
                  final path = error.requestOptions.path;
                  final newUrl = candidate + (path.startsWith('/') ? path : '/$path');
                  final fallbackDio = Dio(BaseOptions(
                    connectTimeout: const Duration(seconds: 3),
                    receiveTimeout: const Duration(seconds: 3),
                  ));
                  final response = await fallbackDio.request(
                    newUrl,
                    data: error.requestOptions.data,
                    queryParameters: error.requestOptions.queryParameters,
                    options: retryOptions,
                  );
                  dio.options.baseUrl = candidate;
                  return handler.resolve(response);
                } catch (_) {}
              }
            }
          }

          // Tangani jika terjadi 401 Unauthorized (token kedaluwarsa)
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            // Jika 401 terjadi saat login atau register, teruskan error ke UI tanpa auto-logout
            if (path.contains('/auth/login') || path.contains('/auth/register')) {
              return handler.next(error);
            }

            final refreshToken = await _storage.getRefreshToken();

            if (refreshToken != null &&
                refreshToken.isNotEmpty &&
                !refreshToken.startsWith('refresh_demo_') &&
                !refreshToken.startsWith('refresh_bio_')) {
              try {
                // Buat client terpisah agar tidak loop interceptor
                final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
                final response = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if (response.statusCode == 200 && response.data != null) {
                  final resData = (response.data is Map && response.data['data'] != null)
                      ? response.data['data']
                      : response.data;
                  final newAccessToken = resData['access'] ?? resData['accessToken'];
                  final newRefreshToken = resData['refresh'] ?? resData['refreshToken'] ?? refreshToken;

                  // Simpan token baru
                  final role = await _storage.getUserRole() ?? 'donatur';
                  final name = await _storage.getUserName() ?? '';
                  final email = await _storage.getUserEmail() ?? '';

                  await _storage.saveAuthSession(
                    accessToken: newAccessToken,
                    refreshToken: newRefreshToken,
                    userId: resData['userId'] ?? '',
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
              } catch (_) {
                // Jangan tendang keluar paksa jika masih bisa fallback ke mode offline
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
