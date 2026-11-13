import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/storage/session_token_store.dart';

/// Whether somebody is logged in. The router listens to it to choose between
/// the login screen and the tabs.
///
/// A token in the secure storage means "logged in". When the API rejects the
/// token, the auth interceptor clears it and tells [SessionExpiredNotifier];
/// this controller then turns to "logged out" and remembers that the session
/// expired, so the login screen can say so.
class SessionController extends ChangeNotifier {
  SessionController({
    required this._tokenStore,
    required this._expiredNotifier,
  });

  final SessionTokenStore _tokenStore;
  final SessionExpiredNotifier _expiredNotifier;

  StreamSubscription<void>? _subscription;
  bool _isLoggedIn = false;
  bool _sessionExpired = false;

  bool get isLoggedIn => _isLoggedIn;

  /// True when the last session ended because the API rejected the token.
  bool get sessionExpired => _sessionExpired;

  /// Reads the stored token and starts listening for an expired session. Call
  /// once at startup, before the router is built.
  Future<void> restore() async {
    final token = await _tokenStore.read();
    _isLoggedIn = token != null && token.isNotEmpty;
    _subscription ??= _expiredNotifier.stream.listen((_) => _onExpired());
    notifyListeners();
  }

  /// The token is already saved: marks the session as open.
  void onLoggedIn() {
    _expiredNotifier.reset();
    _isLoggedIn = true;
    _sessionExpired = false;
    notifyListeners();
  }

  /// The token is already cleared: marks the session as closed.
  void onLoggedOut() {
    _isLoggedIn = false;
    _sessionExpired = false;
    notifyListeners();
  }

  void _onExpired() {
    _isLoggedIn = false;
    _sessionExpired = true;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
