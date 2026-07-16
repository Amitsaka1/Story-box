import 'dart:async';

enum ForceLogoutReason {
  otherDevice, // backend rejected token because another device logged in
  sessionExpired, // refresh also failed -- normal expiry
}

/// Broadcasts "you have been logged out by the backend" events.
/// api_client.dart fires these; auth_provider.dart listens and clears
/// local state; your root widget listens and navigates to the login screen.
class AuthEvents {
  AuthEvents._();
  static final AuthEvents instance = AuthEvents._();

  final _controller = StreamController<ForceLogoutReason>.broadcast();

  Stream<ForceLogoutReason> get onForceLogout => _controller.stream;

  void fireForceLogout(ForceLogoutReason reason) {
    _controller.add(reason);
  }

  void dispose() {
    _controller.close();
  }
}
