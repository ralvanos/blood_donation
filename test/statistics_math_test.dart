import 'package:blood_donation/models/donation_type.dart';
import 'package:blood_donation/models/statistics_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThisTypeStatistics', () {
    test('handles empty and single donation', () {
      expect(ThisTypeStatistics.fromDonations([]).totalDonations, 0);
      expect(ThisTypeStatistics.fromDonations([]).averageDaysBetween, 0);
      expect(ThisTypeStatistics.fromDonations([]).longestGapDays, 0);

      final one = ThisTypeStatistics.fromDonations([DateTime(2024, 1, 1)]);
      expect(one.totalDonations, 1);
      expect(one.averageDaysBetween, 0);
      expect(one.longestGapDays, 0);
    });

    test('computes average and longest gap', () {
      final stats = ThisTypeStatistics.fromDonations([
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 11), // 10 days
        DateTime(2024, 2, 10), // 30 days
      ]);
      expect(stats.totalDonations, 3);
      expect(stats.longestGapDays, 30);
      expect(stats.averageDaysBetween, 20.0);
    });
  });

  group('AllTypesStatistics', () {
    test('sums visits and volume across types', () {
      final byType = {
        DonationType.wholeBlood: [
          DateTime(2024, 1, 1),
          DateTime(2024, 3, 1),
        ],
        DonationType.plasma: [DateTime(2024, 2, 1)],
        DonationType.platelet: <DateTime>[],
        DonationType.doubleRed: <DateTime>[],
      };

      final stats = AllTypesStatistics.fromDonationsByType(
        donationsByType: byType,
        now: DateTime(2024, 4, 1),
      );

      expect(stats.totalVisits, 3);
      expect(
        stats.totalVolumeMl,
        2 * DonationType.wholeBlood.mlPerDonation +
            DonationType.plasma.mlPerDonation,
      );
      expect(stats.typesUsed, 2);
      expect(stats.typesUsedLabel, '2 of 4');
    });

    test('finds soonest next eligibility across types', () {
      final byType = {
        // WB: Jan 1 + 56 → Feb 26; platelets from that visit open Jan 8.
        DonationType.wholeBlood: [DateTime(2024, 1, 1)],
        DonationType.plasma: [DateTime(2024, 1, 20)],
        DonationType.platelet: <DateTime>[],
        DonationType.doubleRed: <DateTime>[],
      };
      final stats = AllTypesStatistics.fromDonationsByType(
        donationsByType: byType,
        now: DateTime(2024, 2, 1),
      );

      expect(stats.soonestType, DonationType.platelet);
      expect(stats.soonestEligible, DateTime(2024, 2, 1));
    });

    test('clamps past-due eligibility to today', () {
      final byType = {
        DonationType.plasma: [DateTime(2023, 1, 1)],
        DonationType.wholeBlood: <DateTime>[],
        DonationType.platelet: <DateTime>[],
        DonationType.doubleRed: <DateTime>[],
      };
      final now = DateTime(2024, 6, 15);
      final stats = AllTypesStatistics.fromDonationsByType(
        donationsByType: byType,
        now: now,
      );

      expect(stats.soonestType, DonationType.platelet);
      expect(stats.soonestEligible, DateTime(2024, 6, 15));
    });
  });

  group('legend defaults and prefs', () {
    test('defaultLegendVisibility turns on types with data only', () {
      final byType = {
        DonationType.wholeBlood: [DateTime(2024, 1, 1)],
        DonationType.plasma: <DateTime>[],
        DonationType.platelet: [DateTime(2024, 2, 1)],
        DonationType.doubleRed: <DateTime>[],
      };
      expect(
        defaultLegendVisibility(byType),
        {DonationType.wholeBlood, DonationType.platelet},
      );
    });

    test('defaultLegendVisibility shows all when empty', () {
      final byType = {
        for (final t in DonationType.values) t: <DateTime>[],
      };
      expect(defaultLegendVisibility(byType), DonationType.values.toSet());
    });

    test('legend prefs round-trip preserves type order', () {
      final set = {DonationType.doubleRed, DonationType.plasma};
      final encoded = legendToPrefs(set);
      expect(encoded, 'plasma,double_red');
      expect(legendFromPrefs(encoded), set);
      expect(legendFromPrefs(null), isNull);
      expect(legendFromPrefs(''), isNull);
    });
  });

  group('trend series', () {
    test('thisTypeTrendSpots are cumulative by visit index', () {
      final spots = thisTypeTrendSpots([
        DateTime(2024, 3, 1),
        DateTime(2024, 1, 1),
      ]);
      expect(spots.length, 2);
      expect(spots[0].x, 0);
      expect(spots[0].y, 1);
      expect(spots[0].date, DateTime(2024, 1, 1));
      expect(spots[1].x, 1);
      expect(spots[1].y, 2);
    });

    test('allTypesTrendSeries builds shared timeline per type', () {
      final byType = {
        DonationType.wholeBlood: [
          DateTime(2024, 1, 1),
          DateTime(2024, 3, 1),
        ],
        DonationType.plasma: [DateTime(2024, 2, 1)],
        DonationType.platelet: <DateTime>[],
        DonationType.doubleRed: <DateTime>[],
      };

      final result = allTypesTrendSeries(
        donationsByType: byType,
        visibleTypes: {
          DonationType.wholeBlood,
          DonationType.plasma,
          DonationType.platelet,
        },
      );

      expect(result.timeline, [
        DateTime(2024, 1, 1),
        DateTime(2024, 2, 1),
        DateTime(2024, 3, 1),
      ]);
      // Platelets visible but empty → no series line.
      expect(result.series.containsKey(DonationType.platelet), isFalse);

      final wb = result.series[DonationType.wholeBlood]!;
      expect(wb.map((s) => (s.x, s.y)).toList(), [
        (0.0, 1.0),
        (1.0, 1.0),
        (2.0, 2.0),
      ]);

      final plasma = result.series[DonationType.plasma]!;
      // Starts at first plasma visit (timeline index 1), not a leading zero.
      expect(plasma.map((s) => (s.x, s.y)).toList(), [
        (1.0, 1.0),
        (2.0, 1.0),
      ]);
    });

    test('StatisticsScope prefs parsing', () {
      expect(StatisticsScope.fromPrefs(null), StatisticsScope.thisType);
      expect(
        StatisticsScope.fromPrefs('all_types'),
        StatisticsScope.allTypes,
      );
      expect(
        StatisticsScope.fromPrefs('this_type'),
        StatisticsScope.thisType,
      );
    });
  });
}
