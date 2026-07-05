import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../services/donation_storage.dart';
import '../widgets/stat_card.dart';
import 'donation_history.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<DateTime> _donations = [];
  int _countdownDays = 56;
  bool _loading = true;
  late AnimationController _pulseController;
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 1;

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
    final donations = await DonationStorage.getDonations();
    final days = await DonationStorage.getCountdownDays();
    final reminderEnabled = await DonationStorage.getReminderEnabled();
    final reminderDaysBefore = await DonationStorage.getReminderDaysBefore();
    final catchUp = DonationStorage.computeCatchUp(
      donations: donations,
      countdownDays: days,
      reminderEnabled: reminderEnabled,
      reminderDaysBefore: reminderDaysBefore,
      now: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _donations = donations;
        _countdownDays = days;
        _reminderEnabled = reminderEnabled;
        _reminderDaysBefore = reminderDaysBefore;
        _loading = false;
      });
      _maybeShowNotificationPermissionHint(reminderEnabled);
      _maybeShowCatchUpSnackBar(catchUp, reminderEnabled);
    }
  }

  void _maybeShowCatchUpSnackBar(EligibilityCatchUp catchUp, bool remindersEnabled) {
    if (!remindersEnabled) return;

    switch (catchUp.kind) {
      case EligibilityCatchUpKind.eligibleNow:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are eligible to donate again today.'),
            duration: Duration(seconds: 5),
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
                  ? 'You are eligible to donate again today.'
                  : 'Your next donation window opens in $daysUntil day${daysUntil == 1 ? '' : 's'}.',
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
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Donation history',
                              onPressed: _openHistory,
                              icon: const Icon(Icons.history_rounded, color: Colors.white70),
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
                    const SizedBox(height: 8),
                    Text(
                      'Track your donations & next eligible date',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha:0.6),
                      ),
                    ),
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
                    _buildVolumeMilestoneBanner(),
                    const SizedBox(height: 8),
                    _buildStatsCards(),
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
        backgroundColor: const Color(0xFFE53935),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add donation'),
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
      subLabel = 'Add your first donation';
    } else if (isReady) {
      centerLabel = 'Ready to donate';
      subLabel = 'You can donate again today';
    } else {
      centerLabel = '$daysUntil days';
      subLabel = 'until your next donation';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: hasDonation ? _progressUntilNext : 0),
          builder: (context, value, _) {
            final Color ringColor = isReady ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
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
                          ringColor.withValues(alpha:0.25),
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
                        backgroundColor: Colors.white.withValues(alpha:0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReady ? Icons.check_circle_rounded : Icons.bloodtype_rounded,
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
                          color: Colors.white.withValues(alpha:0.7),
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
    final totalPints = _donations.length;
    if (totalPints <= 0) {
      return const SizedBox.shrink();
    }

    String? title;
    String? subtitle;
    Color color;

    final int fullGallons = totalPints ~/ 8;
    final bool isExactGallon = totalPints >= 8 && totalPints % 8 == 0;
    final double fullQuarts = totalPints / 2.0;
    final bool isExactQuart = totalPints >= 2 && totalPints % 2 == 0;

    if (isExactGallon) {
      color = const Color(0xFFFFC107);
      title = 'Incredible milestone reached!';
      subtitle =
          'You have donated $fullGallons gallon${fullGallons == 1 ? '' : 's'} of blood so far. Thank you for making a huge impact.';
    } else if (isExactQuart) {
      final quartsText = fullQuarts.toStringAsFixed(fullQuarts == fullQuarts.roundToDouble() ? 0 : 1);
      color = const Color(0xFF64B5F6);
      title = 'Amazing milestone reached!';
      subtitle = 'You have donated about $quartsText quart${fullQuarts == 1 ? '' : 's'} of blood in total.';
    } else {
      final int pintsToNextQuart = (2 - (totalPints % 2)) % 2;
      final int pintsToNextGallon = (8 - (totalPints % 8)) % 8;

      if (pintsToNextGallon == 1 && totalPints >= 1) {
        final nextGallons = (totalPints + 1) ~/ 8;
        color = const Color(0xFFFFC107);
        title = 'You\'re so close to a big milestone';
        subtitle = 'One more donation and you\'ll reach $nextGallons gallon${nextGallons == 1 ? '' : 's'} total!';
      } else if (pintsToNextQuart == 1 && totalPints >= 1) {
        final nextQuarts = (totalPints + 1) / 2.0;
        final quartsText = nextQuarts.toStringAsFixed(nextQuarts == nextQuarts.roundToDouble() ? 0 : 1);
        color = const Color(0xFF64B5F6);
        title = 'Almost at your next quart';
        subtitle = 'One more donation and you\'ll reach about $quartsText quart${nextQuarts == 1 ? '' : 's'} total.';
      } else {
        return const SizedBox.shrink();
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha:0.4)),
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
                    color: Colors.white.withValues(alpha:0.85),
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
    final nextColor = daysUntil == 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B);
    final daysDisplay = hasDonation ? '$daysUntil' : '—';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total donations',
                value: '${_donations.length}',
                icon: Icons.bloodtype_rounded,
                color: const Color(0xFFE53935),
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
                            nextColor.withValues(alpha:0.8),
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
                const Color(0xFFE53935).withValues(alpha:0.25),
                const Color(0xFFE53935).withValues(alpha:0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE53935).withValues(alpha:0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: Color(0xFFE53935), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Next eligible date',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha:0.8),
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
    final int totalPints = totalDonations;

    final int fullGallons = totalPints ~/ 8;
    final int pintsInCurrentGallon = totalPints % 8;
    final double fill = totalPints == 0 ? 0 : (pintsInCurrentGallon / 8).clamp(0.0, 1.0);
    final double visualFill = (totalPints > 0 && pintsInCurrentGallon == 0) ? 1.0 : fill;

    final int totalMl = totalPints * kMlPerDonation;
    final String totalMlText = NumberFormat.decimalPattern().format(totalMl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha:0.06)),
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
                        color: Colors.white.withValues(alpha:0.9),
                      ),
                    ),
                    if (fullGallons > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withValues(alpha:0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFC107).withValues(alpha:0.4)),
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
                        color: Colors.white.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: visualFill,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE53935),
                              Color(0xFFFF6B6B),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  totalPints == 0
                      ? 'No donations logged yet'
                      : '$totalDonations donation${totalDonations == 1 ? '' : 's'} ($totalMlText ml)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha:0.7),
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
              color: const Color(0xFFE53935).withValues(alpha:0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bloodtype_rounded,
              size: 26,
              color: Color(0xFFE53935),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE53935),
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      await DonationStorage.addDonation(date);
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

  void _openStatistics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatisticsScreen(donations: _donations),
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
    final muted = TextStyle(color: Colors.white.withValues(alpha:0.72), fontSize: 13);
    final addressStyle = TextStyle(color: Colors.white.withValues(alpha:0.92), fontSize: 12, height: 1.35);

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
              Text('Feedback', style: TextStyle(color: Colors.white.withValues(alpha:0.9), fontWeight: FontWeight.w600)),
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
                    icon: const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFFE53935)),
                    label: const Text('Open in email app', style: TextStyle(color: Color(0xFFE53935))),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyWithSnackBar(kFeedbackEmail, 'Email address copied'),
                    icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                    label: const Text('Copy email', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Support the app', style: TextStyle(color: Colors.white.withValues(alpha:0.9), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                kSupportTheAppMessage,
                style: muted,
              ),
              const SizedBox(height: 14),
              Text('Bitcoin', style: TextStyle(color: Colors.white.withValues(alpha:0.85), fontWeight: FontWeight.w500, fontSize: 13)),
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
              Text('Monero', style: TextStyle(color: Colors.white.withValues(alpha:0.85), fontWeight: FontWeight.w500, fontSize: 13)),
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
    final result = await DonationStorage.pickAndParseImport();
    if (!mounted) return;

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
          'This will replace your current donation data and settings with the backup file. This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha:0.8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import', style: TextStyle(color: Color(0xFFE53935))),
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

  void _showSettings(BuildContext context) async {
    int tempDays = _countdownDays;
    bool tempReminderEnabled = _reminderEnabled;
    int tempReminderDaysBefore = _reminderDaysBefore;

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
                      'Most places require around 56 days between whole blood donations.',
                      style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 13),
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
                          icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFE53935)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempDays < 365) {
                              tempDays++;
                              setDialogState(() {});
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE53935)),
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
                        color: Colors.white.withValues(alpha:0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: tempReminderEnabled,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: const Color(0xFFE53935),
                      activeTrackColor: const Color(0xFFE53935).withValues(alpha: 0.4),
                      title: const Text('Donation reminders', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        'Schedule a notification when you are eligible to donate again.',
                        style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 12),
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
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFE53935), size: 22),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              if (tempReminderDaysBefore < 30) {
                                tempReminderDaysBefore++;
                                setDialogState(() {});
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE53935), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$tempReminderDaysBefore days before',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                      Text(
                        'Also schedules an advance reminder before your eligible date.',
                        style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Data Management',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha:0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await DonationStorage.exportData();
                              if (!ctx.mounted) return;
                              final messenger = ScaffoldMessenger.of(ctx);
                              switch (result) {
                                case ExportResult.success:
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Data exported successfully')),
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
                            },
                            icon: const Icon(Icons.upload, size: 18),
                            label: const Text('Export JSON'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha:0.2)),
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
                              side: BorderSide(color: Colors.white.withValues(alpha:0.2)),
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
                  await DonationStorage.setCountdownDays(tempDays);
                  await DonationStorage.setReminderEnabled(tempReminderEnabled);
                  await DonationStorage.setReminderDaysBefore(tempReminderDaysBefore);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  setState(() {
                    _countdownDays = tempDays;
                    _reminderEnabled = tempReminderEnabled;
                    _reminderDaysBefore = tempReminderDaysBefore;
                  });
                  if (tempReminderEnabled) {
                    _maybeShowNotificationPermissionHint(true);
                  }
                },
                child: const Text('Save', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }
}
