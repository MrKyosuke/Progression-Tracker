import 'package:flutter_test/flutter_test.dart';
import 'package:progression_tracker/core/utils/date_helper.dart';

void main() {
  group('DateHelper', () {
    test('formatYmd and parseYmd roundtrip', () {
      final date = DateTime(2026, 11, 10);
      final formatted = DateHelper.formatYmd(date);
      expect(formatted, '2026-11-10');
      final parsed = DateHelper.parseYmd(formatted);
      expect(parsed.year, 2026);
      expect(parsed.month, 11);
      expect(parsed.day, 10);
    });

    test('getLogicalDate with dayStartHour at 03:00', () {
      // 02:30 AM should belong to previous calendar day
      final lateNight = DateTime(2026, 11, 10, 2, 30);
      expect(DateHelper.getLogicalDate(now: lateNight, dayStartHour: 3), '2026-11-09');

      // 03:01 AM should belong to current calendar day
      final earlyMorning = DateTime(2026, 11, 10, 3, 1);
      expect(DateHelper.getLogicalDate(now: earlyMorning, dayStartHour: 3), '2026-11-10');
    });

    test('calculateStreak counts consecutive days properly', () {
      final completed = {
        '2026-11-08',
        '2026-11-09',
        '2026-11-10',
      };
      final result = DateHelper.calculateStreak(
        completed,
        currentLogicalDate: '2026-11-10',
      );
      expect(result.currentStreak, 3);
      expect(result.longestStreak, 3);
    });

    test('calculateStreak holds streak if yesterday was completed but today not yet', () {
      final completed = {
        '2026-11-08',
        '2026-11-09',
      };
      final result = DateHelper.calculateStreak(
        completed,
        currentLogicalDate: '2026-11-10',
      );
      expect(result.currentStreak, 2);
    });

    test('calculateStreak resets to 0 if yesterday was missed', () {
      final completed = {
        '2026-11-07',
        '2026-11-08',
      };
      final result = DateHelper.calculateStreak(
        completed,
        currentLogicalDate: '2026-11-10',
      );
      expect(result.currentStreak, 0);
      expect(result.longestStreak, 2);
    });
  });
}

