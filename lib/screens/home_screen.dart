import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../content/donation_type_info.dart';
import '../models/donation_type.dart';
import '../services/auto_lock_policy.dart';
import '../services/donation_storage.dart';
import '../services/pin_service.dart';
import '../widgets/stat_card.dart';
import 'donation_history.dart';
import 'eligibility_overview_screen.dart';
import 'pin_lock_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onPinSettingsChanged});

  /// Notifies [BloodDonationApp] when PIN lock is enabled/disabled.
  final VoidCallback? onPinSettingsChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<DateTime> _donations = [];
  DonationType _activeType = DonationType.wholeBlood;
  int _countdownDays = 56;
  bool _loading = true;
  late AnimationController _pulseController;
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 1;
  String _donorNumber = '';
  bool _showDoubleRedHint = false;
  int _wholeBloodCount = 0;

  Color get _accent => _activeType.accent;
  Color get _accentSecondary => _activeType.accentSecondary;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final activeType = await DonationStorage.getActiveDonationType();
    final donations = await DonationStorage.getDonations(activeType);
    final days = await DonationStorage.getCountdownDays(activeType);
    final reminderEnabled = await DonationStorage.getReminderEnabled();
    final reminderDaysBefore = await DonationStorage.getReminderDaysBefore();
    final donorNumber = await DonationStorage.getDonorNumber();
    final showHint = await DonationStorage.shouldShowDoubleRedJourneyHint();
    final wbDonations = await DonationStorage.getDonations(DonationType.wholeBlood);
    final catchUp = DonationStorage.computeCatchUp(
      donations: donations,
      countdownDays: days,
      reminderEnabled: reminderEnabled,
      reminderDaysBefore: reminderDaysBefore,
      now: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _activeType = activeType;
        _donations = donations;
        _countdownDays = days;
        _reminderEnabled = reminderEnabled;
        _reminderDaysBefore = reminderDaysBefore;
        _donorNumber = donorNumber;
        _showDoubleRedHint = showHint;
        _wholeBloodCount = wbDonations.length;
        _loading = false;
      });
      _maybeShowNotificationPermissionHint(reminderEnabled);
      _maybeShowCatchUpSnackBar(catchUp, reminderEnabled);
    }
  }

  Future<void> _setActiveType(DonationType type) async {
    if (type == _activeType) return;
    await DonationStorage.setActiveDonationType(type);
    final donations = await DonationStorage.getDonations(type);
    final days = await DonationStorage.getCountdownDays(type);
    if (!mounted) return;
    setState(() {
      _activeType = type;
      _donations = donations;
      _countdownDays = days;
    });
  }

  void _maybeShowCatchUpSnackBar(EligibilityCatchUp catchUp, bool remindersEnabled) {
    if (!remindersEnabled) return;

    switch (catchUp.kind) {
      case EligibilityCatchUpKind.eligibleNow:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are eligible to donate ${_activeType.displayName.toLowerCase()} again today.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      case EligibilityCatchUpKind.missedAdvanceReminder:
        final eligible = catchUp.eligibleDate!;
        final daysUntil = eligible.difference(DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        )).inDays;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              daysUntil <= 0
                  ? 'You are eligible to donate ${_activeType.displayName.toLowerCase()} again today.'
                  : 'Your next ${_activeType.displayName.toLowerCase()} window opens in $daysUntil day${daysUntil == 1 ? '' : 's'}.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      case EligibilityCatchUpKind.none:
        break;
    }
  }

  void _maybeShowNotificationPermissionHint(bool remindersEnabled) {
    if (!remindersEnabled || DonationStorage.notificationsPermissionGranted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notification permission is off. Enable notifications in system settings to receive donation reminders.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  DateTime? get _lastDonation => _donations.isEmpty ? null : _donations.first;

  DateTime? get _nextEligible {
    final last = _lastDonation;
    if (last == null) return null;
    return last.add(Duration(days: _countdownDays));
  }

  int? get _daysUntilNext {
    final next = _nextEligible;
    if (next == null) return null;
    final now = DateTime.now();
    final diff = next.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays.clamp(0, 999);
  }

  double get _progressUntilNext {
    final daysUntil = _daysUntilNext;
    if (daysUntil == null) return 0;
    if (_countdownDays <= 0) return 1;
    final completedDays = _countdownDays - daysUntil;
    return (completedDays / _countdownDays).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_donorNumber.isNotEmpty)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Donor number',
                                onPressed: _showDonorNumberSheet,
                                icon: Icon(
                                  Icons.badge_outlined,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  size: 22,
                                ),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Donation history',
                              onPressed: _openHistory,
                              icon: const Icon(Icons.history_rounded, color: Colors.white70),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Eligibility overview',
                              onPressed: _openEligibilityOverview,
                              icon: const Icon(Icons.event_available_outlined, color: Colors.white70),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Statistics',
                              onPressed: _openStatistics,
                              icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Settings',
                              onPressed: () => _showSettings(context),
                              icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Feedback & support',
                              onPressed: _showFeedbackSupport,
                              icon: const Icon(Icons.contact_support_outlined, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track ${_activeType.displayName.toLowerCase()} & next eligible date',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildTypeSwitcher(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildCountdownRing(),
                    const SizedBox(height: 8),
                    _buildDoubleRedJourneyHint(),
                    const SizedBox(height: 8),
                    _buildVolumeMilestoneBanner(),
                    const SizedBox(height: 8),
                    _buildStatsCards(),
                    const SizedBox(height: 16),
                    _buildEligibilityOverviewTeaser(),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 48),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDonation,
        backgroundColor: _accent,
        foregroundColor: _activeType.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add ${_activeType.shortLabel.toLowerCase()}'),
      ),
    );
  }

  Widget _buildTypeSwitcher() {
    // Four types: horizontal scroll keeps segments usable on narrow phones.
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<DonationType>(
              segments: [
                // Order follows DonationType.values: WB → Plasma → Plt → Dbl Red.
                for (final type in DonationType.values)
                  ButtonSegment<DonationType>(
                    value: type,
                    label: Text(
                      type.shortLabel,
                      style: const TextStyle(fontSize: 12),
                    ),
                    tooltip: '${type.displayName} — ${type.journeyLabel}',
                  ),
              ],
              selected: {_activeType},
              onSelectionChanged: (selected) {
                if (selected.isEmpty) return;
                _setActiveType(selected.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return _activeType.onAccent;
                  }
                  return Colors.white70;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    // Solid-ish fill so light gold/peach stay readable with dark text.
                    return _activeType.accentIsLight
                        ? _accent
                        : _accent.withValues(alpha: 0.45);
                  }
                  return Colors.white.withValues(alpha: 0.04);
                }),
                side: WidgetStatePropertyAll(
                  BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              showSelectedIcon: false,
            ),
          ),
        ),
        IconButton(
          tooltip: 'About ${_activeType.displayName}',
          onPressed: () => _showDonationTypeInfo(_activeType),
          icon: Icon(Icons.info_outline_rounded, color: _accentSecondary),
        ),
      ],
    );
  }

  void _showDonationTypeInfo(DonationType type) {
    final info = DonationTypeInfo.forType(type);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(type.icon, color: type.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.journeyLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: type.accentSecondary.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    info.body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPfasInfo() {
    const info = DonationTypeInfo.pfasAndToxins;
    _showInfoSheet(info);
  }

  void _showInfoSheet(DonationTypeInfo info, {IconData? icon, Color? iconColor}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (icon != null) ...[
                    Row(
                      children: [
                        Icon(icon, color: iconColor ?? _accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            info.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      info.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    info.body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDoubleRedJourneyHint() {
    if (!_showDoubleRedHint) return const SizedBox.shrink();
    final accent = DonationType.doubleRed.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(DonationType.doubleRed.icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soft tip · advanced option',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _wholeBloodCount == 1
                      ? 'After a successful whole blood donation, Double Red / Power Red can be a higher-impact option at some centers. Advisory only — nothing is locked.'
                      : 'With a couple of whole blood donations logged, some donors explore Double Red / Power Red. Check with your center — this is guidance only.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
            onPressed: () async {
              await DonationStorage.setJourneyHintDoubleRedDismissed(true);
              if (!mounted) return;
              setState(() => _showDoubleRedHint = false);
            },
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityOverviewTeaser() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openEligibilityOverview,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(Icons.event_available_outlined, color: _accentSecondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Eligibility overview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Next eligible date for every type',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownRing() {
    final hasDonation = _lastDonation != null;
    final daysUntil = _daysUntilNext;
    final isReady = hasDonation && daysUntil == 0;
    final String centerLabel;
    final String subLabel;

    if (!hasDonation) {
      centerLabel = 'No donations';
      subLabel = 'Add your first ${_activeType.displayName.toLowerCase()}';
    } else if (isReady) {
      centerLabel = 'Ready to donate';
      subLabel = 'You can donate ${_activeType.displayName.toLowerCase()} today';
    } else {
      centerLabel = '$daysUntil days';
      subLabel = 'until next ${_activeType.shortLabel.toLowerCase()}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: hasDonation ? _progressUntilNext : 0),
          builder: (context, value, _) {
            final Color ringColor = isReady ? const Color(0xFF4CAF50) : _accent;
            return SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          ringColor.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -3.14159 / 2,
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: hasDonation ? value : 0,
                        strokeWidth: 14,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReady ? Icons.check_circle_rounded : _activeType.icon,
                        color: ringColor,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        centerLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVolumeMilestoneBanner() {
    final totalUnits = _donations.length;
    if (totalUnits <= 0) {
      return const SizedBox.shrink();
    }

    String? title;
    String? subtitle;
    Color color;
    final product = _activeType.displayName.toLowerCase();

    final int fullGallons = totalUnits ~/ 8;
    final bool isExactGallon = totalUnits >= 8 && totalUnits % 8 == 0;
    final double fullQuarts = totalUnits / 2.0;
    final bool isExactQuart = totalUnits >= 2 && totalUnits % 2 == 0;

    if (isExactGallon) {
      color = const Color(0xFFFFC107);
      title = 'Incredible milestone reached!';
      subtitle =
          'You have logged $fullGallons gallon-equivalent${fullGallons == 1 ? '' : 's'} of $product so far. Thank you for making a huge impact.';
    } else if (isExactQuart) {
      final quartsText = fullQuarts.toStringAsFixed(fullQuarts == fullQuarts.roundToDouble() ? 0 : 1);
      color = _accentSecondary;
      title = 'Amazing milestone reached!';
      subtitle = 'You have logged about $quartsText quart-equivalent${fullQuarts == 1 ? '' : 's'} of $product in total.';
    } else {
      final int unitsToNextQuart = (2 - (totalUnits % 2)) % 2;
      final int unitsToNextGallon = (8 - (totalUnits % 8)) % 8;

      if (unitsToNextGallon == 1 && totalUnits >= 1) {
        final nextGallons = (totalUnits + 1) ~/ 8;
        color = const Color(0xFFFFC107);
        title = 'You\'re so close to a big milestone';
        subtitle =
            'One more donation and you\'ll reach $nextGallons gallon-equivalent${nextGallons == 1 ? '' : 's'} of $product!';
      } else if (unitsToNextQuart == 1 && totalUnits >= 1) {
        final nextQuarts = (totalUnits + 1) / 2.0;
        final quartsText = nextQuarts.toStringAsFixed(nextQuarts == nextQuarts.roundToDouble() ? 0 : 1);
        color = _accentSecondary;
        title = 'Almost at your next quart';
        subtitle =
            'One more donation and you\'ll reach about $quartsText quart-equivalent${nextQuarts == 1 ? '' : 's'} of $product.';
      } else {
        return const SizedBox.shrink();
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final daysUntil = _daysUntilNext;
    final hasDonation = _lastDonation != null;
    final nextColor = daysUntil == 0 ? const Color(0xFF4CAF50) : _accentSecondary;
    final daysDisplay = hasDonation ? '$daysUntil' : '—';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total donations',
                value: '${_donations.length}',
                icon: _activeType.icon,
                color: _accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: hasDonation
                  ? AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return StatCard(
                          label: 'Days until next',
                          value: daysDisplay,
                          icon: Icons.schedule_rounded,
                          color: Color.lerp(
                            nextColor,
                            nextColor.withValues(alpha: 0.8),
                            _pulseController.value,
                          )!,
                        );
                      },
                    )
                  : StatCard(
                      label: 'Days until next',
                      value: daysDisplay,
                      icon: Icons.schedule_rounded,
                      color: Colors.white38,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accent.withValues(alpha: 0.25),
                _accent.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_available_rounded, color: _accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Next eligible date',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _nextEligible == null
                    ? 'Add your first donation'
                    : DateFormat('EEEE, MMM d, y').format(_nextEligible!),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildDonationVolumeCard(),
      ],
    );
  }

  Widget _buildDonationVolumeCard() {
    final totalDonations = _donations.length;
    final int totalUnits = totalDonations;

    final int fullGallons = totalUnits ~/ 8;
    final int unitsInCurrentGallon = totalUnits % 8;
    final double fill = totalUnits == 0 ? 0 : (unitsInCurrentGallon / 8).clamp(0.0, 1.0);
    final double visualFill = (totalUnits > 0 && unitsInCurrentGallon == 0) ? 1.0 : fill;

    final int totalMl = totalUnits * _activeType.mlPerDonation;
    final String totalMlText = NumberFormat.decimalPattern().format(totalMl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Donation volume',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (fullGallons > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '$fullGallons GALLON${fullGallons == 1 ? '' : 'S'}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFC107),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: visualFill,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              _accent,
                              _accentSecondary,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  totalUnits == 0
                      ? 'No donations logged yet'
                      : '$totalDonations donation${totalDonations == 1 ? '' : 's'} '
                          '($totalMlText ml approx.; ${_activeType.volumeUnitLabel})',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _activeType.icon,
              size: 26,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddDonation() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Add ${_activeType.displayName} donation',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _accent,
              surface: const Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      await DonationStorage.addDonation(date, _activeType);
      _load();
    }
  }

  void _openHistory() {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (context) => const DonationHistoryScreen(),
      ),
    )
        .then((changed) async {
      if (changed == true) {
        _load();
      }
    });
  }

  void _openEligibilityOverview() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const EligibilityOverviewScreen(),
      ),
    )
        .then((_) {
      if (mounted) _load();
    });
  }

  void _showDonorNumberSheet() {
    final number = _donorNumber;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Donor number',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stored on this device only. Edit in Settings → Donor info.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                number.isEmpty ? '—' : number,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              if (number.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _copyWithSnackBar(number, 'Donor number copied');
                  },
                  icon: Icon(Icons.copy_rounded, size: 18, color: _accent),
                  label: Text('Copy', style: TextStyle(color: _accent)),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStatistics() async {
    final byType = <DonationType, List<DateTime>>{};
    final countdowns = <DonationType, int>{};
    for (final type in DonationType.values) {
      byType[type] = type == _activeType
          ? List<DateTime>.from(_donations)
          : await DonationStorage.getDonations(type);
      countdowns[type] = type == _activeType
          ? _countdownDays
          : await DonationStorage.getCountdownDays(type);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatisticsScreen(
          donationType: _activeType,
          donationsByType: byType,
          countdownDaysByType: countdowns,
        ),
      ),
    );
  }

  void _copyWithSnackBar(String text, String snackMessage) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snackMessage), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openFeedbackEmail() async {
    final subject = Uri.encodeComponent('blood_donation app feedback');
    final uri = Uri.parse('mailto:$kFeedbackEmail?subject=$subject');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _copyWithSnackBar(kFeedbackEmail, 'Email copied — paste it into your mail app');
      }
    } catch (_) {
      if (mounted) {
        _copyWithSnackBar(kFeedbackEmail, 'Email copied — paste it into your mail app');
      }
    }
  }

  void _showFeedbackSupport() {
    final muted = TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13);
    final addressStyle = TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12, height: 1.35);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Feedback & support', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Feedback', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Questions, ideas, or bug reports are welcome.',
                style: muted,
              ),
              const SizedBox(height: 10),
              SelectableText(
                kFeedbackEmail,
                style: addressStyle,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openFeedbackEmail();
                    },
                    icon: Icon(Icons.mail_outline_rounded, size: 18, color: _accent),
                    label: Text('Open in email app', style: TextStyle(color: _accent)),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyWithSnackBar(kFeedbackEmail, 'Email address copied'),
                    icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                    label: const Text('Copy email', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Support the app', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                kSupportTheAppMessage,
                style: muted,
              ),
              const SizedBox(height: 14),
              Text('Bitcoin', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 4),
              SelectableText(kDonateBtcAddress, style: addressStyle),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _copyWithSnackBar(kDonateBtcAddress, 'Bitcoin address copied'),
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                  label: const Text('Copy Bitcoin address', style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Monero', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 4),
              SelectableText(kDonateXmrAddress, style: addressStyle),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _copyWithSnackBar(kDonateXmrAddress, 'Monero address copied'),
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                  label: const Text('Copy Monero address', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _importData() async {
    var result = await DonationStorage.pickAndParseImport();
    if (!mounted) return;

    if (result.needsPassphrase) {
      final passphrase = await PinDialogs.promptImportPassphrase(context);
      if (passphrase == null) return;
      if (!mounted) return;
      result = DonationStorage.decryptAndValidateImport(
        encryptedEnvelope: result.encryptedEnvelope!,
        passphrase: passphrase,
      );
      if (!mounted) return;
    }

    if (!result.success) {
      if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage!)),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Import backup?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will replace your current donation data (all types) and settings with the backup file. This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Import', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await DonationStorage.applyImport(result.data!);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data imported successfully')),
    );
    _load();
  }

  Future<void> _runExport({required bool pinProtected, required BuildContext messengerContext}) async {
    String? passphrase;
    if (pinProtected) {
      passphrase = await PinDialogs.promptExportPassphrase(messengerContext);
      if (passphrase == null) return;
      if (!messengerContext.mounted) return;
    } else {
      final proceed = await showDialog<bool>(
        context: messengerContext,
        builder: (warnCtx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Normal export (plaintext)',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'The JSON backup is a plaintext file. Anyone with the file can read it. '
            'Store it somewhere only you can access. Choose PIN-protected export for an encrypted file.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(warnCtx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(warnCtx, true),
              child: Text(
                'Export plaintext',
                style: TextStyle(color: _accent),
              ),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!messengerContext.mounted) return;
    }

    final result = await DonationStorage.exportData(passphrase: passphrase);
    if (!messengerContext.mounted) return;
    final messenger = ScaffoldMessenger.of(messengerContext);
    switch (result) {
      case ExportResult.success:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              pinProtected
                  ? 'PIN-protected backup exported'
                  : 'Data exported successfully',
            ),
          ),
        );
      case ExportResult.cancelled:
        messenger.showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
      case ExportResult.failure:
        messenger.showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
    }
  }

  Future<void> _showExportOptions(BuildContext ctx) async {
    final choice = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Export backup', style: TextStyle(color: Colors.white)),
        content: Text(
          'Choose how to save your backup file.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, 'normal'),
            child: const Text('Normal export'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, 'pin'),
            child: Text(
              'PIN-protected',
              style: TextStyle(color: _accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !ctx.mounted) return;
    await _runExport(pinProtected: choice == 'pin', messengerContext: ctx);
  }

  void _showSettings(BuildContext context) async {
    int tempDays = _countdownDays;
    bool tempReminderEnabled = _reminderEnabled;
    int tempReminderDaysBefore = _reminderDaysBefore;
    final donorController = TextEditingController(text: _donorNumber);
    final accent = _accent;
    final type = _activeType;
    var pinEnabled = await PinService.instance.isEnabled();
    var autoLockSeconds = await DonationStorage.getAutoLockTimeoutSeconds();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Settings', style: TextStyle(color: Colors.white)),
            content: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Donor info',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Optional donor number / donor ID for check-in. Stays on this device.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: donorController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Donor number',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        hintText: 'Optional',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: accent),
                        ),
                        isDense: true,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          await DonationStorage.setDonorNumber(
                            donorController.text,
                          );
                          final saved = await DonationStorage.getDonorNumber();
                          if (!mounted) return;
                          setState(() => _donorNumber = saved);
                          donorController.text = saved;
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                saved.isEmpty
                                    ? 'Donor number cleared'
                                    : 'Donor number saved',
                              ),
                            ),
                          );
                          setDialogState(() {});
                        },
                        child: Text('Save donor number', style: TextStyle(color: accent)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      type.settingsIntervalBlurb,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempDays > 1) {
                              tempDays--;
                              setDialogState(() {});
                            }
                          },
                          icon: Icon(Icons.remove_circle_outline, color: accent),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempDays < 365) {
                              tempDays++;
                              setDialogState(() {});
                            }
                          },
                          icon: Icon(Icons.add_circle_outline, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$tempDays days',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Reminder',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: tempReminderEnabled,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: accent,
                      activeTrackColor: accent.withValues(alpha: 0.4),
                      title: const Text('Donation reminders', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        'Schedules from the soonest eligibility across '
                        '${DonationType.values.map((t) => t.displayName).join(', ')}. '
                        'Notification text names the type when possible.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          tempReminderEnabled = value;
                        });
                      },
                    ),
                    if (tempReminderEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              if (tempReminderDaysBefore > 0) {
                                tempReminderDaysBefore--;
                                setDialogState(() {});
                              }
                            },
                            icon: Icon(Icons.remove_circle_outline, color: accent, size: 22),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              if (tempReminderDaysBefore < 30) {
                                tempReminderDaysBefore++;
                                setDialogState(() {});
                              }
                            },
                            icon: Icon(Icons.add_circle_outline, color: accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$tempReminderDaysBefore days before',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                      Text(
                        'Also schedules an advance reminder before your soonest eligible date.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Security',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Optional ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN. '
                      'Locks the app on open and after the auto-lock delay. PIN is stored as a salted hash.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: pinEnabled,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: accent,
                      activeTrackColor: accent.withValues(alpha: 0.4),
                      title: const Text('Require PIN', style: TextStyle(color: Colors.white)),
                      onChanged: (value) async {
                        if (value) {
                          final pin = await PinDialogs.promptNewPin(
                            ctx,
                            title: 'Set PIN',
                          );
                          if (pin == null) return;
                          if (!ctx.mounted) return;
                          await PinService.instance.setPin(pin);
                          pinEnabled = true;
                          widget.onPinSettingsChanged?.call();
                          if (!ctx.mounted) return;
                          setDialogState(() {});
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('PIN lock enabled')),
                          );
                        } else {
                          final current = await PinDialogs.promptCurrentPin(
                            ctx,
                            title: 'Confirm PIN to turn off',
                          );
                          if (current == null) return;
                          try {
                            await PinService.instance.disablePin(current);
                            pinEnabled = false;
                            widget.onPinSettingsChanged?.call();
                            if (!ctx.mounted) return;
                            setDialogState(() {});
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('PIN lock disabled')),
                            );
                          } catch (_) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Incorrect PIN')),
                            );
                          }
                        }
                      },
                    ),
                    if (pinEnabled) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            final current = await PinDialogs.promptCurrentPin(
                              ctx,
                              title: 'Enter current PIN',
                            );
                            if (current == null) return;
                            if (!ctx.mounted) return;
                            final next = await PinDialogs.promptNewPin(
                              ctx,
                              title: 'Choose new PIN',
                            );
                            if (next == null) return;
                            if (!ctx.mounted) return;
                            try {
                              await PinService.instance.changePin(
                                currentPin: current,
                                newPin: next,
                              );
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('PIN changed')),
                              );
                            } catch (_) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Incorrect PIN')),
                              );
                            }
                          },
                          child: Text('Change PIN', style: TextStyle(color: accent)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Auto-lock',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How long after leaving the app before the PIN is required again.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        key: ValueKey(autoLockSeconds),
                        initialValue: autoLockSeconds,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          isDense: true,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: accent),
                          ),
                        ),
                        items: [
                          for (final seconds in AutoLockPolicy.allowedTimeoutSeconds)
                            DropdownMenuItem(
                              value: seconds,
                              child: Text(AutoLockPolicy.labelForTimeout(seconds)),
                            ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await DonationStorage.setAutoLockTimeoutSeconds(value);
                          autoLockSeconds = value;
                          widget.onPinSettingsChanged?.call();
                          if (!ctx.mounted) return;
                          setDialogState(() {});
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Learn',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Donor journey order — soft guidance only (nothing locked).',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final learnType in DonationType.values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(learnType.icon, color: learnType.accent, size: 22),
                        title: Text(
                          learnType.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        subtitle: Text(
                          learnType.journeyLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showDonationTypeInfo(learnType);
                        },
                      ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showInfoSheet(DonationTypeInfo.donorJourneyGuidance);
                      },
                      icon: Icon(Icons.route_outlined, size: 18, color: accent),
                      label: Text(
                        'Donor journey (soft guidance)',
                        style: TextStyle(color: accent),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showInfoSheet(DonationTypeInfo.centerRuleNotes);
                      },
                      icon: Icon(Icons.local_hospital_outlined, size: 18, color: accent),
                      label: Text(
                        'Center-specific rule notes',
                        style: TextStyle(color: accent),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPfasInfo();
                      },
                      icon: Icon(Icons.science_outlined, size: 18, color: accent),
                      label: Text(
                        'About donation types / PFAS & toxins',
                        style: TextStyle(color: accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Privacy',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Donation dates, donor number, and settings are encrypted on this device. '
                      'Optional PIN lock and auto-lock timeout are available above. There is no cloud sync. '
                      'Exports can be plaintext or PIN-protected (`enc_export_v1`). '
                      'See PRIVACY.md in the project for details.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data Management',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Export as plaintext JSON or PIN-protected (encrypted) backup. '
                      'PIN-protected files need the export PIN to import. '
                      'Import still accepts older plaintext v1–v5 backups.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showExportOptions(ctx),
                            icon: const Icon(Icons.upload, size: 18),
                            label: const Text('Export JSON'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _importData,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Import JSON'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  await DonationStorage.setCountdownDays(tempDays, type);
                  await DonationStorage.setReminderEnabled(tempReminderEnabled);
                  await DonationStorage.setReminderDaysBefore(tempReminderDaysBefore);
                  await DonationStorage.setDonorNumber(donorController.text);
                  final savedDonor = await DonationStorage.getDonorNumber();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  setState(() {
                    _countdownDays = tempDays;
                    _reminderEnabled = tempReminderEnabled;
                    _reminderDaysBefore = tempReminderDaysBefore;
                    _donorNumber = savedDonor;
                  });
                  if (tempReminderEnabled) {
                    _maybeShowNotificationPermissionHint(true);
                  }
                },
                child: Text('Save', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    ).whenComplete(donorController.dispose);
  }
}
