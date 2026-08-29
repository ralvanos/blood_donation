import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/eligibility_matrix.dart';
import '../models/typed_donation.dart';
import '../services/donation_storage.dart';
import '../widgets/eligibility_calendar.dart';
import '../widgets/eligibility_matrix_table.dart';

/// Next eligible date for every type, cross-product matrix, and calendar.
class EligibilityOverviewScreen extends StatefulWidget {
  const EligibilityOverviewScreen({super.key});

  @override
  State<EligibilityOverviewScreen> createState() =>
      _EligibilityOverviewScreenState();
}

class _EligibilityOverviewScreenState extends State<EligibilityOverviewScreen> {
  EligibilitySnapshot? _snapshot;
  List<TypedDonation> _donations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshot = await DonationStorage.getEligibilitySnapshot();
    final donations = await DonationStorage.getCombinedDonations();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _donations = donations;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Eligibility overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading || snapshot == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD3180C)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  snapshot.hasHistory
                      ? 'Based on your last donation'
                      : 'Log a donation to start wait times. New donors can typically give any type their center allows.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                if (snapshot.lastDonation != null) ...[
                  const SizedBox(height: 10),
                  _LastDonationBanner(donation: snapshot.lastDonation!),
                ],
                const SizedBox(height: 16),
                for (final row in snapshot.rows) ...[
                  _EligibilityCard(row: row, hasHistory: snapshot.hasHistory),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                EligibilityMatrixTable(
                  lastType: snapshot.lastDonation?.type,
                ),
                const SizedBox(height: 16),
                EligibilityCalendar(
                  snapshot: snapshot,
                  donations: _donations,
                ),
                const SizedBox(height: 12),
                Text(
                  'Centers set the final rules, including overlapping products and yearly caps. This screen is a personal planner — not medical advice.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LastDonationBanner extends StatelessWidget {
  const _LastDonationBanner({required this.donation});

  final TypedDonation donation;

  @override
  Widget build(BuildContext context) {
    final type = donation.type;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: type.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: type.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(type.icon, color: type.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${type.displayName} · ${DateFormat('MMM d, y').format(donation.date)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({
    required this.row,
    required this.hasHistory,
  });

  final TypeEligibility row;
  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    final type = row.type;
    final accent = type.accent;
    final String statusLabel;
    final String detail;
    final Color statusColor;

    if (!hasHistory) {
      statusLabel = 'No donations yet';
      detail =
          'Log a donation to start the matrix. You can begin with ${type.displayName.toLowerCase()} if your center allows it.';
      statusColor = Colors.white54;
    } else if (row.eligibleNow) {
      statusLabel = 'Eligible now';
      statusColor = const Color(0xFF4CAF50);
      detail = _constraintDetail(row);
    } else {
      final days = row.daysUntil!;
      statusLabel = 'In $days day${days == 1 ? '' : 's'}';
      statusColor = accent;
      detail =
          'Next: ${DateFormat('EEEE, MMM d, y').format(row.nextEligible!)}\n'
          '${_constraintDetail(row)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(type.icon, color: accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _constraintDetail(TypeEligibility row) {
    final blocking = row.blockingDonation;
    final cap = EligibilityMatrix.annualCaps[row.type] ?? 0;
    final parts = <String>[];
    if (blocking != null) {
      parts.add(
        'After ${blocking.type.displayName.toLowerCase()} on '
        '${DateFormat('MMM d, y').format(blocking.date)} · '
        '${row.appliedWaitDays}-day wait',
      );
    }
    if (row.annualCapReached) {
      parts.add('Yearly cap (${row.donationsInLastYear}/$cap)');
    } else if (row.donationsInLastYear > 0 && cap > 0) {
      parts.add('${row.donationsInLastYear} of $cap in the last year');
    }
    if (parts.isEmpty) {
      return '${row.countdownDays}-day same-type interval';
    }
    return parts.join('\n');
  }
}
