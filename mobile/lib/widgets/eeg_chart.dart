import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EegChart extends StatelessWidget {
  const EegChart({
    super.key,
    required this.samples,
    required this.channelCount,
  });

  final List<double> samples;
  final int channelCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (samples.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Henüz EEG verisi gelmedi',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var index = 0; index < samples.length; index++) {
      spots.add(FlSpot(index.toDouble(), samples[index]));
    }

    final minY = samples.reduce((a, b) => a < b ? a : b);
    final maxY = samples.reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY).abs() * 0.1).clamp(1.0, 100.0);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Canlı EEG Sinyali',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$channelCount kanal • ${samples.length} örnek',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (samples.length - 1).toDouble(),
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
