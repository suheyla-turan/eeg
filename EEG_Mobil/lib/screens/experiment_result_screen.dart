import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/experiment.dart';
import '../models/experiment_result.dart';
import '../models/participant.dart';
import '../models/phase_metrics.dart';
import '../theme/app_colors.dart';
import '../widgets/eeg_pdf_download_button.dart';
import '../widgets/experiment_interpretation_section.dart';
import '../widgets/section_card.dart';

/// Deney sonucu: Baseline / Reels / Metin + video istatistikleri + grafikler.
class ExperimentResultScreen extends StatelessWidget {
  const ExperimentResultScreen({
    super.key,
    required this.result,
    this.experiment,
    this.participant,
    this.cancelled = false,
  });

  final ExperimentResult result;
  final Experiment? experiment;
  final Participant? participant;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy HH:mm', 'tr');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(cancelled ? 'İptal Edilen Deney' : 'Deney Sonuçları'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          if (cancelled)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF0D4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                experiment?.cancelReason ??
                    'Bu deney iptal edildi. Kısmi veriler gösteriliyor.',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SectionCard(
            title: participant?.fullName ?? 'Katılımcı',
            subtitle: [
              if (participant != null)
                '${participant!.age} yaş · ${participant!.gender}',
              if (experiment?.createdAt != null)
                dateFmt.format(experiment!.createdAt),
              if (experiment?.storagePath != null)
                'Storage: ${experiment!.storagePath}',
              'Spektral analiz v${result.analysisVersion}',
            ].where((e) => e.isNotEmpty).join(' · '),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Attention', result.averageAttention),
                _chip('Focus', result.averageFocus),
                _chip('Engagement', result.averageEngagement),
                _chip('Mental Fatigue', result.mentalFatigue),
                _chip('Relaxation', result.averageRelaxation),
                _chip('Stress', result.averageStress),
                _chip('Distraction', result.distractionScore),
                _chip(
                  'Baseline Δ',
                  result.baselineDifference,
                  signed: true,
                  display: result.hasBaselineData ? null : 'yok',
                ),
              ],
            ),
          ),
          if (result.dataInsufficient)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                result.dataInsufficientReason.isNotEmpty
                    ? result.dataInsufficientReason
                    : 'Veri yetersiz: gerçek EEG spektral bantları bulunamadı.',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ExperimentInterpretationSection(
              result: result,
              participant: participant,
            ),
          ),
          _phaseSection('1. Reels', result.reels),
          _phaseSection('2. Metin', result.text),
          _bandsSection(),
          _ratiosSection(),
          _chartsSection(),
          _videoStatsSection(),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ExperimentSummaryCard(result: result),
          ),
          const SizedBox(height: 8),
          EegPdfDownloadButton(
            result: result,
            participant: participant,
            experimentDate: experiment?.createdAt,
            storagePath: experiment?.storagePath,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Ana Sayfaya Dön'),
          ),
        ],
      ),
    );
  }

  Widget _phaseSection(String title, PhaseMetrics m) {
    return SectionCard(
      title: title,
      subtitle: m.dataInsufficient
          ? 'Veri yetersiz'
          : m.sampleCount > 0
              ? '${m.sampleCount} örnek · ${m.durationSeconds} sn'
              : 'Bu aşamada örnek yok',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _metricTile('Attention', m.attention)),
              const SizedBox(width: 8),
              Expanded(child: _metricTile('Focus', m.focus)),
              const SizedBox(width: 8),
              Expanded(child: _metricTile('Stress', m.stress)),
              const SizedBox(width: 8),
              Expanded(child: _metricTile('Engagement', m.engagement)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metricTile('Relaxation', m.relaxation)),
              const SizedBox(width: 8),
              Expanded(child: _metricTile('Fatigue', m.mentalFatigue)),
              const SizedBox(width: 8),
              Expanded(child: _metricTile('Distraction', m.distraction)),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bandsSection() {
    return SectionCard(
      title: 'Relative Band Power',
      subtitle: 'Alpha · Beta · Theta · Delta · Gamma (%)',
      child: Row(
        children: [
          Expanded(child: _metricTile('α', result.alphaPower, decimals: 2)),
          const SizedBox(width: 8),
          Expanded(child: _metricTile('β', result.betaPower, decimals: 2)),
          const SizedBox(width: 8),
          Expanded(child: _metricTile('θ', result.thetaPower, decimals: 2)),
          const SizedBox(width: 8),
          Expanded(
            child: _metricTile(
              'δ',
              result.deltaPower,
              decimals: 2,
              display: result.isDeltaUnavailable ? 'N/A' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _metricTile('γ', result.gammaPower, decimals: 2)),
        ],
      ),
    );
  }

  Widget _ratiosSection() {
    return SectionCard(
      title: 'Spektral Oranlar',
      subtitle: 'θ/β · α/β · β/α · Baseline Change',
      child: Row(
        children: [
          Expanded(
            child: _metricTile('θ/β', result.thetaBetaRatio, decimals: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricTile('α/β', result.alphaBetaRatio, decimals: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricTile('β/α', result.betaAlphaRatio, decimals: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricTile(
              'Baseline Δ%',
              result.baselineDifference,
              decimals: 1,
              display: result.hasBaselineData
                  ? null
                  : 'Baseline verisi bulunamadı',
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartsSection() {
    return SectionCard(
      title: 'Grafikler',
      subtitle: 'Attention / Focus / Stress / Engagement zaman serisi',
      child: Column(
        children: [
          _lineChart(
            'Attention',
            result.attentionSeries,
            AppColors.primary,
          ),
          const SizedBox(height: 16),
          _lineChart('Focus', result.focusSeries, AppColors.accent),
          const SizedBox(height: 16),
          _lineChart('Stress', result.stressSeries, AppColors.danger),
          const SizedBox(height: 16),
          _lineChart(
            'Engagement',
            result.engagementSeries,
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _lineChart(String label, List<double> series, Color color) {
    if (series.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label — veri yok',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final spots = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), series[i]),
    ];

    final minV = series.reduce((a, b) => a < b ? a : b);
    final maxV = series.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV).abs() < 5 ? 8.0 : (maxV - minV) * 0.15);
    final yMin = (minV - pad).clamp(0.0, 95.0);
    final yMax = (maxV + pad).clamp(yMin + 5, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: yMin,
              maxY: yMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border.withValues(alpha: 0.6),
                  strokeWidth: 1,
                ),
              ),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(),
                rightTitles: AxisTitles(),
                bottomTitles: AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 25,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoStatsSection() {
    final v = result.videoStats;
    final cats = v.categoryWatchSeconds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SectionCard(
      title: 'Video İstatistikleri',
      subtitle: 'Reels aşaması özeti',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _metricTile('Toplam Video', v.totalVideos.toDouble(),
                    asInt: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile('Toplam Kaydırma', v.totalScrolls.toDouble(),
                    asInt: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  'Tekrar İzlenen',
                  v.rewatchedVideos.toDouble(),
                  asInt: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  'Ort. İzleme (sn)',
                  v.averageWatchSeconds,
                ),
              ),
            ],
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Kategori bazlı izleme süreleri',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            ...cats.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(color: AppColors.text),
                      ),
                    ),
                    Text(
                      '${e.value} sn',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    double value, {
    bool signed = false,
    String? display,
  }) {
    final text = display ??
        (signed
            ? '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}'
            : value.toStringAsFixed(1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label  $text',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }

  Widget _metricTile(
    String label,
    double value, {
    bool asInt = false,
    int decimals = 1,
    String? display,
  }) {
    final shown = display ??
        (asInt ? value.round().toString() : value.toStringAsFixed(decimals));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            shown,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: display != null && display.length > 6 ? 11 : 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
