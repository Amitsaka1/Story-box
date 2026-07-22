import 'package:dio/dio.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/token_storage.dart';
import 'package:my_app/models/user_model.dart';

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
    String honeypot = '',
    required int formRenderedAt,
  }) async {
    try {
      await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
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
    String honeypot = '',
    required int formRenderedAt,
  }) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
        'honeypot': honeypot,
        'formRenderedAt': formRenderedAt,
      });
      await _tokenStorage.saveTokens(
        accessToken: res.data['accessToken'],
        refreshToken: res.data['refreshToken'],
      );
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

  Future<void> deleteAccount({required String password}) async {
    try {
      await _dio.delete('/auth/me', data: {'password': password});
    } on DioException catch (e) {
      throw _extractError(e, 'Could not delete account.');
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    try {
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } on DioException catch (_) {
    } finally {
      await _tokenStorage.clear();
    }
  }
}
