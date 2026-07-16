import 'package:dio/dio.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'user_model.dart';

/// Thin wrapper around every endpoint your backend exposes.
/// Throws a plain String (the backend's `error` message) on failure, so
/// screens can show it directly.
class AuthService {
  final _dio = ApiClient.instance.dio;
  final _tokenStorage = TokenStorage();

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return fallback;
  }

  Future<void> register({
    required String username,
    required String password,
    required String captchaToken,
    String honeypot = '',
    required int formRenderedAt,
  }) async {
    try {
      await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
        'captchaToken': captchaToken,
        'honeypot': honeypot,
        'formRenderedAt': formRenderedAt,
      });
    } on DioException catch (e) {
      throw _extractError(e, 'Could not create account.');
    }
  }

  Future<UserModel> login({
    required String username,
    required String password,
    required String captchaToken,
    String honeypot = '',
    required int formRenderedAt,
  }) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
        'captchaToken': captchaToken,
        'honeypot': honeypot,
        'formRenderedAt': formRenderedAt,
      });
      await _tokenStorage.saveTokens(
        accessToken: res.data['accessToken'],
        refreshToken: res.data['refreshToken'],
      );
      // /auth/login doesn't return createdAt, so fetch full profile right after
      return fetchMe();
    } on DioException catch (e) {
      throw _extractError(e, 'Invalid username or password.');
    }
  }

  Future<UserModel> fetchMe() async {
    try {
      final res = await _dio.get('/auth/me');
      return UserModel.fromJson(res.data);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load profile.');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      throw _extractError(e, 'Could not change password.');
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    try {
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } on DioException catch (_) {
      // even if the network call fails, still clear local tokens below --
      // no point leaving the device "logged in" locally if logout errored
    } finally {
      await _tokenStorage.clear();
    }
  }
}

