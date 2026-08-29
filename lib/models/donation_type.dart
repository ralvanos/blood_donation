import 'package:flutter/material.dart';

/// Tracked donation product. Whole blood keeps the legacy `donations` prefs key.
enum DonationType {
  wholeBlood,
  plasma,
  platelet,
  doubleRed;

  static const String prefsKeyActive = 'active_donation_type';

  /// Stable id stored in SharedPreferences / JSON backups.
  String get id => switch (this) {
        DonationType.wholeBlood => 'whole_blood',
        DonationType.plasma => 'plasma',
        DonationType.platelet => 'platelet',
        DonationType.doubleRed => 'double_red',
      };

  /// SharedPreferences list key for ISO date strings.
  String get donationsPrefsKey => switch (this) {
        // Legacy key — existing installs stay valid as whole blood.
        DonationType.wholeBlood => 'donations',
        DonationType.plasma => 'donations_plasma',
        DonationType.platelet => 'donations_platelet',
        DonationType.doubleRed => 'donations_double_red',
      };

  /// Backup key for unused countdown prefs. Whole blood keeps legacy `countdown_days`.
  String get countdownPrefsKey => switch (this) {
        DonationType.wholeBlood => 'countdown_days',
        DonationType.plasma => 'countdown_days_plasma',
        DonationType.platelet => 'countdown_days_platelet',
        DonationType.doubleRed => 'countdown_days_double_red',
      };

  int get defaultCountdownDays => switch (this) {
        DonationType.wholeBlood => 56,
        DonationType.plasma => 28,
        DonationType.platelet => 7,
        DonationType.doubleRed => 112,
      };

  /// Approximate volume used for UI totals (not stored per record).
  /// Platelets: typical single apheresis yield is ~200–300 ml concentrate; 250 ml is a mid estimate.
  int get mlPerDonation => switch (this) {
        DonationType.wholeBlood => 500,
        DonationType.plasma => 650,
        DonationType.platelet => 250,
        DonationType.doubleRed => 400,
      };

  String get shortLabel => switch (this) {
        DonationType.wholeBlood => 'Whole',
        DonationType.plasma => 'Plasma',
        DonationType.platelet => 'Plt',
        DonationType.doubleRed => 'Dbl Red',
      };

  String get displayName => switch (this) {
        DonationType.wholeBlood => 'Whole Blood',
        DonationType.plasma => 'Plasma',
        DonationType.platelet => 'Platelets',
        DonationType.doubleRed => 'Double Red / Power Red',
      };

  /// Soft donor-journey guidance (not an unlock gate).
  String get journeyLabel => switch (this) {
        DonationType.wholeBlood => 'Start here / New donor',
        DonationType.plasma ||
        DonationType.platelet =>
          'Frequent / Maximize impact',
        DonationType.doubleRed => 'Advanced / High impact',
      };

  String get volumeUnitLabel => switch (this) {
        DonationType.wholeBlood => 'pint (~$mlPerDonation ml)',
        DonationType.plasma => '~$mlPerDonation ml plasma',
        DonationType.platelet =>
          '~$mlPerDonation ml platelet concentrate (approx.)',
        DonationType.doubleRed => '~$mlPerDonation ml RBC (2 units)',
      };

  /// Primary accent for charts, FAB, ring, cards, and selected segments.
  Color get accent => switch (this) {
        DonationType.wholeBlood => const Color(0xFFD3180C),
        DonationType.plasma => const Color(0xFFF4C430),
        // Slightly warmer/brighter than raw peach for icon contrast on dark UI.
        DonationType.platelet => const Color(0xFFFFCFA0),
        DonationType.doubleRed => const Color(0xFF800000),
      };

  /// Visible companion accent (icons, milestones, gradient highlights) on dark UI.
  Color get accentSecondary => switch (this) {
        DonationType.wholeBlood => const Color(0xFF8B0000),
        DonationType.plasma => const Color(0xFFFFD700),
        DonationType.platelet => const Color(0xFFFFFACD),
        // Keep maroon family but readable as icon/text on dark scaffold.
        DonationType.doubleRed => const Color(0xFFA52A2A),
      };

  /// Deeper fill for chart underlays / heavy gradients (brand darks).
  Color get accentDeep => switch (this) {
        DonationType.wholeBlood => const Color(0xFF8B0000),
        DonationType.plasma => const Color(0xFFC9A227),
        DonationType.platelet => const Color(0xFFFFDAB9),
        DonationType.doubleRed => const Color(0xFF4A0404),
      };

  /// Brand peach for platelets (cloudy chart fill); [accent] is the brighter UI tint.
  Color get brandAccent => switch (this) {
        DonationType.platelet => const Color(0xFFFFDAB9),
        _ => accent,
      };

  /// Whether [accent] is light enough that dark foreground text is needed on top.
  bool get accentIsLight => switch (this) {
        DonationType.plasma || DonationType.platelet => true,
        _ => false,
      };

  /// Foreground on solid accent backgrounds (FAB, selected chips).
  Color get onAccent => accentIsLight ? const Color(0xFF1A1208) : Colors.white;

  /// Chart area fill opacity — plasma/platelet get a softer translucent/cloudy look.
  double get chartFillOpacity => switch (this) {
        DonationType.plasma => 0.35,
        DonationType.platelet => 0.42,
        _ => 0.3,
      };

  IconData get icon => switch (this) {
        DonationType.wholeBlood => Icons.bloodtype_rounded,
        DonationType.plasma => Icons.water_drop_rounded,
        DonationType.platelet => Icons.bubble_chart_rounded,
        DonationType.doubleRed => Icons.opacity_rounded,
      };

  /// Typical setup — guidance only; centers and machines vary.
  bool get typicallyDualNeedle => this == DonationType.platelet;

  /// Short copy for the arm picker (not medical advice).
  String get needleGuidance => switch (this) {
        DonationType.wholeBlood =>
          'Whole blood uses a single needle. Alternating arms can help reduce '
              'venous fibrosis from repeated sticks.',
        DonationType.plasma =>
          'Plasma is typically a single needle — blood goes out and back through '
              'the same arm.',
        DonationType.platelet =>
          'Platelets often use two needles (one in each arm), depending on the '
              'machine. Some centers use a single needle.',
        DonationType.doubleRed =>
          'Double Red is typically a single needle — blood goes out and back '
              'through the same arm.',
      };

  static DonationType fromId(String? id) {
    for (final type in DonationType.values) {
      if (type.id == id) return type;
    }
    return DonationType.wholeBlood;
  }
}
