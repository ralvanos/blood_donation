import 'donation_type.dart';
import 'typed_donation.dart';

/// Wait days from last product to next product.
///
/// Same-type and cross-type waits both use the fixed donor wait table —
/// donation centers set the final rules.
class EligibilityMatrix {
  EligibilityMatrix._();

  /// Rolling 12-month caps (Red Cross-style). Advisory only.
  static const Map<DonationType, int> annualCaps = {
    DonationType.wholeBlood: 6,
    DonationType.plasma: 13,
    DonationType.platelet: 24,
    DonationType.doubleRed: 3,
  };

  /// Cross-product waits when [from] != [to]. Diagonal is unused here.
  ///
  /// Current donation (rows) → next type (columns):
  /// Whole Blood: 56 / 56 / 7 / 56
  /// Plasma:      28 / 28 / 7 / 28
  /// Platelets:    7 /  7 / 7 /  7
  /// Double Red: 112 /112 /112 /112
  static const Map<DonationType, Map<DonationType, int>> crossWaitDays = {
    DonationType.wholeBlood: {
      DonationType.plasma: 56,
      DonationType.platelet: 7,
      DonationType.doubleRed: 56,
    },
    DonationType.plasma: {
      DonationType.wholeBlood: 28,
      DonationType.platelet: 7,
      DonationType.doubleRed: 28,
    },
    DonationType.platelet: {
      DonationType.wholeBlood: 7,
      DonationType.plasma: 7,
      DonationType.doubleRed: 7,
    },
    DonationType.doubleRed: {
      DonationType.wholeBlood: 112,
      DonationType.plasma: 112,
      DonationType.platelet: 112,
    },
  };

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Calendar-day add (avoids DST shifting local midnight).
  static DateTime addDays(DateTime date, int days) {
    final d = dateOnly(date);
    return DateTime(d.year, d.month, d.day + days);
  }

  static DateTime addYears(DateTime date, int years) {
    final d = dateOnly(date);
    return DateTime(d.year + years, d.month, d.day);
  }

  /// Days to wait after [from] before [to] is allowed (fixed wait table).
  static int waitDays({
    required DonationType from,
    required DonationType to,
  }) {
    if (from == to) return from.defaultCountdownDays;
    return crossWaitDays[from]?[to] ?? to.defaultCountdownDays;
  }

  static EligibilitySnapshot evaluate({
    required List<TypedDonation> donations,
    DateTime? now,
  }) {
    final today = dateOnly(now ?? DateTime.now());
    final sorted = donations
        .map(
          (d) => TypedDonation(
            type: d.type,
            date: dateOnly(d.date),
            arm: d.arm,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return a.type.index.compareTo(b.type.index);
      });

    final lastDonation = sorted.isEmpty ? null : sorted.first;
    final byType = <DonationType, TypeEligibility>{};

    for (final target in DonationType.values) {
      final countdown = target.defaultCountdownDays;
      if (sorted.isEmpty) {
        byType[target] = TypeEligibility(
          type: target,
          countdownDays: countdown,
          waitDays: countdown,
        );
        continue;
      }

      DateTime? next;
      TypedDonation? blocking;
      var waitUsed = countdown;

      for (final donation in sorted) {
        final wait = waitDays(
          from: donation.type,
          to: target,
        );
        final candidate = addDays(donation.date, wait);
        if (next == null || candidate.isAfter(next)) {
          next = candidate;
          blocking = donation;
          waitUsed = wait;
        }
      }

      final ofType = sorted
          .where((d) => d.type == target)
          .map((d) => d.date)
          .toList()
        ..sort();
      final windowStart = addDays(today, -365);
      final inWindow = ofType.where((d) => !d.isBefore(windowStart)).toList();
      final cap = annualCaps[target] ?? 99;
      var annualCapReached = false;
      if (inWindow.length >= cap) {
        final capNext = addYears(inWindow[inWindow.length - cap], 1);
        if (next == null || capNext.isAfter(next)) {
          next = capNext;
          annualCapReached = true;
        }
      }

      final daysUntil = next!.difference(today).inDays.clamp(0, 999);
      byType[target] = TypeEligibility(
        type: target,
        countdownDays: countdown,
        waitDays: waitUsed,
        lastDonation: ofType.isEmpty ? null : ofType.last,
        nextEligible: next,
        daysUntil: daysUntil,
        blockingDonation: blocking,
        annualCapReached: annualCapReached,
        donationsInLastYear: inWindow.length,
      );
    }

    DateTime? soonestEligible;
    DonationType? soonestType;
    if (lastDonation != null) {
      for (final type in DonationType.values) {
        final next = byType[type]!.nextEligible!;
        if (soonestEligible == null || next.isBefore(soonestEligible)) {
          soonestEligible = next;
          soonestType = type;
        }
      }
    }

    return EligibilitySnapshot(
      lastDonation: lastDonation,
      byType: byType,
      soonestEligible: soonestEligible,
      soonestType: soonestType,
    );
  }
}

class EligibilitySnapshot {
  const EligibilitySnapshot({
    required this.byType,
    this.lastDonation,
    this.soonestEligible,
    this.soonestType,
  });

  final TypedDonation? lastDonation;
  final Map<DonationType, TypeEligibility> byType;
  final DateTime? soonestEligible;
  final DonationType? soonestType;

  bool get hasHistory => lastDonation != null;

  List<TypeEligibility> get rows => [
        for (final type in DonationType.values) byType[type]!,
      ];

  TypeEligibility row(DonationType type) => byType[type]!;

  List<DonationType> eligibleTypesOn(DateTime day) {
    final d = EligibilityMatrix.dateOnly(day);
    if (!hasHistory) return List<DonationType>.from(DonationType.values);
    return [
      for (final type in DonationType.values)
        if (!row(type).nextEligible!.isAfter(d)) type,
    ];
  }

  bool isFirstEligibleDay(DateTime day, DonationType type) {
    final next = row(type).nextEligible;
    if (next == null) return false;
    return EligibilityMatrix.dateOnly(day) == EligibilityMatrix.dateOnly(next);
  }
}
