import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile/features/auth/data/models/token_dto.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// Logs in through the API and keeps the token in the secure storage.
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
        await _tokenStore.save(dto.accessToken);
        return const Result<void>.success(null);
      },
      failure: (failure) async => Result<void>.failure(failure),
    );
  }

  @override
  Future<void> logout() => _tokenStore.clear();
}
