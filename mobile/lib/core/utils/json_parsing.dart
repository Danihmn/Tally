import 'package:decimal/decimal.dart';

/// Helpers for reading API JSON at the data-layer edge. They only parse: no
/// business rule belongs here. On bad input they throw [FormatException],
/// which `apiCall` turns into an `UnknownFailure`.

/// Money can arrive as a JSON number or as a string. Never goes through a
/// `double` calculation: the text is parsed as it is.
Decimal parseDecimal(Object? value) {
  if (value is String) return Decimal.parse(value);
  if (value is num) return Decimal.parse(value.toString());
  throw FormatException('Expected a decimal, got ${value.runtimeType}.');
}

/// Like [parseDecimal] but allows `null`.
Decimal? parseDecimalOrNull(Object? value) =>
    value == null ? null : parseDecimal(value);

/// An ISO 8601 date-time such as `2026-11-12T10:30:00Z`.
DateTime parseDateTime(Object? value) {
  if (value is String) return DateTime.parse(value);
  throw FormatException('Expected a date-time, got ${value.runtimeType}.');
}

/// Like [parseDateTime] but allows `null`.
DateTime? parseDateTimeOrNull(Object? value) =>
    value == null ? null : parseDateTime(value);

/// A required, non-empty text field. [field] only names it in the error.
String requireString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Expected a text for "$field".');
}
