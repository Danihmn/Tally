/// Whether a financial entry is money to receive or money to pay.
enum EntryType {
  revenues('REVENUES'),
  expenses('EXPENSES');

  const EntryType(this.apiValue);

  /// What the API expects in the `type` query parameter.
  final String apiValue;
}
