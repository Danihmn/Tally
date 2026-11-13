/// One backend endpoint the app calls.
class ApiEndpoint {
  const ApiEndpoint(this.method, this.path, {required this.usedBy});

  /// HTTP method in upper case: GET, POST, PUT, PATCH or DELETE.
  final String method;

  /// The path as the backend declares it: starts with `/`, no query string.
  final String path;

  /// The feature of the app that calls it.
  final String usedBy;

  @override
  String toString() => '$method $path';
}

/// Every backend endpoint the app uses.
///
/// This is the mark used to clean the backend: a route that is not here is a
/// candidate for removal. Data sources take the paths from here.
///
/// Add every new endpoint in the same change that creates it, and list it in
/// [all] too.
///
/// NOT COMPLETE YET: the endpoints created before this registry and used by
/// the app (`/bank-accounts`, the transaction and entry lists, `/tally/chat`,
/// ...) are not marked yet. Until they are, do not use this list alone to
/// delete routes from the backend.
abstract final class ApiEndpoints {
  // Login and household

  static const login = ApiEndpoint('POST', '/auth/login', usedBy: 'Login');

  static const me = ApiEndpoint('GET', '/users/me', usedBy: 'Home');

  static const users = ApiEndpoint('GET', '/users', usedBy: 'Home');

  // Movement analysis (transactions)

  static const totalExpenses = ApiEndpoint(
    'GET',
    '/transactions/total-expenses',
    usedBy: 'Movement analysis',
  );

  static const totalRevenues = ApiEndpoint(
    'GET',
    '/transactions/total-revenues',
    usedBy: 'Movement analysis',
  );

  static const balance = ApiEndpoint(
    'GET',
    '/transactions/balance',
    usedBy: 'Movement analysis',
  );

  // Planning (financial entries)

  static const totalPlanned = ApiEndpoint(
    'GET',
    '/financial-entries/total-planned',
    usedBy: 'Planning',
  );

  static const totalReconciled = ApiEndpoint(
    'GET',
    '/financial-entries/total-reconciled',
    usedBy: 'Planning',
  );

  static const reconciliationCounts = ApiEndpoint(
    'GET',
    '/financial-entries/reconciliation-counts',
    usedBy: 'Planning',
  );

  // Spending analysis (transactions)

  static const topExpenses = ApiEndpoint(
    'GET',
    '/transactions/top-expenses',
    usedBy: 'Spending analysis',
  );

  static const dailyExpenses = ApiEndpoint(
    'GET',
    '/transactions/daily-expenses',
    usedBy: 'Spending analysis',
  );

  static const averageDailyExpenses = ApiEndpoint(
    'GET',
    '/transactions/average-daily-expenses',
    usedBy: 'Spending analysis',
  );

  // Upcoming entries (financial entries)

  static const upcomingEntries = ApiEndpoint(
    'GET',
    '/financial-entries/upcoming',
    usedBy: 'Upcoming entries',
  );

  /// Every endpoint above. Add new ones here too.
  static const all = <ApiEndpoint>[
    login,
    me,
    users,
    totalExpenses,
    totalRevenues,
    balance,
    totalPlanned,
    totalReconciled,
    reconciliationCounts,
    topExpenses,
    dailyExpenses,
    averageDailyExpenses,
    upcomingEntries,
  ];
}
