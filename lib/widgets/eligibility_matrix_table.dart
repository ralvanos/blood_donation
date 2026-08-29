import 'package:flutter/material.dart';

import '../models/donation_type.dart';
import '../models/eligibility_matrix.dart';

/// Compact last→next wait table. Highlights the last donation's row.
class EligibilityMatrixTable extends StatelessWidget {
  const EligibilityMatrixTable({
    super.key,
    this.lastType,
  });

  final DonationType? lastType;

  @override
  Widget build(BuildContext context) {
    final types = DonationType.values;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wait days (last → next)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fixed wait table from last donation type to next. Advisory only — confirm with your center.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const FlexColumnWidth(1.15),
              for (var i = 1; i <= types.length; i++)
                i: const FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final type in types)
                    _HeadCell(label: type.shortLabel, color: type.accent),
                ],
              ),
              for (final from in types)
                TableRow(
                  decoration: BoxDecoration(
                    color: lastType == from
                        ? from.accent.withValues(alpha: 0.12)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Text(
                        from.shortLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: from.accent,
                        ),
                      ),
                    ),
                    for (final to in types)
                      _WaitCell(
                        days: EligibilityMatrix.waitDays(
                          from: from,
                          to: to,
                        ),
                        highlight: lastType == from,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _WaitCell extends StatelessWidget {
  const _WaitCell({required this.days, required this.highlight});

  final int days;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '$days',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          color: Colors.white.withValues(alpha: highlight ? 0.95 : 0.7),
        ),
      ),
    );
  }
}
