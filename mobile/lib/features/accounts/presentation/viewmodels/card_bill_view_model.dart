import 'package:flutter/foundation.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/accounts/domain/entities/card_bill.dart';
import 'package:mobile/features/accounts/domain/usecases/get_card_bill.dart';

/// The bill of one credit card for one due month. It starts at the bill due
/// next month (the one the person pays next) and moves month by month.
class CardBillViewModel extends ChangeNotifier {
  CardBillViewModel({
    required this._accountId,
    required this._getBill,
    DateTime Function()? now,
  }) {
    final today = (now ?? DateTime.now)();
    _month = DateTime(today.year, today.month + 1);
  }

  final String _accountId;
  final GetCardBill _getBill;

  late DateTime _month;
  UiState<CardBill> _state = const UiInitial();
  int _request = 0;
  bool _disposed = false;

  /// Day 1 of the due month on screen.
  DateTime get month => _month;
  UiState<CardBill> get state => _state;

  Future<void> load() async {
    final request = ++_request;
    _state = const UiLoading();
    _notify();
    final result = await _getBill(_accountId, month: _month);
    // A slower answer for a month the person already left is dropped.
    if (_disposed || request != _request) return;
    _state = result.when<UiState<CardBill>>(
      success: UiSuccess.new,
      failure: UiError<CardBill>.new,
    );
    _notify();
  }

  Future<void> previousMonth() =>
      _goTo(DateTime(_month.year, _month.month - 1));

  Future<void> nextMonth() => _goTo(DateTime(_month.year, _month.month + 1));

  Future<void> _goTo(DateTime month) {
    _month = month;
    return load();
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
