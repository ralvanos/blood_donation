import 'donation_type.dart';

/// Scope for the Statistics screen dual mode.
enum StatisticsScope {
  thisType,
  allTypes;

  static const String prefsKey = 'stats_scope';
  static const String legendPrefsKey = 'stats_legend_visible';

  String get prefsValue => switch (this) {
        StatisticsScope.thisType => 'this_type',
        StatisticsScope.allTypes => 'all_types',
      };

  static StatisticsScope fromPrefs(String? raw) {
    if (raw == StatisticsScope.allTypes.prefsValue) {
      return StatisticsScope.allTypes;
    }
    return StatisticsScope.thisType;
  }
}

/// Single-type summary (active Home type).
class ThisTypeStatistics {
  const ThisTypeStatistics({
    required this.totalDonations,
    required this.averageDaysBetween,
    required this.longestGapDays,
  });

  final int totalDonations;
  final double averageDaysBetween;
  final int longestGapDays;

  static ThisTypeStatistics fromDonations(List<DateTime> donations) {
    final sorted = List<DateTime>.from(donations)
      ..sort((a, b) => a.compareTo(b));
    final total = sorted.length;
    var averageDays = 0.0;
    var longestGap = 0;

    if (total > 1) {
      var totalDays = 0;
      for (var i = 1; i < total; i++) {
        final gap = sorted[i].difference(sorted[i - 1]).inDays;
        totalDays += gap;
        if (gap > longestGap) longestGap = gap;
      }
      averageDays = totalDays / (total - 1);
    }

    return ThisTypeStatistics(
      totalDonations: total,
      averageDaysBetween: averageDays,
      longestGapDays: longestGap,
    );
  }
}

/// Cross-type summary for All types mode.
class AllTypesStatistics {
  const AllTypesStatistics({
    required this.totalVisits,
    required this.totalVolumeMl,
    required this.typesUsed,
    required this.typesTotal,
    this.soonestEligible,
    this.soonestType,
  });

  final int totalVisits;
  final int totalVolumeMl;
  final int typesUsed;
  final int typesTotal;
  final DateTime? soonestEligible;
  final DonationType? soonestType;

  String get typesUsedLabel => '$typesUsed of $typesTotal';

  static AllTypesStatistics fromDonationsByType({
    required Map<DonationType, List<DateTime>> donationsByType,
    Map<DonationType, int>? countdownDaysByType,
    DateTime? now,
  }) {
    var totalVisits = 0;
    var totalVolumeMl = 0;
    var typesUsed = 0;

    for (final type in DonationType.values) {
      final count = donationsByType[type]?.length ?? 0;
      if (count > 0) typesUsed++;
      totalVisits += count;
      totalVolumeMl += count * type.mlPerDonation;
    }

    DateTime? soonest;
    DonationType? soonestType;
    final today = _dateOnly(now ?? DateTime.now());

    if (countdownDaysByType != null) {
      for (final type in DonationType.values) {
        final dates = donationsByType[type];
        if (dates == null || dates.isEmpty) continue;
        final countdown =
            countdownDaysByType[type] ?? type.defaultCountdownDays;
        final last = dates.reduce((a, b) => a.isAfter(b) ? a : b);
        final eligible = _dateOnly(last).add(Duration(days: countdown));
        if (soonest == null || eligible.isBefore(soonest)) {
          soonest = eligible;
          soonestType = type;
        }
      }
    }

    // Surface "eligible now" as today when past due.
    if (soonest != null && soonest.isBefore(today)) {
      soonest = today;
    }

    return AllTypesStatistics(
      totalVisits: totalVisits,
      totalVolumeMl: totalVolumeMl,
      typesUsed: typesUsed,
      typesTotal: DonationType.values.length,
      soonestEligible: soonest,
      soonestType: soonestType,
    );
  }
}

/// Default legend: types with ≥1 donation visible; empty types hidden.
Set<DonationType> defaultLegendVisibility(
  Map<DonationType, List<DateTime>> donationsByType,
) {
  final visible = <DonationType>{};
  for (final type in DonationType.values) {
    if ((donationsByType[type] ?? const []).isNotEmpty) {
      visible.add(type);
    }
  }
  // If nothing logged yet, show all four so the empty chart UX is clear.
  if (visible.isEmpty) {
    return DonationType.values.toSet();
  }
  return visible;
}

/// Parse persisted legend type ids; null → use [defaultLegendVisibility].
Set<DonationType>? legendFromPrefs(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final ids = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
  final result = <DonationType>{};
  for (final id in ids) {
    for (final type in DonationType.values) {
      if (type.id == id) {
        result.add(type);
        break;
      }
    }
  }
  return result;
}

String legendToPrefs(Set<DonationType> visible) {
  return DonationType.values
      .where(visible.contains)
      .map((t) => t.id)
      .join(',');
}

/// Ascending cumulative series for a single type (x = visit index).
List<({double x, double y, DateTime date})> thisTypeTrendSpots(
  List<DateTime> donations,
) {
  final sorted = List<DateTime>.from(donations)
    ..sort((a, b) => a.compareTo(b));
  return [
    for (var i = 0; i < sorted.length; i++)
      (x: i.toDouble(), y: (i + 1).toDouble(), date: sorted[i]),
  ];
}

/// Shared chronological timeline; each visible type gets cumulative Y at every
/// timeline date (steps only when that type donated).
({
  List<DateTime> timeline,
  Map<DonationType, List<({double x, double y})>> series,
}) allTypesTrendSeries({
  required Map<DonationType, List<DateTime>> donationsByType,
  required Set<DonationType> visibleTypes,
}) {
  final dateSet = <DateTime>{};
  for (final type in DonationType.values) {
    if (!visibleTypes.contains(type)) continue;
    for (final d in donationsByType[type] ?? const <DateTime>[]) {
      dateSet.add(_dateOnly(d));
    }
  }
  final timeline = dateSet.toList()..sort((a, b) => a.compareTo(b));

  final series = <DonationType, List<({double x, double y})>>{};
  for (final type in DonationType.values) {
    if (!visibleTypes.contains(type)) continue;
    final typeDates = {
      for (final d in donationsByType[type] ?? const <DateTime>[]) _dateOnly(d),
    };
    if (typeDates.isEmpty) continue;

    var cumulative = 0;
    var started = false;
    final spots = <({double x, double y})>[];
    for (var i = 0; i < timeline.length; i++) {
      if (typeDates.contains(timeline[i])) {
        cumulative++;
        started = true;
      }
      // Start each series at that type’s first visit (no leading zeros).
      if (started) {
        spots.add((x: i.toDouble(), y: cumulative.toDouble()));
      }
    }
    series[type] = spots;
  }

  return (timeline: timeline, series: series);
}

/// Compact legend / chip label (Double Red without “Power Red”).
String statisticsLegendLabel(DonationType type) => switch (type) {
      DonationType.wholeBlood => 'Whole Blood',
      DonationType.plasma => 'Plasma',
      DonationType.platelet => 'Platelets',
      DonationType.doubleRed => 'Double Red',
    };

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
