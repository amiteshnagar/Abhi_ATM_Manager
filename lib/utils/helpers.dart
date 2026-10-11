import 'package:intl/intl.dart';

class Helpers {
  // Format currency with custom symbol (e.g. ₹ 1,200.00 or $ 10.00)
  static String formatCurrency(double amount, String symbol) {
    final formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Format a DateTime object to standard user friendly date: "Aug 6, 2026"
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  // Format date to show day name too: "Thursday, Aug 6, 2026"
  static String formatFullDate(DateTime date) {
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  // Check if a given date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // Check if a given date is within the current week (Monday to Sunday)
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    // Start of current week (Monday) at 00:00:00
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );
    // End of current week (Sunday) at 23:59:59
    final endOfWeek = startOfWeek.add(const Duration(days: 7)).subtract(
      const Duration(microseconds: 1),
    );
    
    return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
           date.isBefore(endOfWeek.add(const Duration(seconds: 1)));
  }

  // Check if a given date is within the current calendar month
  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  // Check if a given date is within the current calendar year
  static bool isThisYear(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year;
  }

  // Parse standard string date 'yyyy-MM-dd' to DateTime safely
  static DateTime parseDateString(String dateStr) {
    return DateTime.parse(dateStr);
  }

  // Shared authoritative missing-entry calculation algorithm
  static List<Map<String, dynamic>> calculateMissingEntries({
    required List<String> assignedAtmIds,
    required String regDateStr,
    required Set<String> loggedSets,
    required Set<String> nonWorkingSets,
  }) {
    if (assignedAtmIds.isEmpty) return [];

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final limitDate = todayMidnight.subtract(const Duration(days: 1)); // Yesterday inclusive

    final registrationDate = DateTime.tryParse(regDateStr) ??
        todayMidnight.subtract(const Duration(days: 14));

    final List<Map<String, dynamic>> missing = [];

    for (var atmId in assignedAtmIds) {
      var checkDate = DateTime(registrationDate.year, registrationDate.month, registrationDate.day);
      while (checkDate.isBefore(limitDate) || checkDate.isAtSameMomentAs(limitDate)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
        final key = '${atmId}_$dateStr';
        if (!loggedSets.contains(key) && !nonWorkingSets.contains(key)) {
          missing.add({
            'date': checkDate,
            'dateStr': dateStr,
            'atmId': atmId,
          });
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }
    }

    // Sort oldest first
    missing.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return missing;
  }
}
