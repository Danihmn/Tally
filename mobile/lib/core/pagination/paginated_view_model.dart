import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';

export 'package:mobile/core/pagination/page_result.dart';

/// Infinite scroll for list ViewModels, written once.
///
/// The ViewModel only implements [fetchPage]. Calls to [load] and [refresh]
/// start a new "generation": an answer that comes back late for an older
/// generation (for example a previous search text) is thrown away, so it
/// cannot overwrite newer results.
mixin PaginatedViewModel<T> on ChangeNotifier {
  static const defaultPageSize = 30;

  /// Page size sent as `limit`. Override to change it.
  int get pageSize => defaultPageSize;

  /// Fetches one page. Implemented by the ViewModel through a use case.
  Future<Result<PageResult<T>>> fetchPage({
    required int offset,
    required int limit,
  });

  final List<T> _items = [];
  UiState<List<T>> _state = const UiInitial();
  bool _hasMore = false;
  bool _loadingMore = false;
  Failure? _inlineFailure;
  int? _total;
  int _generation = 0;
  bool _disposed = false;

  UiState<List<T>> get state => _state;

  bool get hasMore => _hasMore;

  bool get isLoadingMore => _loadingMore;

  /// How many items the API says match, from the last answer. `null` when the
  /// endpoint does not tell (plain lists) or nothing was loaded.
  int? get total => _total;

  /// Failure of a refresh or "load more" while data is already on screen.
  /// The view shows a retry footer. It is cleared by the next success.
  Failure? get inlineFailure => _inlineFailure;

  /// First load: clears the list and shows the skeleton.
  Future<void> load() async {
    final generation = ++_generation;
    _items.clear();
    _hasMore = false;
    _loadingMore = false;
    _inlineFailure = null;
    _total = null;
    _state = const UiLoading();
    _notify();
    final result = await fetchPage(offset: 0, limit: pageSize);
    if (generation != _generation) return;
    switch (result) {
      case Success<PageResult<T>>(:final value):
        _applyFirstPage(value);
      case Err<PageResult<T>>(:final failure):
        _state = UiError(failure);
    }
    _notify();
  }

  /// Pull to refresh: keeps the current data on screen while it reloads.
  Future<void> refresh() async {
    if (_state is! UiSuccess<List<T>>) return load();
    final generation = ++_generation;
    _loadingMore = false;
    final result = await fetchPage(offset: 0, limit: pageSize);
    if (generation != _generation) return;
    switch (result) {
      case Success<PageResult<T>>(:final value):
        _items.clear();
        _inlineFailure = null;
        _applyFirstPage(value);
      case Err<PageResult<T>>(:final failure):
        _inlineFailure = failure;
    }
    _notify();
  }

  /// Loads the next page when the user scrolls near the end.
  Future<void> loadMore() async {
    if (_state is! UiSuccess<List<T>> || !_hasMore || _loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    _inlineFailure = null;
    _notify();
    final result = await fetchPage(offset: _items.length, limit: pageSize);
    if (generation != _generation) return;
    _loadingMore = false;
    switch (result) {
      case Success<PageResult<T>>(:final value):
        _items.addAll(value.items);
        _total = value.total;
        _hasMore = _computeHasMore(value);
        _state = UiSuccess(List.unmodifiable(_items));
      case Err<PageResult<T>>(:final failure):
        _inlineFailure = failure;
    }
    _notify();
  }

  void _applyFirstPage(PageResult<T> page) {
    _items.addAll(page.items);
    _total = page.total;
    _hasMore = _computeHasMore(page);
    _state = _items.isEmpty
        ? const UiEmpty()
        : UiSuccess(List.unmodifiable(_items));
  }

  bool _computeHasMore(PageResult<T> page) {
    if (page.items.isEmpty) return false;
    final total = page.total;
    return total != null
        ? _items.length < total
        : page.items.length >= page.limit;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
