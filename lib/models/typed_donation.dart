import 'donation_type.dart';

/// A donation date tagged with its product type (for combined history).
class TypedDonation {
  const TypedDonation({
    required this.type,
    required this.date,
  });

  final DonationType type;
  final DateTime date;
}

/// Per-type eligibility snapshot for the overview screen.
class TypeEligibility {
  const TypeEligibility({
    required this.type,
    required this.countdownDays,
    this.lastDonation,
    this.nextEligible,
    this.daysUntil,
  });

  final DonationType type;
  final int countdownDays;
  final DateTime? lastDonation;
  final DateTime? nextEligible;

  /// Days until eligible (0 = eligible now). Null when there are no donations.
  final int? daysUntil;

  bool get hasDonations => lastDonation != null;

  bool get eligibleNow => hasDonations && daysUntil == 0;
}
