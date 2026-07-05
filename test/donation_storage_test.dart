import 'package:blood_donation/services/donation_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dateOnly', () {
    test('strips time component', () {
      final date = DateTime(2024, 6, 15, 14, 30, 45);
      expect(
        DonationStorage.dateOnly(date),
        DateTime(2024, 6, 15),
      );
    });
  });

  group('dedupeDonationDates', () {
    test('removes duplicate calendar days', () {
      final dates = [
        DateTime(2024, 1, 1, 10),
        DateTime(2024, 1, 1, 18),
        DateTime(2024, 2, 1),
      ];

      expect(
        DonationStorage.dedupeDonationDates(dates),
        [DateTime(2024, 2, 1), DateTime(2024, 1, 1)],
      );
    });

    test('returns empty list for empty input', () {
      expect(DonationStorage.dedupeDonationDates([]), isEmpty);
    });

    test('sorts descending by date', () {
      final dates = [
        DateTime(2023, 1, 1),
        DateTime(2025, 1, 1),
        DateTime(2024, 6, 1),
      ];

      final result = DonationStorage.dedupeDonationDates(dates);
      expect(result.map((d) => d.year), [2025, 2024, 2023]);
    });
  });

  group('dedupeDonationStrings', () {
    test('dedupes ISO strings with different times on same day', () {
      final strings = [
        '2024-03-10T08:00:00.000',
        '2024-03-10T20:00:00.000',
        '2024-01-05T00:00:00.000',
      ];

      final result = DonationStorage.dedupeDonationStrings(strings);
      expect(result.length, 2);
      expect(result.first, startsWith('2024-03-10'));
      expect(result.last, startsWith('2024-01-05'));
    });

    test('skips invalid date strings', () {
      final strings = [
        'not-a-date',
        '2024-03-10T00:00:00.000',
        '2024-03-10T12:00:00.000',
      ];

      expect(DonationStorage.dedupeDonationStrings(strings).length, 1);
    });
  });

  group('validateImportMap', () {
    test('accepts valid backup with deduped donations', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': 1,
        DonationStorage.keyDonations: [
          '2024-06-01T10:00:00.000',
          '2024-06-01T18:00:00.000',
          '2024-01-15T00:00:00.000',
        ],
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyReminderEnabled: true,
        DonationStorage.keyReminderDaysBefore: 2,
      });

      expect(result.success, isTrue);
      final donations = result.data![DonationStorage.keyDonations] as List<String>;
      expect(donations.length, 2);
    });

    test('rejects newer schema version', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': 999,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('newer app version'));
    });

    test('rejects invalid schema_version type', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': '1',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('schema_version'));
    });

    test('rejects invalid countdown_days', () {
      final result = DonationStorage.validateImportMap({
        DonationStorage.keyCountdownDays: 0,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('countdown_days'));
    });

    test('rejects invalid reminder_days_before', () {
      final result = DonationStorage.validateImportMap({
        DonationStorage.keyReminderDaysBefore: 31,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('reminder_days_before'));
    });

    test('rejects donations that are not a list', () {
      final result = DonationStorage.validateImportMap({
        DonationStorage.keyDonations: 'not-a-list',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('donations'));
    });

    test('rejects empty recognizable data', () {
      final result = DonationStorage.validateImportMap({
        'unknown_field': 'value',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('No recognizable data'));
    });

    test('ignores legacy show_countdown_widget field', () {
      final result = DonationStorage.validateImportMap({
        DonationStorage.keyCountdownDays: 56,
        'show_countdown_widget': true,
      });

      expect(result.success, isTrue);
      expect(result.data!.containsKey('show_countdown_widget'), isFalse);
    });
  });

  group('computeCatchUp', () {
    final lastDonation = DateTime(2024, 1, 1);

    test('returns none when reminders disabled', () {
      final result = DonationStorage.computeCatchUp(
        donations: [lastDonation],
        countdownDays: 56,
        reminderEnabled: false,
        reminderDaysBefore: 1,
        now: DateTime(2024, 3, 1),
      );

      expect(result.kind, EligibilityCatchUpKind.none);
    });

    test('returns none when no donations', () {
      final result = DonationStorage.computeCatchUp(
        donations: [],
        countdownDays: 56,
        reminderEnabled: true,
        reminderDaysBefore: 1,
        now: DateTime(2024, 3, 1),
      );

      expect(result.kind, EligibilityCatchUpKind.none);
    });

    test('returns eligibleNow when countdown has passed', () {
      final result = DonationStorage.computeCatchUp(
        donations: [lastDonation],
        countdownDays: 56,
        reminderEnabled: true,
        reminderDaysBefore: 1,
        now: DateTime(2024, 3, 1),
      );

      expect(result.kind, EligibilityCatchUpKind.eligibleNow);
      expect(result.eligibleDate, DateTime(2024, 2, 26));
    });

    test('returns eligibleNow on exact eligible date', () {
      final result = DonationStorage.computeCatchUp(
        donations: [lastDonation],
        countdownDays: 56,
        reminderEnabled: true,
        reminderDaysBefore: 1,
        now: DateTime(2024, 2, 26),
      );

      expect(result.kind, EligibilityCatchUpKind.eligibleNow);
    });

    test('returns missedAdvanceReminder in reminder window', () {
      final result = DonationStorage.computeCatchUp(
        donations: [lastDonation],
        countdownDays: 56,
        reminderEnabled: true,
        reminderDaysBefore: 3,
        now: DateTime(2024, 2, 24),
      );

      expect(result.kind, EligibilityCatchUpKind.missedAdvanceReminder);
      expect(result.reminderDate, DateTime(2024, 2, 23));
      expect(result.eligibleDate, DateTime(2024, 2, 26));
    });

    test('returns none before reminder window', () {
      final result = DonationStorage.computeCatchUp(
        donations: [lastDonation],
        countdownDays: 56,
        reminderEnabled: true,
        reminderDaysBefore: 3,
        now: DateTime(2024, 2, 20),
      );

      expect(result.kind, EligibilityCatchUpKind.none);
    });
  });

  group('dedupeDonationStrings edge cases', () {
    test('preserves single valid entry', () {
      expect(
        DonationStorage.dedupeDonationStrings(['2024-03-10T00:00:00.000']),
        ['2024-03-10T00:00:00.000'],
      );
    });

    test('returns empty list when all strings are invalid', () {
      expect(
        DonationStorage.dedupeDonationStrings(['bad', 'also-bad']),
        isEmpty,
      );
    });
  });
}
