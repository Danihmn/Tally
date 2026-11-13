import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/paginated_view_model.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';

class _Vm extends ChangeNotifier with PaginatedViewModel<int> {
  _Vm(this.onFetch) : size = 2;

  final Future<Result<PageResult<int>>> Function(int offset, int limit) onFetch;
  final int size;

  @override
  int get pageSize => size;

  @override
  Future<Result<PageResult<int>>> fetchPage({
    required int offset,
    required int limit,
  }) => onFetch(offset, limit);
}

Result<PageResult<int>> _page(
  List<int> items,
  int offset, {
  int? total,
  int limit = 2,
}) => Result.success(
  PageResult(items: items, limit: limit, offset: offset, total: total),
);

void main() {
  group('PaginatedViewModel', () {
    test('load_shows_loading_then_success', () async {
      final vm = _Vm((o, l) async => _page([1, 2], o, total: 3));
      final states = <UiState<List<int>>>[];
      vm.addListener(() => states.add(vm.state));

      await vm.load();

      expect(states.first, isA<UiLoading<List<int>>>());
      expect((vm.state as UiSuccess<List<int>>).data, [1, 2]);
      expect(vm.hasMore, isTrue);
    });

    test('total_is_what_the_api_says_and_is_null_without_it', () async {
      final withTotal = _Vm((o, l) async => _page([1, 2], o, total: 7));
      await withTotal.load();
      final plain = _Vm((o, l) async => _page([1, 2], o));
      await plain.load();

      expect(withTotal.total, 7);
      expect(plain.total, isNull);
    });

    test('total_follows_the_last_page_and_is_cleared_by_a_new_load', () async {
      final vm = _Vm((o, l) async => _page([1, 2], o, total: o == 0 ? 4 : 5));
      await vm.load();
      await vm.loadMore();
      expect(vm.total, 5);

      final loading = vm.load();
      expect(vm.total, isNull);
      await loading;
      expect(vm.total, 4);
    });

    test('load_with_no_items_ends_in_empty', () async {
      final vm = _Vm((o, l) async => _page([], o, total: 0));
      await vm.load();
      expect(vm.state, isA<UiEmpty<List<int>>>());
      expect(vm.hasMore, isFalse);
    });

    test('load_failure_ends_in_error_with_the_failure', () async {
      final vm = _Vm((o, l) async => const Result.failure(NetworkFailure()));
      await vm.load();
      expect((vm.state as UiError<List<int>>).failure, const NetworkFailure());
    });

    test(
      'load_more_appends_the_next_page_using_the_item_count_as_offset',
      () async {
        final offsets = <int>[];
        final vm = _Vm((o, l) async {
          offsets.add(o);
          return o == 0 ? _page([1, 2], o, total: 3) : _page([3], o, total: 3);
        });
        await vm.load();
        await vm.loadMore();

        expect((vm.state as UiSuccess<List<int>>).data, [1, 2, 3]);
        expect(offsets, [0, 2]);
        expect(vm.hasMore, isFalse);
        await vm.loadMore();
        expect(offsets, [
          0,
          2,
        ], reason: 'no request when there is nothing more');
      },
    );

    test(
      'without_total_a_full_page_means_maybe_more_and_a_short_page_means_end',
      () async {
        final vm = _Vm(
          (o, l) async => o == 0 ? _page([1, 2], o) : _page([3], o),
        );
        await vm.load();
        expect(vm.hasMore, isTrue);
        await vm.loadMore();
        expect(vm.hasMore, isFalse);
      },
    );

    test(
      'load_more_failure_keeps_the_items_and_sets_an_inline_failure',
      () async {
        var fail = false;
        final vm = _Vm(
          (o, l) async => fail
              ? const Result.failure(TimeoutFailure())
              : _page([1, 2], o, total: 5),
        );
        await vm.load();
        fail = true;
        await vm.loadMore();

        expect((vm.state as UiSuccess<List<int>>).data, [1, 2]);
        expect(vm.inlineFailure, const TimeoutFailure());
        expect(vm.isLoadingMore, isFalse);
      },
    );

    test('refresh_keeps_data_on_screen_and_replaces_it_on_success', () async {
      var round = 0;
      final vm = _Vm(
        (o, l) async => _page(round == 0 ? [1, 2] : [9], o, total: 5),
      );
      await vm.load();
      round = 1;
      final states = <UiState<List<int>>>[];
      vm.addListener(() => states.add(vm.state));
      await vm.refresh();

      expect(states.whereType<UiLoading<List<int>>>(), isEmpty);
      expect((vm.state as UiSuccess<List<int>>).data, [9]);
    });

    test('refresh_failure_keeps_old_data_and_sets_inline_failure', () async {
      var fail = false;
      final vm = _Vm(
        (o, l) async => fail
            ? const Result.failure(NetworkFailure())
            : _page([1, 2], o, total: 2),
      );
      await vm.load();
      fail = true;
      await vm.refresh();

      expect((vm.state as UiSuccess<List<int>>).data, [1, 2]);
      expect(vm.inlineFailure, const NetworkFailure());
    });

    test('a_late_answer_from_an_older_load_is_ignored', () async {
      final first = Completer<Result<PageResult<int>>>();
      var call = 0;
      final vm = _Vm((o, l) {
        call++;
        return call == 1 ? first.future : Future.value(_page([7], o, total: 1));
      });

      final slow = vm.load();
      await vm.load();
      first.complete(_page([1, 2], 0, total: 2));
      await slow;

      expect((vm.state as UiSuccess<List<int>>).data, [7]);
    });

    test('does_not_notify_after_dispose', () async {
      final completer = Completer<Result<PageResult<int>>>();
      final vm = _Vm((o, l) => completer.future);
      final pending = vm.load();
      vm.dispose();
      completer.complete(_page([1], 0, total: 1));
      await expectLater(pending, completes);
    });
  });
}
