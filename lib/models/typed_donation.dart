import 'donation_arm.dart';
import 'donation_type.dart';

/// A stored donation date with an optional needle-access arm (no product type).
class DonationEntry {
  const DonationEntry({
    required this.date,
    this.arm,
  });

  final DateTime date;
  final DonationArm? arm;
}

/// A donation date tagged with its product type (for combined history).
class TypedDonation {
  const TypedDonation({
    required this.type,
    required this.date,
    this.arm,
  });

  final DonationType type;
  final DateTime date;
  final DonationArm? arm;
}

/// Per-type eligibility snapshot for the overview screen.
class TypeEligibility {
  const TypeEligibility({
    required this.type,
    required this.countdownDays,
    this.waitDays,
    this.lastDonation,
    this.nextEligible,
    this.daysUntil,
    this.blockingDonation,
    this.annualCapReached = false,
    this.donationsInLastYear = 0,
  });

  final DonationType type;
  final int countdownDays;
  final int? waitDays;
  final DateTime? lastDonation;
  final DateTime? nextEligible;

  /// Days until eligible (0 = eligible now). Null when there are no donations.
  final int? daysUntil;

  /// Visit that currently sets the longest wait for [type].
  final TypedDonation? blockingDonation;

  final bool annualCapReached;
  final int donationsInLastYear;

  int get appliedWaitDays => waitDays ?? countdownDays;

  bool get hasDonations => lastDonation != null;

  bool get eligibleNow => nextEligible != null && daysUntil == 0;
}
