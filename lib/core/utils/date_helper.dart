import 'package:intl/intl.dart';

class DateHelper {
  static final DateFormat _ymdFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayFormat = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _shortDisplayFormat = DateFormat('d MMM');

  /// Returns YYYY-MM-DD string
  static String formatYmd(DateTime date) {
    return _ymdFormat.format(date);
  }

  /// Parses YYYY-MM-DD string to DateTime (local)
  static DateTime parseYmd(String ymd) {
    return _ymdFormat.parse(ymd);
  }

  /// Formats date for display: "Sen, 10 Nov 2026"
  static String formatDisplay(DateTime date) {
    return _displayFormat.format(date);
  }

  static String formatShortDisplay(DateTime date) {
    return _shortDisplayFormat.format(date);
  }

  /// Returns logical date taking into account dayStartHour (e.g. 03:00).
  /// If now.hour < dayStartHour, it is attributed to the previous calendar day.
  static String getLogicalDate({DateTime? now, int dayStartHour = 0}) {
    final current = now ?? DateTime.now();
    if (dayStartHour > 0 && current.hour < dayStartHour) {
      final previousDay = current.subtract(const Duration(days: 1));
      return formatYmd(previousDay);
    }
    return formatYmd(current);
  }

  /// Calculates current streak and longest streak from a set of dates where goal was met.
  static StreakResult calculateStreak(
    Set<String> completedDates, {
    String? currentLogicalDate,
    int dayStartHour = 0,
  }) {
    if (completedDates.isEmpty) {
      return const StreakResult(currentStreak: 0, longestStreak: 0);
    }

    final todayStr = currentLogicalDate ?? getLogicalDate(dayStartHour: dayStartHour);
    final today = parseYmd(todayStr);
    final yesterdayStr = formatYmd(today.subtract(const Duration(days: 1)));

    // Calculate current streak
    int currentStreak = 0;
    DateTime checkDate;

    if (completedDates.contains(todayStr)) {
      checkDate = today;
    } else if (completedDates.contains(yesterdayStr)) {
      checkDate = today.subtract(const Duration(days: 1));
    } else {
      checkDate = today; // Won't match, so 0
    }

    while (completedDates.contains(formatYmd(checkDate))) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Calculate longest streak
    final sortedDates = completedDates.map(parseYmd).toList()..sort();
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? prevDate;

    for (final date in sortedDates) {
      if (prevDate == null) {
        tempStreak = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          tempStreak = 1;
        }
        // If diff == 0, duplicate date, ignore
      }
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
      }
      prevDate = date;
    }

    return StreakResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }
}

class StreakResult {
  final int currentStreak;
  final int longestStreak;

  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
  });
}

