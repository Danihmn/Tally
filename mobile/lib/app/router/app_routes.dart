/// Route paths. Used by the router and by views that navigate.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const transactions = '/transactions';

  /// The detail of one transaction. It covers the tabs.
  static const transactionDetail = '/transactions/detail';
  static const entries = '/entries';
  static const accounts = '/accounts';
  static const chat = '/chat';
}
