import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../services/donation_storage.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  List<DateTime> _donations = [];
  bool _loading = true;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final donations = await DonationStorage.getDonations();
    if (mounted) {
      setState(() {
        _donations = donations;
        _loading = false;
      });
    }
  }

  Future<bool> _confirmDeleteDonation(DateTime date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Remove donation?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove donation on ${DateFormat.yMMMd().format(date)}?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (confirm != true) return false;

    await DonationStorage.removeDonation(date);
    if (!mounted) return true;
    await _load();
    _hasChanged = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanged);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D0D),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Donation history',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE53935)),
              )
            : _donations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bloodtype_rounded, size: 64, color: Colors.white.withValues(alpha:0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No donations yet',
                          style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha:0.5)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add donations from the main screen.',
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha:0.4)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _donations.length,
                    itemBuilder: (context, index) {
                      final date = _donations[index];
                      return Dismissible(
                        key: ValueKey('$index-${date.toIso8601String()}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withValues(alpha:0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmDeleteDonation(date),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha:0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.bloodtype_rounded, color: Color(0xFFE53935), size: 26),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('EEEE, MMM d').format(date),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        DateFormat.y().format(date),
                                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha:0.5)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '1 pint (~$kMlPerDonation ml)',
                                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha:0.7)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _confirmDeleteDonation(date),
                                  icon: Icon(Icons.more_horiz, color: Colors.white.withValues(alpha:0.5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
