import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/donation_type.dart';
import '../models/statistics_math.dart';
import '../services/encrypted_store.dart';
import '../widgets/stat_box.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    required this.donationType,
    required this.donationsByType,
  });

  /// Active Home donation type (scopes “This type” mode).
  final DonationType donationType;

  /// All four series (may be empty lists).
  final Map<DonationType, List<DateTime>> donationsByType;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatisticsScope _scope = StatisticsScope.thisType;
  late Set<DonationType> _legendVisible;
  bool _prefsReady = false;

  List<DateTime> get _activeDonations =>
      widget.donationsByType[widget.donationType] ?? const [];

  @override
  void initState() {
    super.initState();
    _legendVisible = defaultLegendVisibility(widget.donationsByType);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final store = EncryptedStore.instance;
    final scope = StatisticsScope.fromPrefs(
      await store.getString(StatisticsScope.prefsKey),
    );
    final savedLegend = legendFromPrefs(
      await store.getString(StatisticsScope.legendPrefsKey),
    );
    if (!mounted) return;
    setState(() {
      _scope = scope;
      if (savedLegend != null) {
        _legendVisible = savedLegend;
      }
      _prefsReady = true;
    });
  }

  Future<void> _persistScope(StatisticsScope scope) async {
    await EncryptedStore.instance.setString(
      StatisticsScope.prefsKey,
      scope.prefsValue,
    );
  }

  Future<void> _persistLegend() async {
    await EncryptedStore.instance.setString(
      StatisticsScope.legendPrefsKey,
      legendToPrefs(_legendVisible),
    );
  }

  void _setScope(StatisticsScope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _persistScope(scope);
  }

  void _toggleLegend(DonationType type) {
    setState(() {
      if (_legendVisible.contains(type)) {
        _legendVisible = {..._legendVisible}..remove(type);
      } else {
        _legendVisible = {..._legendVisible, type};
      }
    });
    _persistLegend();
  }

  @override
  Widget build(BuildContext context) {
    // Avoid flashing wrong mode before prefs load; defaults are fine briefly.
    final accent = widget.donationType.accent;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScopeToggle(
              scope: _scope,
              accent: accent,
              onChanged: _setScope,
            ),
            const SizedBox(height: 24),
            if (_scope == StatisticsScope.thisType)
              _ThisTypeBody(
                donationType: widget.donationType,
                donations: _activeDonations,
              )
            else
              _AllTypesBody(
                donationsByType: widget.donationsByType,
                legendVisible: _legendVisible,
                onToggleLegend: _toggleLegend,
                prefsReady: _prefsReady,
              ),
          ],
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({
    required this.scope,
    required this.accent,
    required this.onChanged,
  });

  final StatisticsScope scope;
  final Color accent;
  final ValueChanged<StatisticsScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<StatisticsScope>(
      segments: const [
        ButtonSegment<StatisticsScope>(
          value: StatisticsScope.thisType,
          label: Text('This type'),
        ),
        ButtonSegment<StatisticsScope>(
          value: StatisticsScope.allTypes,
          label: Text('All types'),
        ),
      ],
      selected: {scope},
      onSelectionChanged: (selected) {
        if (selected.isEmpty) return;
        onChanged(selected.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white70;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.45);
          }
          return Colors.white.withValues(alpha: 0.04);
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
    );
  }
}

class _ThisTypeBody extends StatelessWidget {
  const _ThisTypeBody({
    required this.donationType,
    required this.donations,
  });

  final DonationType donationType;
  final List<DateTime> donations;

  @override
  Widget build(BuildContext context) {
    final accent = donationType.accent;
    final fillAccent = donationType.brandAccent;
    final fillOpacity = donationType.chartFillOpacity;
    final stats = ThisTypeStatistics.fromDonations(donations);
    final spots = thisTypeTrendSpots(donations);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatBox(
                label: 'Total\nDonations',
                value: '${stats.totalDonations}',
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatBox(
                label: 'Avg. Days\nBetween',
                value: stats.averageDaysBetween.toStringAsFixed(1),
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatBox(
                label: 'Longest Gap\n(Days)',
                value: '${stats.longestGapDays}',
                color: const Color(0xFFFFC107),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${donationType.displayName} trend',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Cumulative visits for ${donationType.displayName}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 300,
          child: spots.isEmpty
              ? const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 16, top: 16),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: Colors.white10,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= spots.length) {
                                return const SizedBox();
                              }
                              if (spots.length > 5 &&
                                  i % (spots.length ~/ 5) != 0) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MMM yy').format(spots[i].date),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white54,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (final s in spots) FlSpot(s.x, s.y),
                          ],
                          isCurved: true,
                          color: accent,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                fillAccent.withValues(alpha: fillOpacity),
                                donationType.accentDeep
                                    .withValues(alpha: fillOpacity * 0.55),
                                fillAccent.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AllTypesBody extends StatelessWidget {
  const _AllTypesBody({
    required this.donationsByType,
    required this.legendVisible,
    required this.onToggleLegend,
    required this.prefsReady,
  });

  final Map<DonationType, List<DateTime>> donationsByType;
  final Set<DonationType> legendVisible;
  final ValueChanged<DonationType> onToggleLegend;
  final bool prefsReady;

  @override
  Widget build(BuildContext context) {
    final stats = AllTypesStatistics.fromDonationsByType(
      donationsByType: donationsByType,
    );
    final chart = allTypesTrendSeries(
      donationsByType: donationsByType,
      visibleTypes: legendVisible,
    );
    final volumeText =
        NumberFormat.decimalPattern().format(stats.totalVolumeMl);
    final soonestLabel = _formatSoonest(stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatBox(
                label: 'Total\nVisits',
                value: '${stats.totalVisits}',
                color: const Color(0xFFD3180C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatBox(
                label: 'Total Volume\n(ml approx.)',
                value: volumeText,
                color: const Color(0xFFF4C430),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatBox(
                label: 'Types\nUsed',
                value: stats.typesUsedLabel,
                color: const Color(0xFFFFCFA0),
              ),
            ),
          ],
        ),
        if (soonestLabel != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              soonestLabel,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
        const SizedBox(height: 36),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Donation trends by type',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Cumulative visits per type (not a merged total)',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final type in DonationType.values) ...[
                if (type != DonationType.values.first) const SizedBox(width: 8),
                _LegendChip(
                  type: type,
                  selected: legendVisible.contains(type),
                  hasData: (donationsByType[type] ?? const []).isNotEmpty,
                  onTap: () => onToggleLegend(type),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 300,
          child: chart.series.isEmpty || chart.timeline.isEmpty
              ? Center(
                  child: Text(
                    prefsReady && legendVisible.isEmpty
                        ? 'Turn on a type in the legend'
                        : 'No data available',
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 16, top: 16),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: Colors.white10,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              final timeline = chart.timeline;
                              if (i < 0 || i >= timeline.length) {
                                return const SizedBox();
                              }
                              if (timeline.length > 5 &&
                                  i % (timeline.length ~/ 5) != 0) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MMM yy').format(timeline[i]),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white54,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        for (final type in DonationType.values)
                          if (chart.series.containsKey(type))
                            LineChartBarData(
                              spots: [
                                for (final s in chart.series[type]!)
                                  FlSpot(s.x, s.y),
                              ],
                              isCurved: true,
                              color: type.accent,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 3.5,
                                    color: type.accent,
                                    strokeWidth: 0,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(show: false),
                            ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String? _formatSoonest(AllTypesStatistics stats) {
    final date = stats.soonestEligible;
    final type = stats.soonestType;
    if (date == null || type == null) return null;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (!date.isAfter(today)) {
      return 'Next eligibility: ${type.displayName} — eligible now';
    }
    return 'Next eligibility: ${type.displayName} — '
        '${DateFormat.yMMMd().format(date)}';
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.type,
    required this.selected,
    required this.hasData,
    required this.onTap,
  });

  final DonationType type;
  final bool selected;
  final bool hasData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = type.accent;
    final label = statisticsLegendLabel(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              if (!hasData) ...[
                const SizedBox(width: 4),
                Text(
                  '(0)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
