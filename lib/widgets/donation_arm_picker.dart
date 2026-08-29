import 'package:flutter/material.dart';

import '../models/donation_arm.dart';
import '../models/donation_type.dart';

/// Result of the arm picker. Null from [showDonationArmPicker] means cancelled
/// (edit: leave unchanged). [skipped] means save without a tag.
class DonationArmPick {
  const DonationArmPick.selected(this.arm)
      : skipped = false,
        cleared = false;

  const DonationArmPick.skipped()
      : arm = null,
        skipped = true,
        cleared = false;

  const DonationArmPick.cleared()
      : arm = null,
        skipped = false,
        cleared = true;

  final DonationArm? arm;
  final bool skipped;
  final bool cleared;
}

Future<DonationArmPick?> showDonationArmPicker({
  required BuildContext context,
  required DonationType type,
  required Color accent,
  DonationArm? current,
  DonationArm? lastSingleArm,
  bool allowClear = false,
}) {
  return showModalBottomSheet<DonationArmPick>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return _DonationArmPickerSheet(
        type: type,
        accent: accent,
        current: current,
        lastSingleArm: lastSingleArm,
        allowClear: allowClear,
      );
    },
  );
}

class _DonationArmPickerSheet extends StatelessWidget {
  const _DonationArmPickerSheet({
    required this.type,
    required this.accent,
    required this.current,
    required this.lastSingleArm,
    required this.allowClear,
  });

  final DonationType type;
  final Color accent;
  final DonationArm? current;
  final DonationArm? lastSingleArm;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    final lastArm = lastSingleArm;
    final suggested = lastArm?.opposite;
    final options = <DonationArm>[
      if (type.typicallyDualNeedle) DonationArm.both,
      DonationArm.left,
      DonationArm.right,
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Which arm?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            type.needleGuidance,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          if (lastArm != null && suggested != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last tagged ${type.shortLabel.toLowerCase()} was '
              '${lastArm.displayName}. Consider ${suggested.displayName} '
              'this time to alternate.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: accent,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final arm in options)
                _ArmChoiceChip(
                  arm: arm,
                  accent: accent,
                  selected: current == arm,
                  suggested: suggested == arm,
                  onTap: () => Navigator.pop(
                    context,
                    DonationArmPick.selected(arm),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.pop(
                context,
                const DonationArmPick.skipped(),
              ),
              child: Text(
                'Not sure',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          ),
          if (allowClear && current != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  const DonationArmPick.cleared(),
                ),
                child: Text(
                  'Clear arm tag',
                  style: TextStyle(color: accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArmChoiceChip extends StatelessWidget {
  const _ArmChoiceChip({
    required this.arm,
    required this.accent,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  final DonationArm arm;
  final Color accent;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.85)
                  : suggested
                      ? accent.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                arm.tag,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                arm.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact L / R / Both badge for history rows.
class ArmTag extends StatelessWidget {
  const ArmTag({
    super.key,
    required this.arm,
    required this.accent,
    this.onAccent,
  });

  final DonationArm arm;
  final Color accent;
  final Color? onAccent;

  @override
  Widget build(BuildContext context) {
    final fg = onAccent ?? accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        arm.tag,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
