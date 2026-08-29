import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/donation_type.dart';
import '../models/eligibility_matrix.dart';
import '../models/typed_donation.dart';

/// Month grid: past donations as dots, first-eligible days outlined.
class EligibilityCalendar extends StatefulWidget {
  const EligibilityCalendar({
    super.key,
    required this.snapshot,
    required this.donations,
  });

  final EligibilitySnapshot snapshot;
  final List<TypedDonation> donations;

  @override
  State<EligibilityCalendar> createState() => _EligibilityCalendarState();
}

class _EligibilityCalendarState extends State<EligibilityCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  List<TypedDonation> _donationsOn(DateTime day) {
    return widget.donations
        .where(
          (d) =>
              d.date.year == day.year &&
              d.date.month == day.month &&
              d.date.day == day.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white70),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM y').format(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final label in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < ((leading + daysInMonth) / 7).ceil(); row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _buildDayCell(
                        dayNum: row * 7 + col - leading + 1,
                        daysInMonth: daysInMonth,
                        todayOnly: todayOnly,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Dots are logged donations. Outlines mark the first day you could donate that type.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required int dayNum,
    required int daysInMonth,
    required DateTime todayOnly,
  }) {
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 44);
    }
    final day = DateTime(_month.year, _month.month, dayNum);
    final isToday = day == todayOnly;
    final logged = _donationsOn(day);
    final firstTypes = [
      for (final type in DonationType.values)
        if (widget.snapshot.isFirstEligibleDay(day, type)) type,
    ];
    final eligible = widget.snapshot.eligibleTypesOn(day);
    final outline = firstTypes.isEmpty ? null : firstTypes.first.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDaySheet(day, logged, eligible, firstTypes),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isToday
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: outline ??
                  (isToday
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.transparent),
              width: outline != null ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final d in logged.take(4))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: d.type.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDaySheet(
    DateTime day,
    List<TypedDonation> logged,
    List<DonationType> eligible,
    List<DonationType> firstTypes,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            20 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMM d, y').format(day),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (logged.isEmpty)
                Text(
                  'No donations logged this day.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                )
              else ...[
                Text(
                  'Logged',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                for (final d in logged)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      d.type.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: d.type.accent,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                widget.snapshot.hasHistory
                    ? 'Could donate (typical waits)'
                    : 'No history yet — any type can be logged',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in DonationType.values)
                    _TypeChip(
                      type: type,
                      enabled: eligible.contains(type),
                      firstDay: firstTypes.contains(type),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Always confirm with your donation center. This is not medical advice.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.enabled,
    required this.firstDay,
  });

  final DonationType type;
  final bool enabled;
  final bool firstDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? type.accent.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? type.accent.withValues(alpha: firstDay ? 0.9 : 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        enabled
            ? (firstDay ? '${type.shortLabel} · first day' : type.shortLabel)
            : '${type.shortLabel} · not yet',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: enabled
              ? (type.accentIsLight ? type.onAccent : type.accent)
              : Colors.white38,
        ),
      ),
    );
  }
}
