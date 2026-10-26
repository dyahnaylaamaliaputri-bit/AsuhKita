


import 'package:dio/dio.dart';
import 'constants.dart';
import 'secure_storage.dart';

typedef VoidCallback = void Function();

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  final SecureStorageService _storage = SecureStorageService();


  VoidCallback? onSessionExpired;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 2500),
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

          final token = await _storage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {

          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;

            if (path.contains('/auth/login') || path.contains('/auth/register')) {
              return handler.next(error);
            }

            final refreshToken = await _storage.getRefreshToken();

            if (refreshToken != null &&
                refreshToken.isNotEmpty &&
                !refreshToken.startsWith('refresh_demo_') &&
                !refreshToken.startsWith('refresh_bio_')) {
              try {
                final refreshDio = Dio(BaseOptions(
                  baseUrl: dio.options.baseUrl,
                  connectTimeout: const Duration(milliseconds: 1500),
                  receiveTimeout: const Duration(milliseconds: 2000),
                ));
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


                  final role = await _storage.getUserRole() ?? 'donatur';
                  final name = await _storage.getUserName() ?? '';
                  final email = await _storage.getUserEmail() ?? '';

                  await _storage.saveAuthSession(
                    accessToken: newAccessToken,
                    refreshToken: newRefreshToken,
                    userId: await _storage.getUserId() ?? 'usr_active',
                    name: name,
                    email: email,
                    role: role,
                  );


                  error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                  final retryResponse = await dio.fetch(error.requestOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (_) {

                await _storage.clearAuthSession();
                onSessionExpired?.call();
              }
            } else {
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
