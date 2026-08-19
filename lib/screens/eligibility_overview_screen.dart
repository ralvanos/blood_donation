import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/typed_donation.dart';
import '../services/donation_storage.dart';

/// Next eligible date for every donation type (uses each type's countdown).
class EligibilityOverviewScreen extends StatefulWidget {
  const EligibilityOverviewScreen({super.key});

  @override
  State<EligibilityOverviewScreen> createState() =>
      _EligibilityOverviewScreenState();
}

class _EligibilityOverviewScreenState extends State<EligibilityOverviewScreen> {
  List<TypeEligibility> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DonationStorage.getEligibilityOverview();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD3180C)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  'Next eligible date for each type, using your per-type countdown settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                for (final row in _rows) ...[
                  _EligibilityCard(row: row),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({required this.row});

  final TypeEligibility row;

  @override
  Widget build(BuildContext context) {
    final type = row.type;
    final accent = type.accent;
    final String statusLabel;
    final String detail;
    final Color statusColor;

    if (!row.hasDonations) {
      statusLabel = 'No donations yet';
      detail = 'Log a ${type.displayName.toLowerCase()} donation to start the countdown.';
      statusColor = Colors.white54;
    } else if (row.eligibleNow) {
      statusLabel = 'Eligible now';
      detail =
          'Since ${DateFormat('MMM d, y').format(row.nextEligible!)} · ${row.countdownDays}-day interval';
      statusColor = const Color(0xFF4CAF50);
    } else {
      final days = row.daysUntil!;
      statusLabel = 'In $days day${days == 1 ? '' : 's'}';
      detail =
          'Next: ${DateFormat('EEEE, MMM d, y').format(row.nextEligible!)} · ${row.countdownDays}-day interval';
      statusColor = accent;
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
}
