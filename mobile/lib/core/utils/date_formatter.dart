import 'package:intl/intl.dart';

/// The only place where dates become text or text becomes dates.
///
/// Numeric formats are built by hand so they need no locale data. Month names
/// use `intl` and need `initializeDateFormatting('pt_BR')` first (the app does
/// it at startup).
abstract final class DateFormatter {
  /// `12/11/2026`.
  static String date(DateTime value) =>
      '${_two(value.day)}/${_two(value.month)}/${value.year}';

  /// `12/11`.
  static String dayMonth(DateTime value) =>
      '${_two(value.day)}/${_two(value.month)}';

  /// `novembro de 2026`.
  static String monthYear(DateTime value) =>
      DateFormat("MMMM 'de' yyyy", 'pt_BR').format(value);

  /// `novembro`.
  static String monthName(DateTime value) =>
      DateFormat('MMMM', 'pt_BR').format(value);

  /// `nov`.
  static String monthShort(DateTime value) =>
      DateFormat('MMM', 'pt_BR').format(value).replaceAll('.', '');

  /// `Seg`, `Ter`, ... Needs the same locale data as [monthName].
  static String weekdayShort(DateTime value) {
    final text = DateFormat('E', 'pt_BR').format(value).replaceAll('.', '');
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  /// Reads `dd/MM/yyyy`. Returns `null` for anything else, including dates
  /// that do not exist, such as `31/02/2026`.
  static DateTime? parse(String input) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(input.trim());
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final result = DateTime(year, month, day);
    final exists =
        result.year == year && result.month == month && result.day == day;
    return exists ? result : null;
  }

  /// `yyyy-MM-dd`, the format of date fields and query parameters of the API.
  static String toApiDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
