import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/entries/data/datasources/entries_remote_data_source.dart';
import 'package:mobile/features/entries/data/mappers/financial_entry_mapper.dart';
import 'package:mobile/features/entries/domain/entities/entry_draft.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/entries/domain/repositories/entries_repository.dart';

class EntriesRepositoryImpl implements EntriesRepository {
  const EntriesRepositoryImpl(this._remote);

  final EntriesRemoteDataSource _remote;

  @override
  Future<Result<PageResult<FinancialEntry>>> search({
    required int offset,
    required int limit,
    String? userId,
    EntryStatus? status,
    DateTime? referenceMonth,
    EntryFilters filters = const EntryFilters(),
    String search = '',
    String? transactionId,
  }) async {
    final result = await _remote.search(
      offset: offset,
      limit: limit,
      userId: userId,
      status: status,
      referenceMonth: referenceMonth,
      filters: filters,
      search: search,
      transactionId: transactionId,
    );
    return result.map(
      (page) => PageResult<FinancialEntry>(
        items: [for (final dto in page.items) dto.toEntity()],
        limit: page.limit,
        offset: page.offset,
        total: page.total,
      ),
    );
  }

  @override
  Future<Result<FinancialEntry>> create(EntryDraft draft) async =>
      (await _remote.create(draft)).map((dto) => dto.toEntity());

  @override
  Future<Result<FinancialEntry>> update(String id, EntryDraft draft) async =>
      (await _remote.update(id, draft)).map((dto) => dto.toEntity());

  @override
  Future<Result<FinancialEntry>> setStatus(
    String id,
    EntryStatus status,
  ) async => (await _remote.setStatus(id, status)).map((dto) => dto.toEntity());

  @override
  Future<Result<void>> delete(String id) => _remote.delete(id);
}
