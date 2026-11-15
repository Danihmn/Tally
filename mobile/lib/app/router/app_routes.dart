/// Route paths. Used by the router and by views that navigate.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const transactions = '/transactions';

  /// The detail of one transaction. It covers the tabs.
  static const transactionDetail = '/transactions/detail';
  static const entries = '/entries';

  /// The detail of one entry. It covers the tabs.
  static const entryDetail = '/entries/detail';
  static const accounts = '/accounts';
  static const chat = '/chat';

  /// The conversation history. It covers the tabs and pops with the id.
  static const chatConversations = '/chat/conversations';

  /// The people of the house, opened from the settings. It covers the tabs.
  static const users = '/settings/users';

  /// The details of one person. It covers the tabs.
  static const userDetail = '/settings/users/detail';
}
