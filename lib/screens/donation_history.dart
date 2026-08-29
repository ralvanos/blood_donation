import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/donation_type.dart';
import '../models/typed_donation.dart';
import '../services/donation_storage.dart';
import '../widgets/donation_arm_picker.dart';

/// Donation history with an **All** combined timeline plus per-type filters.
///
/// Per-type delete behavior is preserved when a single type is selected
/// (or when deleting from the combined list for that entry's type).
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({
    super.key,
    this.initialFilter,
  });

  /// When null, starts on **All** (combined). When set, starts on that type.
  final DonationType? initialFilter;

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  /// `null` means All (combined).
  DonationType? _filter;
  List<TypedDonation> _entries = [];
  bool _loading = true;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  Future<void> _load() async {
    final all = await DonationStorage.getCombinedDonations();
    if (!mounted) return;
    setState(() {
      _entries = all;
      _loading = false;
    });
  }

  List<TypedDonation> get _visible {
    final filter = _filter;
    if (filter == null) return _entries;
    return _entries.where((e) => e.type == filter).toList();
  }

  Future<bool> _confirmDeleteDonation(TypedDonation entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Remove donation?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${entry.type.displayName.toLowerCase()} donation on ${DateFormat.yMMMd().format(entry.date)}?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: entry.type.accent)),
          ),
        ],
      ),
    );
    if (confirm != true) return false;

    await DonationStorage.removeDonation(entry.date, entry.type);
    if (!mounted) return true;
    await _load();
    _hasChanged = true;
    return true;
  }

  Future<void> _showRowActions(TypedDonation entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_outlined, color: entry.type.accent),
                title: Text(
                  entry.arm == null ? 'Tag arm' : 'Change arm tag',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, 'arm'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: entry.type.accent),
                title: const Text('Remove donation',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'arm') {
      await _editArm(entry);
    } else if (action == 'remove') {
      await _confirmDeleteDonation(entry);
    }
  }

  Future<void> _editArm(TypedDonation entry) async {
    final lastSingle = await DonationStorage.lastTaggedSingleArm(entry.type);
    if (!mounted) return;
    final pick = await showDonationArmPicker(
      context: context,
      type: entry.type,
      accent: entry.type.accent,
      current: entry.arm,
      lastSingleArm: lastSingle,
      allowClear: entry.arm != null,
    );
    if (pick == null || pick.skipped || !mounted) return;

    final next = pick.cleared ? null : pick.arm;
    if (next == entry.arm) return;

    await DonationStorage.updateDonationArm(
      date: entry.date,
      type: entry.type,
      arm: next,
    );
    if (!mounted) return;
    _hasChanged = true;
    await _load();
  }

  String? get _armSequence {
    if (_filter == null) return null;
    final tagged = _visible;
    if (tagged.isEmpty) return null;
    if (tagged.every((e) => e.arm == null)) return null;
    final recent = tagged.take(8).toList();
    final parts = [
      for (final e in recent) e.arm?.tag ?? '—',
    ];
    final suffix = tagged.length > 8 ? ' · …' : '';
    return 'Newest first: ${parts.join(' · ')}$suffix';
  }

  Color get _appBarAccent {
    final filter = _filter;
    return filter?.accent ?? const Color(0xFFD3180C);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _appBarAccent;
    final visible = _visible;

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
          title: Text(
            _filter == null
                ? 'Donation history'
                : '${_filter!.displayName} history',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == null,
                      color: const Color(0xFFD3180C),
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final type in DonationType.values) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: type.shortLabel,
                        selected: _filter == type,
                        color: type.accent,
                        onTap: () => setState(() => _filter = type),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_armSequence != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  _armSequence!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : visible.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _filter?.icon ?? Icons.history_rounded,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filter == null
                                    ? 'No donations yet'
                                    : 'No ${_filter!.displayName.toLowerCase()} donations yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add donations from the main screen.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final entry = visible[index];
                            final type = entry.type;
                            final date = entry.date;
                            final showTypeTag = _filter == null;
                            return Dismissible(
                              key: ValueKey(
                                '${type.id}-${date.toIso8601String()}-$index',
                              ),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: type.accent.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (_) =>
                                  _confirmDeleteDonation(entry),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 6,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _editArm(entry),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A1A),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: showTypeTag
                                              ? type.accent
                                                  .withValues(alpha: 0.28)
                                              : Colors.white
                                                  .withValues(alpha: 0.06),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: type.accent
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              type.icon,
                                              color: type.accent,
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (showTypeTag) ...[
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: type.accent
                                                          .withValues(
                                                              alpha: 0.18),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: type.accent
                                                            .withValues(
                                                                alpha: 0.45),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      type.shortLabel,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            type.accentIsLight
                                                                ? type.onAccent
                                                                : type.accent,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                ],
                                                Text(
                                                  DateFormat('EEEE, MMM d')
                                                      .format(date),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat.y().format(date),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '1 ${type.volumeUnitLabel}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.7),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                if (entry.arm != null)
                                                  ArmTag(
                                                    arm: entry.arm!,
                                                    accent: type.accent,
                                                    onAccent: type.accentIsLight
                                                        ? type.onAccent
                                                        : type.accent,
                                                  )
                                                else
                                                  Text(
                                                    'Tap to tag arm',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.45),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                _showRowActions(entry),
                                            icon: Icon(
                                              Icons.more_horiz,
                                              color: Colors.white
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
