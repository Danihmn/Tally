import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/data/datasources/household_remote_data_source.dart';
import 'package:mobile/features/household/data/mappers/member_mapper.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

class HouseholdRepositoryImpl implements HouseholdRepository {
  const HouseholdRepositoryImpl(this._remote);

  final HouseholdRemoteDataSource _remote;

  @override
  Future<Result<Member>> getMe() async =>
      (await _remote.getMe()).map((dto) => dto.toEntity());

  @override
  Future<Result<List<Member>>> getUsers() async => (await _remote.getUsers())
      .map((dtos) => [for (final dto in dtos) dto.toEntity()]);

  @override
  Future<Result<Member>> createUser(UserDraft draft) async =>
      (await _remote.createUser(draft)).map((dto) => dto.toEntity());

  @override
  Future<Result<Member>> updateUser(String id, UserChanges changes) async =>
      (await _remote.updateUser(id, changes)).map((dto) => dto.toEntity());

  @override
  Future<Result<void>> updatePluggyCredentials(
    String id,
    PluggyCredentials credentials,
  ) => _remote.updatePluggyCredentials(id, credentials);

  @override
  Future<Result<void>> updatePassword(String id, String password) =>
      _remote.updatePassword(id, password);
}
