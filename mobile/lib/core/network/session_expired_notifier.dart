import 'dart:async';

/// Tells the app that the API rejected the token (401 outside of login).
///
/// The session layer listens and sends the user to the login screen. It fires
/// once per session: several requests failing at the same time must not cause
/// several redirects (a redirect loop). Call [reset] after a new login.
class SessionExpiredNotifier {
  final _controller = StreamController<void>.broadcast();
  bool _notified = false;

  Stream<void> get stream => _controller.stream;

  void notifyExpired() {
    if (_notified) return;
    _notified = true;
    _controller.add(null);
  }

  void reset() => _notified = false;

  Future<void> dispose() => _controller.close();
}
