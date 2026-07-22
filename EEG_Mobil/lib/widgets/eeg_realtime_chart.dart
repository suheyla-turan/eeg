import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/sensors.dart';
import '../models/eeg_sample.dart';
import '../theme/app_colors.dart';

/// 14 kanal veya tek kanal gerçek zamanlı EEG grafiği.
class EegRealtimeChart extends StatelessWidget {
  const EegRealtimeChart({
    super.key,
    required this.history,
    this.selectedChannel,
    this.height = 280,
  });

  final List<EegSample> history;
  final String? selectedChannel;
  final double height;

  static const _palette = <Color>[
    Color(0xFF0D7A8C),
    Color(0xFF1FA8A0),
    Color(0xFF2E9B63),
    Color(0xFFD4A017),
    Color(0xFFD4783A),
    Color(0xFFC44B4B),
    Color(0xFF5B7C99),
    Color(0xFF7B5EA7),
    Color(0xFFE8A838),
    Color(0xFF3D8B6E),
    Color(0xFF4A90A4),
    Color(0xFFB85C38),
    Color(0xFF6B8E23),
    Color(0xFF8B4513),
  ];

  @override
  Widget build(BuildContext context) {
    final channels = selectedChannel == null
        ? sensorIds
        : [selectedChannel!];

    if (history.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'EEG verisi bekleniyor…',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final series = <LineChartBarData>[];
    for (var i = 0; i < channels.length; i++) {
      final ch = channels[i];
      final spots = <FlSpot>[];
      for (var x = 0; x < history.length; x++) {
        spots.add(FlSpot(x.toDouble(), history[x][ch]));
      }
      series.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: _palette[i % _palette.length],
          barWidth: selectedChannel == null ? 1.2 : 2.2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    double minY = double.infinity;
    double maxY = -double.infinity;
    for (final bar in series) {
      for (final s in bar.spots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
      }
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final pad = (maxY - minY) * 0.12;
    minY -= pad;
    maxY += pad;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedChannel == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < sensorIds.length; i++)
                  _LegendDot(
                    color: _palette[i % _palette.length],
                    label: sensorIds[i],
                  ),
              ],
            ),
          ),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (history.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border.withValues(alpha: 0.7),
                  strokeWidth: 1,
                ),
              ),
              titlesData: const FlTitlesData(
                show: true,
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: AppColors.border),
              ),
              lineBarsData: series,
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots.map((s) {
                      final ch = channels[s.barIndex.clamp(0, channels.length - 1)];
                      return LineTooltipItem(
                        '$ch\n${s.y.toStringAsFixed(1)}',
                        TextStyle(
                          color: _palette[s.barIndex % _palette.length],
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Tek kanal seçici chip satırı.
class EegChannelSelector extends StatelessWidget {
  const EegChannelSelector({
    super.key,
    required this.selectedChannel,
    required this.onSelected,
  });

  final String? selectedChannel;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tümü'),
              selected: selectedChannel == null,
              onSelected: (_) => onSelected(null),
              selectedColor: AppColors.primarySoft,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selectedChannel == null
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          for (final id in sensorIds)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(id),
                selected: selectedChannel == id,
                onSelected: (_) => onSelected(id),
                selectedColor: AppColors.primarySoft,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selectedChannel == id
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
