import 'package:blood_donation/models/donation_type.dart';
import 'package:blood_donation/models/export_schema.dart';
import 'package:blood_donation/models/typed_donation.dart';
import 'package:blood_donation/services/donation_storage.dart';
import 'package:blood_donation/services/encrypted_store.dart';
import 'package:blood_donation/services/key_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _resetEncryptedStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(initial));
  final prefs = await SharedPreferences.getInstance();
  final store = EncryptedStore(
    keyVault: InMemoryKeyVault(),
    prefs: prefs,
  );
  EncryptedStore.resetInstanceForTest(store);
  await store.ensureInitialized();
}

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

  group('DonationType', () {
    test('keeps donor-journey enum order', () {
      expect(
        DonationType.values.map((t) => t.id).toList(),
        ['whole_blood', 'plasma', 'platelet', 'double_red'],
      );
      expect(
        DonationType.values.map((t) => t.displayName).toList(),
        [
          'Whole Blood',
          'Plasma',
          'Platelets',
          'Double Red / Power Red',
        ],
      );
    });

    test('exposes soft journey labels', () {
      expect(DonationType.wholeBlood.journeyLabel, 'Start here / New donor');
      expect(DonationType.plasma.journeyLabel, 'Frequent / Maximize impact');
      expect(DonationType.platelet.journeyLabel, 'Frequent / Maximize impact');
      expect(DonationType.doubleRed.journeyLabel, 'Advanced / High impact');
    });

    test('exposes four types with expected prefs keys and defaults', () {
      expect(DonationType.values.length, 4);
      expect(DonationType.platelet.id, 'platelet');
      expect(DonationType.platelet.donationsPrefsKey, 'donations_platelet');
      expect(DonationType.platelet.countdownPrefsKey, 'countdown_days_platelet');
      expect(DonationType.platelet.defaultCountdownDays, 7);
      expect(DonationType.platelet.mlPerDonation, 250);
    });

    test('uses the requested palette accents', () {
      expect(DonationType.wholeBlood.accent, const Color(0xFFD3180C));
      expect(DonationType.wholeBlood.accentDeep, const Color(0xFF8B0000));
      expect(DonationType.plasma.accent, const Color(0xFFF4C430));
      expect(DonationType.plasma.accentSecondary, const Color(0xFFFFD700));
      expect(DonationType.platelet.brandAccent, const Color(0xFFFFDAB9));
      expect(DonationType.platelet.accentSecondary, const Color(0xFFFFFACD));
      expect(DonationType.doubleRed.accent, const Color(0xFF800000));
      expect(DonationType.doubleRed.accentDeep, const Color(0xFF4A0404));
    });

    test('marks plasma and platelets as light accents', () {
      expect(DonationType.plasma.accentIsLight, isTrue);
      expect(DonationType.platelet.accentIsLight, isTrue);
      expect(DonationType.wholeBlood.accentIsLight, isFalse);
      expect(DonationType.doubleRed.accentIsLight, isFalse);
    });
  });

  group('TypeEligibility', () {
    test('eligibleNow when daysUntil is 0', () {
      final row = TypeEligibility(
        type: DonationType.platelet,
        countdownDays: 7,
        lastDonation: DateTime(2024, 6, 1),
        nextEligible: DateTime(2024, 6, 8),
        daysUntil: 0,
      );
      expect(row.hasDonations, isTrue);
      expect(row.eligibleNow, isTrue);
    });

    test('not eligible when days remain', () {
      final row = TypeEligibility(
        type: DonationType.wholeBlood,
        countdownDays: 56,
        lastDonation: DateTime(2024, 1, 1),
        nextEligible: DateTime(2024, 2, 26),
        daysUntil: 10,
      );
      expect(row.eligibleNow, isFalse);
    });

    test('no donations leaves daysUntil null', () {
      const row = TypeEligibility(
        type: DonationType.plasma,
        countdownDays: 28,
      );
      expect(row.hasDonations, isFalse);
      expect(row.eligibleNow, isFalse);
      expect(row.daysUntil, isNull);
    });
  });

  group('export schema', () {
    test('current schema is v5', () {
      expect(kExportSchemaVersion, 5);
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
      expect(result.data!.containsKey(DonationStorage.keyDonationsPlasma), isFalse);
      expect(result.data!.containsKey(DonationStorage.keyDonationsPlatelet), isFalse);
    });

    test('accepts schema v2 with three series (no platelet key)', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': 2,
        DonationStorage.keyDonations: ['2024-01-01T00:00:00.000'],
        DonationStorage.keyDonationsPlasma: ['2024-02-01T00:00:00.000'],
        DonationStorage.keyDonationsDoubleRed: ['2024-03-01T00:00:00.000'],
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyCountdownDaysPlasma: 28,
        DonationStorage.keyCountdownDaysDoubleRed: 112,
        DonationStorage.keyActiveDonationType: 'plasma',
        DonationStorage.keyReminderEnabled: false,
        DonationStorage.keyReminderDaysBefore: 1,
      });

      expect(result.success, isTrue);
      expect(result.data![DonationStorage.keyActiveDonationType], 'plasma');
      expect(
        (result.data![DonationStorage.keyDonationsPlasma] as List).length,
        1,
      );
      expect(result.data!.containsKey(DonationStorage.keyDonationsPlatelet), isFalse);
    });

    test('accepts schema v3 with all four series', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': 3,
        DonationStorage.keyDonations: ['2024-01-01T00:00:00.000'],
        DonationStorage.keyDonationsPlasma: ['2024-02-01T00:00:00.000'],
        DonationStorage.keyDonationsPlatelet: ['2024-02-15T00:00:00.000'],
        DonationStorage.keyDonationsDoubleRed: ['2024-03-01T00:00:00.000'],
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyCountdownDaysPlasma: 28,
        DonationStorage.keyCountdownDaysPlatelet: 7,
        DonationStorage.keyCountdownDaysDoubleRed: 112,
        DonationStorage.keyActiveDonationType: 'platelet',
        DonationStorage.keyReminderEnabled: true,
        DonationStorage.keyReminderDaysBefore: 1,
      });

      expect(result.success, isTrue);
      expect(result.data![DonationStorage.keyActiveDonationType], 'platelet');
      expect(
        (result.data![DonationStorage.keyDonationsPlatelet] as List).length,
        1,
      );
      expect(result.data![DonationStorage.keyCountdownDaysPlatelet], 7);
      expect(result.data!.containsKey(DonationStorage.keyDonorNumber), isFalse);
    });

    test('accepts schema v4 with optional donor_number', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': 4,
        DonationStorage.keyDonations: ['2024-01-01T00:00:00.000'],
        DonationStorage.keyDonationsPlasma: [],
        DonationStorage.keyDonationsPlatelet: [],
        DonationStorage.keyDonationsDoubleRed: [],
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyDonorNumber: '  ABC-12345  ',
      });

      expect(result.success, isTrue);
      expect(result.data![DonationStorage.keyDonorNumber], 'ABC-12345');
    });

    test('accepts schema v5 (same fields as v4)', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': 5,
        DonationStorage.keyDonations: ['2024-01-01T00:00:00.000'],
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyDonorNumber: 'V5-ID',
        'export_note': 'This backup file is not encrypted.',
      });

      expect(result.success, isTrue);
      expect(result.data![DonationStorage.keyDonorNumber], 'V5-ID');
    });

    test('accepts empty donor_number string', () {
      final result = DonationStorage.validateImportMap({
        'schema_version': 4,
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyDonorNumber: '',
      });

      expect(result.success, isTrue);
      expect(result.data![DonationStorage.keyDonorNumber], '');
    });

    test('rejects non-string donor_number', () {
      final result = DonationStorage.validateImportMap({
        DonationStorage.keyDonorNumber: 12345,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('donor_number'));
    });

    test('rejects oversized donor_number', () {
      final result = DonationStorage.validateImportMap({
        DonationStorage.keyDonorNumber: 'x' * 65,
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('too long'));
    });

    test('maps unknown active_donation_type to whole blood', () {
      final result = DonationStorage.validateImportMap({
        DonationStorage.keyActiveDonationType: 'unknown_type',
        DonationStorage.keyCountdownDays: 56,
      });

      expect(result.success, isTrue);
      expect(result.data![DonationStorage.keyActiveDonationType], 'whole_blood');
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

    test('works with platelet 7-day countdown', () {
      final result = DonationStorage.computeCatchUp(
        donations: [DateTime(2024, 6, 1)],
        countdownDays: 7,
        reminderEnabled: true,
        reminderDaysBefore: 1,
        now: DateTime(2024, 6, 8),
      );

      expect(result.kind, EligibilityCatchUpKind.eligibleNow);
      expect(result.eligibleDate, DateTime(2024, 6, 8));
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

  group('encrypted-store-backed helpers', () {
    setUp(() async {
      await _resetEncryptedStore();
    });

    test('donor number get/set/clear', () async {
      expect(await DonationStorage.getDonorNumber(), '');
      await DonationStorage.setDonorNumber('  DNR-99  ');
      expect(await DonationStorage.getDonorNumber(), 'DNR-99');
      await DonationStorage.setDonorNumber('');
      expect(await DonationStorage.getDonorNumber(), '');
    });

    test('applyImport restores donor_number from v4 backup', () async {
      await DonationStorage.applyImport({
        DonationStorage.keyDonations: ['2024-01-10T00:00:00.000'],
        DonationStorage.keyDonationsPlasma: <String>[],
        DonationStorage.keyDonationsPlatelet: <String>[],
        DonationStorage.keyDonationsDoubleRed: <String>[],
        DonationStorage.keyDonorNumber: 'RESTORE-42',
      });

      expect(await DonationStorage.getDonorNumber(), 'RESTORE-42');
      final wb = await DonationStorage.getDonations(DonationType.wholeBlood);
      expect(wb, [DateTime(2024, 1, 10)]);
    });

    test('applyImport clears donor_number when empty in backup', () async {
      await DonationStorage.setDonorNumber('OLD');
      await DonationStorage.applyImport({
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyDonorNumber: '',
      });
      expect(await DonationStorage.getDonorNumber(), '');
    });

    test('getCombinedDonations merges types newest first', () async {
      await DonationStorage.applyImport({
        DonationStorage.keyDonations: ['2024-01-01T00:00:00.000'],
        DonationStorage.keyDonationsPlasma: ['2024-03-01T00:00:00.000'],
        DonationStorage.keyDonationsPlatelet: ['2024-02-15T00:00:00.000'],
        DonationStorage.keyDonationsDoubleRed: ['2024-01-20T00:00:00.000'],
      });

      final combined = await DonationStorage.getCombinedDonations();
      expect(combined.length, 4);
      expect(combined.map((e) => e.type).toList(), [
        DonationType.plasma,
        DonationType.platelet,
        DonationType.doubleRed,
        DonationType.wholeBlood,
      ]);
      expect(combined.first.date, DateTime(2024, 3, 1));
    });

    test('getEligibilityOverview respects per-type countdown', () async {
      await DonationStorage.applyImport({
        DonationStorage.keyDonations: ['2024-01-01T00:00:00.000'],
        DonationStorage.keyDonationsPlasma: <String>[],
        DonationStorage.keyDonationsPlatelet: ['2024-06-01T00:00:00.000'],
        DonationStorage.keyDonationsDoubleRed: <String>[],
        DonationStorage.keyCountdownDays: 56,
        DonationStorage.keyCountdownDaysPlatelet: 7,
      });

      final rows = await DonationStorage.getEligibilityOverview(
        now: DateTime(2024, 6, 10),
      );
      expect(rows.length, 4);
      expect(rows.map((r) => r.type).toList(), DonationType.values);

      final wb = rows.firstWhere((r) => r.type == DonationType.wholeBlood);
      expect(wb.hasDonations, isTrue);
      expect(wb.eligibleNow, isTrue);
      expect(wb.nextEligible, DateTime(2024, 2, 26));

      final plasma = rows.firstWhere((r) => r.type == DonationType.plasma);
      expect(plasma.hasDonations, isFalse);

      final plt = rows.firstWhere((r) => r.type == DonationType.platelet);
      expect(plt.eligibleNow, isTrue);
      expect(plt.nextEligible, DateTime(2024, 6, 8));
    });

    test('journey hint shows for 1–2 whole blood donations', () async {
      expect(await DonationStorage.shouldShowDoubleRedJourneyHint(), isFalse);

      await DonationStorage.applyImport({
        DonationStorage.keyDonations: ['2024-01-01T00:00:00.000'],
        DonationStorage.keyDonationsPlasma: <String>[],
        DonationStorage.keyDonationsPlatelet: <String>[],
        DonationStorage.keyDonationsDoubleRed: <String>[],
      });
      expect(await DonationStorage.shouldShowDoubleRedJourneyHint(), isTrue);

      await DonationStorage.applyImport({
        DonationStorage.keyDonations: [
          '2024-03-01T00:00:00.000',
          '2024-01-01T00:00:00.000',
        ],
        DonationStorage.keyDonationsPlasma: <String>[],
        DonationStorage.keyDonationsPlatelet: <String>[],
        DonationStorage.keyDonationsDoubleRed: <String>[],
      });
      expect(await DonationStorage.shouldShowDoubleRedJourneyHint(), isTrue);

      await DonationStorage.setJourneyHintDoubleRedDismissed(true);
      expect(await DonationStorage.shouldShowDoubleRedJourneyHint(), isFalse);
    });
  });
}
