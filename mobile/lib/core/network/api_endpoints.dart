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
/// the app (the entry list, ...) are not marked yet. Until they
/// are, do not use this list alone to delete routes from the backend.
abstract final class ApiEndpoints {
  // Login and household

  static const login = ApiEndpoint('POST', '/auth/login', usedBy: 'Login');

  static const me = ApiEndpoint('GET', '/users/me', usedBy: 'Home');

  static const users = ApiEndpoint('GET', '/users', usedBy: 'Home');

  // Settings: the people of the house

  static const createUser = ApiEndpoint(
    'POST',
    '/users',
    usedBy: 'Configurações',
  );

  /// Name, nickname and e-mail. `{id}` is the user id.
  static const updateUser = ApiEndpoint(
    'PATCH',
    '/users/{id}',
    usedBy: 'Configurações',
  );

  /// Replaces the Pluggy client id and secret. `{id}` is the user id.
  static const updateUserPluggyCredentials = ApiEndpoint(
    'PUT',
    '/users/{id}/pluggy-credentials',
    usedBy: 'Configurações',
  );

  /// Sets a new password for a person of the house. `{id}` is the user id.
  static const updateUserPassword = ApiEndpoint(
    'PUT',
    '/users/{id}/password',
    usedBy: 'Configurações',
  );

  // Transactions list (and the accounts it names)

  static const transactions = ApiEndpoint(
    'GET',
    '/transactions',
    usedBy: 'Transações',
  );

  static const bankAccounts = ApiEndpoint(
    'GET',
    '/bank-accounts',
    usedBy: 'Transações',
  );

  /// Links a transaction with an entry by hand. `{transactionId}` and
  /// `{entryId}` are the ids.
  static const linkTransactionEntry = ApiEndpoint(
    'POST',
    '/transactions/{transactionId}/financial-entries/{entryId}',
    usedBy: 'Transações',
  );

  /// Undoes the link of a transaction with an entry.
  static const unlinkTransactionEntry = ApiEndpoint(
    'DELETE',
    '/transactions/{transactionId}/financial-entries/{entryId}',
    usedBy: 'Transações',
  );

  // Accounts and cards with their balance

  static const accountBalances = ApiEndpoint(
    'GET',
    '/bank-accounts/balances',
    usedBy: 'Contas',
  );

  static const totalAccountBalance = ApiEndpoint(
    'GET',
    '/bank-accounts/total-balance',
    usedBy: 'Contas',
  );

  /// The "conta salário" setting of a bank account. `{id}` is the account id.
  static const updateBankAccount = ApiEndpoint(
    'PATCH',
    '/bank-accounts/{id}',
    usedBy: 'Contas',
  );

  /// The bill of a credit card for one due month (`month=YYYY-MM`). `{id}` is
  /// the card id.
  static const creditCardBill = ApiEndpoint(
    'GET',
    '/bank-accounts/{id}/bill',
    usedBy: 'Contas',
  );

  // Entries list (and the transactions they are matched with)

  static const financialEntries = ApiEndpoint(
    'GET',
    '/financial-entries',
    usedBy: 'Lançamentos',
  );

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

  // Planning screen: create, edit and delete entries

  static const createFinancialEntry = ApiEndpoint(
    'POST',
    '/financial-entries',
    usedBy: 'Planejamento',
  );

  /// `{id}` is the entry id. Also used to cancel or reopen (`status`).
  static const updateFinancialEntry = ApiEndpoint(
    'PATCH',
    '/financial-entries/{id}',
    usedBy: 'Planejamento',
  );

  static const deleteFinancialEntry = ApiEndpoint(
    'DELETE',
    '/financial-entries/{id}',
    usedBy: 'Planejamento',
  );

  // Planning screen: recurrences

  /// `status` (ACTIVE or CANCELLED) picks the tab.
  static const recurrences = ApiEndpoint(
    'GET',
    '/recurrences',
    usedBy: 'Planejamento',
  );

  static const createRecurrence = ApiEndpoint(
    'POST',
    '/recurrences',
    usedBy: 'Planejamento',
  );

  static const updateRecurrence = ApiEndpoint(
    'PATCH',
    '/recurrences/{id}',
    usedBy: 'Planejamento',
  );

  static const deleteRecurrence = ApiEndpoint(
    'DELETE',
    '/recurrences/{id}',
    usedBy: 'Planejamento',
  );

  /// Creates next month's entries from the recurrences. 422 with the code
  /// `NO_RECURRENCES` when the house has none.
  static const provisionRecurrences = ApiEndpoint(
    'POST',
    '/recurrences/provision',
    usedBy: 'Planejamento',
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

  // Tally AI chat

  /// Sends a question. The answer is a `text/event-stream` (SSE).
  static const chat = ApiEndpoint('POST', '/tally/chat', usedBy: 'Tally AI');

  static const conversations = ApiEndpoint(
    'GET',
    '/tally/conversations',
    usedBy: 'Tally AI',
  );

  /// One conversation with its messages. `{id}` is the conversation id.
  static const conversation = ApiEndpoint(
    'GET',
    '/tally/conversations/{id}',
    usedBy: 'Tally AI',
  );

  /// Every endpoint above. Add new ones here too.
  static const all = <ApiEndpoint>[
    login,
    me,
    users,
    createUser,
    updateUser,
    updateUserPluggyCredentials,
    updateUserPassword,
    transactions,
    bankAccounts,
    linkTransactionEntry,
    unlinkTransactionEntry,
    accountBalances,
    totalAccountBalance,
    updateBankAccount,
    creditCardBill,
    financialEntries,
    totalExpenses,
    totalRevenues,
    balance,
    totalPlanned,
    totalReconciled,
    reconciliationCounts,
    createFinancialEntry,
    updateFinancialEntry,
    deleteFinancialEntry,
    recurrences,
    createRecurrence,
    updateRecurrence,
    deleteRecurrence,
    provisionRecurrences,
    topExpenses,
    dailyExpenses,
    averageDailyExpenses,
    upcomingEntries,
    chat,
    conversations,
    conversation,
  ];
}
