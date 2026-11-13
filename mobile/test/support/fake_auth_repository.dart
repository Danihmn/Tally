import 'dart:async';

import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// [AuthRepository] that answers with what the test sets, and records the
/// calls. Set [pending] to hold the answer until the test completes it.
class FakeAuthRepository implements AuthRepository {
  Result<void> answer = const Result<void>.success(null);
  Completer<Result<void>>? pending;
  final List<({String email, String password})> logins = [];
  int logouts = 0;

  @override
  Future<Result<void>> login({
    required String email,
    required String password,
  }) {
    logins.add((email: email, password: password));
    return pending?.future ?? Future.value(answer);
  }

  @override
  Future<void> logout() async => logouts++;
}
