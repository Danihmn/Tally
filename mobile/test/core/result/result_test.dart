import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';

void main() {
  group('Result', () {
    test('success_exposes_value_and_no_failure', () {
      const result = Result.success(3);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 3);
      expect(result.failureOrNull, isNull);
    });

    test('failure_exposes_failure_and_no_value', () {
      const result = Result<int>.failure(NotFoundFailure());
      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, const NotFoundFailure());
    });

    test('map_changes_the_value_and_keeps_a_failure', () {
      expect(const Result.success(2).map((v) => v * 2).valueOrNull, 4);
      const failed = Result<int>.failure(NetworkFailure());
      expect(failed.map((v) => v * 2).failureOrNull, const NetworkFailure());
    });

    test('flat_map_chains_and_stops_at_the_first_failure', () {
      final chained = const Result.success(2)
          .flatMap((v) => const Result<int>.failure(ConflictFailure()));
      expect(chained.failureOrNull, const ConflictFailure());
    });

    test('when_runs_the_branch_that_matches', () {
      const ok = Result.success('a');
      const bad = Result<String>.failure(TimeoutFailure());
      expect(ok.when(success: (v) => v, failure: (_) => 'x'), 'a');
      expect(bad.when(success: (v) => v, failure: (_) => 'x'), 'x');
    });
  });
}
