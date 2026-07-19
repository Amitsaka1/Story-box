import 'package:dio/dio.dart';
import 'token_storage.dart';
import 'auth_events.dart';

/// EDIT THIS: your backend's base URL (Render/wherever you deployed it).
const String kApiBaseUrl = 'https://story-box-backend-yim1.onrender.com';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio.interceptors.add(_authInterceptor());
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  final _tokenStorage = TokenStorage();

  // Prevents multiple simultaneous requests from all trying to refresh
  // the token at once -- only one refresh call happens at a time, the
  // rest wait on the same in-flight future.
  Future<String?>? _refreshingFuture;

  Dio get dio => _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // /auth/login, /auth/register, /auth/refresh don't need a bearer token
        final isPublic = options.path.contains('/auth/login') ||
            options.path.contains('/auth/register') ||
            options.path.contains('/auth/refresh');
        if (!isPublic) {
          final token = await _tokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final response = error.response;
        final path = error.requestOptions.path;

        if (response?.statusCode != 401 || path.contains('/auth/refresh')) {
          // not a token problem, or the refresh call itself failed -- give up
          return handler.next(error);
        }

        // The backend sends a specific message when this token was
        // invalidated because the account logged in on ANOTHER device
        // (single-active-device enforcement). No point refreshing in
        // that case -- the whole session family was already revoked.
        final serverMessage = (response?.data is Map) ? response!.data['error']?.toString() ?? '' : '';
        if (serverMessage.toLowerCase().contains('another device')) {
          await _tokenStorage.clear();
          AuthEvents.instance.fireForceLogout(ForceLogoutReason.otherDevice);
          return handler.next(error);
        }

        // Otherwise: normal access-token expiry -- try to refresh once,
        // then retry the original request.
        try {
          final newAccessToken = await _refreshAccessToken();
          if (newAccessToken == null) {
            await _tokenStorage.clear();
            AuthEvents.instance.fireForceLogout(ForceLogoutReason.sessionExpired);
            return handler.next(error);
          }

          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          await _tokenStorage.clear();
          AuthEvents.instance.fireForceLogout(ForceLogoutReason.sessionExpired);
          return handler.next(error);
        }
      },
    );
  }

  Future<String?> _refreshAccessToken() {
    // single-flight: if a refresh is already happening, reuse its future
    _refreshingFuture ??= _doRefresh();
    return _refreshingFuture!.whenComplete(() => _refreshingFuture = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      // separate Dio call (not via this._dio) so it doesn't recurse
      // through the same interceptor
      final plainDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
      final res = await plainDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final newAccess = res.data['accessToken'] as String;
      final newRefresh = res.data['refreshToken'] as String;
      await _tokenStorage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      return newAccess;
    } catch (_) {
      return null;
    }
  }
}
