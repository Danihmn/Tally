import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/recurrences/data/datasources/recurrences_remote_data_source.dart';
import 'package:mobile/features/recurrences/data/mappers/recurrence_mapper.dart';
import 'package:mobile/features/recurrences/domain/entities/recurrence.dart';
import 'package:mobile/features/recurrences/domain/repositories/recurrences_repository.dart';

class RecurrencesRepositoryImpl implements RecurrencesRepository {
  const RecurrencesRepositoryImpl(this._remote);

  final RecurrencesRemoteDataSource _remote;

  @override
  Future<Result<List<Recurrence>>> list() async => (await _remote.list()).map(
    (items) => [for (final dto in items) dto.toEntity()],
  );

  @override
  Future<Result<Recurrence>> create(RecurrenceDraft draft) async =>
      (await _remote.create(draft)).map((dto) => dto.toEntity());

  @override
  Future<Result<Recurrence>> update(String id, RecurrenceDraft draft) async =>
      (await _remote.update(id, draft)).map((dto) => dto.toEntity());

  @override
  Future<Result<void>> delete(String id) => _remote.delete(id);

  @override
  Future<Result<ProvisionResult>> provisionNextMonth() async =>
      (await _remote.provisionNextMonth()).map((dto) => dto.toEntity());
}
