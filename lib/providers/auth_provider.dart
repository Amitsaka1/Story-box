import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_events.dart';
import 'auth_service.dart';
import 'token_storage.dart';
import 'user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _forceLogoutSub = AuthEvents.instance.onForceLogout.listen(_handleForceLogout);
  }

  final _authService = AuthService();
  final _tokenStorage = TokenStorage();
  late final StreamSubscription<ForceLogoutReason> _forceLogoutSub;

  UserModel? currentUser;
  bool isLoading = false;
  String? lastError;

  // Set when the backend force-logs-out this session, so the UI can show
  // *why* (e.g. "signed in on another device") instead of a silent kick.
  ForceLogoutReason? lastForceLogoutReason;

  bool get isLoggedIn => currentUser != null;

  Future<void> tryRestoreSession() async {
    final hasTokens = await _tokenStorage.hasTokens();
    if (!hasTokens) return;
    isLoading = true;
    notifyListeners();
    try {
      currentUser = await _authService.fetchMe();
    } catch (_) {
      currentUser = null;
      await _tokenStorage.clear();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    required String captchaToken,
  }) async {
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      currentUser = await _authService.login(
        username: username,
        password: password,
        captchaToken: captchaToken,
        formRenderedAt: DateTime.now().millisecondsSinceEpoch,
      );
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    lastError = null;
    try {
      await _authService.changePassword(currentPassword: currentPassword, newPassword: newPassword);
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser = null;
    notifyListeners();
  }

  void _handleForceLogout(ForceLogoutReason reason) {
    currentUser = null;
    lastForceLogoutReason = reason;
    notifyListeners();
  }

  @override
  void dispose() {
    _forceLogoutSub.cancel();
    super.dispose();
  }
}

