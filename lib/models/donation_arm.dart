/// Needle-access arm for a donation. Optional on every record.
///
/// Whole blood, plasma, and double red are typically a single needle (L or R).
/// Platelets may be dual-needle (**Both**) or single-needle, depending on equipment.
enum DonationArm {
  left,
  right,
  both;

  /// Stored in backups and on-device records (`L` / `R` / `both`).
  String get id => switch (this) {
        DonationArm.left => 'L',
        DonationArm.right => 'R',
        DonationArm.both => 'both',
      };

  /// Compact history chip.
  String get tag => switch (this) {
        DonationArm.left => 'L',
        DonationArm.right => 'R',
        DonationArm.both => 'Both',
      };

  String get displayName => switch (this) {
        DonationArm.left => 'Left',
        DonationArm.right => 'Right',
        DonationArm.both => 'Both arms',
      };

  /// Opposite single-needle arm, for alternation hints. Null for dual-needle.
  DonationArm? get opposite => switch (this) {
        DonationArm.left => DonationArm.right,
        DonationArm.right => DonationArm.left,
        DonationArm.both => null,
      };

  bool get isSingleNeedle =>
      this == DonationArm.left || this == DonationArm.right;

  static DonationArm? tryFromId(Object? id) {
    if (id is! String) return null;
    final normalized = id.trim().toLowerCase();
    return switch (normalized) {
      'l' || 'left' => DonationArm.left,
      'r' || 'right' => DonationArm.right,
      'both' || 'dual' || 'b' => DonationArm.both,
      _ => null,
    };
  }
}
