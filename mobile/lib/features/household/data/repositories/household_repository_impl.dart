import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/data/datasources/household_remote_data_source.dart';
import 'package:mobile/features/household/data/mappers/member_mapper.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
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
}
