import 'package:intl/intl.dart';

/// Formátování datumů v české notaci.
///
/// `initializeDateFormatting('cs_CZ')` se volá v `main()` před `runApp`.
abstract final class AppDateFormat {
  static const String _locale = 'cs_CZ';

  /// "21. 8. 2026, 7:15" - datum a čas přijetí.
  static String dateTime(DateTime value) =>
      DateFormat('d. M. yyyy, H:mm', _locale).format(value);

  /// "26. 8." - kompaktní termín v kartě seznamu.
  static String dayMonth(DateTime value) =>
      DateFormat('d. M.', _locale).format(value);

  /// "26. 8. 2026" - termín dokončení v detailu.
  static String date(DateTime value) =>
      DateFormat('d. M. yyyy', _locale).format(value);

  /// "9:40".
  static String time(DateTime value) =>
      DateFormat('H:mm', _locale).format(value);

  /// Meta u poznámky: "dnes 9:40", "včera 16:20", "23. 8. 16:20".
  static String relativeDateTime(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final day = DateTime(value.year, value.month, value.day);
    final today = DateTime(reference.year, reference.month, reference.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'dnes ${time(value)}';
    if (diff == 1) return 'včera ${time(value)}';
    return '${dayMonth(value)} ${time(value)}';
  }
}
