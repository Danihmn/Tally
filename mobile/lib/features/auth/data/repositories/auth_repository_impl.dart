import 'dart:async';

import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile/features/auth/data/models/token_dto.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// Logs in through the API and keeps the tokens in the secure storage.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this._remote, required this._tokenStore});

  final AuthRemoteDataSource _remote;
  final SessionTokenStore _tokenStore;

  @override
  Future<Result<void>> login({
    required String email,
    required String password,
  }) async {
    final result = await _remote.login(email: email, password: password);
    return result.when<Future<Result<void>>>(
      success: (TokenDto dto) async {
        await _tokenStore.saveTokens(
          accessToken: dto.accessToken,
          refreshToken: dto.refreshToken,
        );
        return const Result<void>.success(null);
      },
      failure: (failure) async => Result<void>.failure(failure),
    );
  }

  /// Forgets the tokens at once, then asks the API to revoke the refresh token.
  /// The revoke is best effort: the user is logged out even when it fails.
  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStore.readRefresh();
    await _tokenStore.clear();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      unawaited(_remote.logout(refreshToken: refreshToken));
    }
  }
}
