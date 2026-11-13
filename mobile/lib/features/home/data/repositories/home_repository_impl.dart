import 'package:decimal/decimal.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/home/data/datasources/home_remote_data_source.dart';
import 'package:mobile/features/home/data/mappers/home_mappers.dart';
import 'package:mobile/features/home/domain/entities/daily_amount.dart';
import 'package:mobile/features/home/domain/entities/date_range.dart';
import 'package:mobile/features/home/domain/entities/entry_type.dart';
import 'package:mobile/features/home/domain/entities/reconciliation_counts.dart';
import 'package:mobile/features/home/domain/entities/top_expense.dart';
import 'package:mobile/features/home/domain/entities/upcoming_entry.dart';
import 'package:mobile/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._remote);

  final HomeRemoteDataSource _remote;

  @override
  Future<Result<Decimal>> totalExpenses(
    DateRange range, {
    String? userId,
  }) async =>
      (await _remote.totalExpenses(range, userId: userId)).map((d) => d.value);

  @override
  Future<Result<Decimal>> totalRevenues(
    DateRange range, {
    String? userId,
  }) async =>
      (await _remote.totalRevenues(range, userId: userId)).map((d) => d.value);

  @override
  Future<Result<Decimal>> balance(DateRange range, {String? userId}) async =>
      (await _remote.balance(range, userId: userId)).map((d) => d.value);

  @override
  Future<Result<Decimal>> averageDailyExpenses(
    DateRange range, {
    String? userId,
  }) async => (await _remote.averageDailyExpenses(
    range,
    userId: userId,
  )).map((d) => d.value);

  @override
  Future<Result<List<DailyAmount>>> dailyExpenses(
    DateRange range, {
    String? userId,
  }) async => (await _remote.dailyExpenses(
    range,
    userId: userId,
  )).map((dtos) => [for (final dto in dtos) dto.toEntity()]);

  @override
  Future<Result<List<TopExpense>>> topExpenses(
    DateRange range, {
    required int limit,
    String? userId,
  }) async => (await _remote.topExpenses(
    range,
    limit: limit,
    userId: userId,
  )).map((dtos) => [for (final dto in dtos) dto.toEntity()]);

  @override
  Future<Result<Decimal>> totalPlanned(
    DateRange months,
    EntryType type, {
    String? userId,
  }) async => (await _remote.totalPlanned(
    months,
    type,
    userId: userId,
  )).map((d) => d.value);

  @override
  Future<Result<Decimal>> totalReconciled(
    DateRange months,
    EntryType type, {
    String? userId,
  }) async => (await _remote.totalReconciled(
    months,
    type,
    userId: userId,
  )).map((d) => d.value);

  @override
  Future<Result<ReconciliationCounts>> reconciliationCounts(
    DateRange months,
    EntryType type, {
    String? userId,
  }) async => (await _remote.reconciliationCounts(
    months,
    type,
    userId: userId,
  )).map((dto) => dto.toEntity());

  @override
  Future<Result<List<UpcomingEntry>>> upcomingEntries({
    required int days,
    String? userId,
  }) async => (await _remote.upcomingEntries(
    days: days,
    userId: userId,
  )).map((dtos) => [for (final dto in dtos) dto.toEntity()]);
}
