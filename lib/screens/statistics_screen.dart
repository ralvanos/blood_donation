import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/stat_box.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key, required this.donations});

  final List<DateTime> donations;

  @override
  Widget build(BuildContext context) {
    final sortedDonations = List<DateTime>.from(donations)..sort((a, b) => a.compareTo(b));

    final totalDonations = sortedDonations.length;
    double averageDays = 0;
    int longestGap = 0;

    if (totalDonations > 1) {
      int totalDays = 0;
      for (int i = 1; i < totalDonations; i++) {
        final gap = sortedDonations[i].difference(sortedDonations[i - 1]).inDays;
        totalDays += gap;
        if (gap > longestGap) longestGap = gap;
      }
      averageDays = totalDays / (totalDonations - 1);
    }

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
          children: [
            Row(
              children: [
                Expanded(
                  child: StatBox(
                    label: 'Total\nDonations',
                    value: '$totalDonations',
                    color: const Color(0xFFE53935),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatBox(
                    label: 'Avg. Days\nBetween',
                    value: averageDays.toStringAsFixed(1),
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatBox(
                    label: 'Longest Gap\n(Days)',
                    value: '$longestGap',
                    color: const Color(0xFFFFC107),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Donation History Graph',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: sortedDonations.isEmpty
                  ? const Center(child: Text('No data available'))
                  : Padding(
                      padding: const EdgeInsets.only(right: 16, top: 16),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) =>
                                const FlLine(color: Colors.white10, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() < 0 || value.toInt() >= sortedDonations.length) {
                                    return const SizedBox();
                                  }
                                  if (sortedDonations.length > 5 &&
                                      value.toInt() % (sortedDonations.length ~/ 5) != 0) {
                                    return const SizedBox();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('MMM yy').format(sortedDonations[value.toInt()]),
                                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                sortedDonations.length,
                                (index) => FlSpot(index.toDouble(), index + 1.0),
                              ),
                              isCurved: true,
                              color: const Color(0xFFE53935),
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFE53935).withValues(alpha:0.3),
                                    const Color(0xFFE53935).withValues(alpha:0.0),
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
        ),
      ),
    );
  }
}
