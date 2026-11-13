import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/features/auth/domain/usecases/login.dart';

/// State of the login screen: busy while the request runs, and why the last
/// attempt did not work.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._login, required this._session});

  final Login _login;
  final SessionController _session;

  bool _busy = false;
  bool _missingFields = false;
  Failure? _failure;
  bool _disposed = false;

  bool get busy => _busy;

  /// The e-mail or the password was left empty (no request was made).
  bool get missingFields => _missingFields;

  /// Why the last request failed, or `null`. On this screen an
  /// `UnauthorizedFailure` means wrong e-mail or password.
  Failure? get failure => _failure;

  Future<void> submit({required String email, required String password}) async {
    if (_busy) return;
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      _missingFields = true;
      _failure = null;
      _notify();
      return;
    }

    _busy = true;
    _missingFields = false;
    _failure = null;
    _notify();

    final result = await _login(email: cleanEmail, password: password);
    _busy = false;
    final failure = result.failureOrNull;
    if (failure == null) {
      // The router leaves this screen as soon as the session opens.
      _session.onLoggedIn();
    } else {
      _failure = failure;
    }
    _notify();
  }

  /// Hides the last error, for example when the person starts typing again.
  void clearError() {
    if (_failure == null && !_missingFields) return;
    _failure = null;
    _missingFields = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
