import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/experiment_result.dart';
import '../../models/phase_metrics.dart';
import '../../models/video_experiment_stats.dart';
import '../../providers/experiment_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/experiment_interpretation_section.dart';
import '../../widgets/experiment_scaffold.dart';

/// Sonuç adımı: Baseline / Reels / Metin + video istatistikleri + grafikler.
class ExperimentResultsStepScreen extends StatelessWidget {
  const ExperimentResultsStepScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExperimentProvider>();
    final result = provider.lastResult;
    final participant = provider.participant;
    final experiment = provider.experiment;
    final cancelled = provider.phase == ExperimentPhase.cancelled ||
        experiment?.isCancelled == true;

    return ExperimentScaffold(
      title: cancelled ? 'İptal Edilen Deney' : 'Sonuçlar',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            cancelled ? 'Deney İptal Edildi' : 'Deney Tamamlandı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            participant == null
                ? 'Özet skorlar aşağıdadır. Sonuçlar geçmişe kaydedildi.'
                : '${participant.firstName} ${participant.lastName} · Sonuçlar geçmişe kaydedildi.',
            style: TextStyle(
              color: AppColors.secondary(context),
              height: 1.4,
            ),
          ),
          if (cancelled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF0D4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                experiment?.cancelReason ??
                    'Kısmi EEG verisi yüklendi; geçmişte görüntülenebilir.',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _StatCard(
            title: 'Özet',
            children: [
              _row('EEG örnekleri', '${provider.sampleCount}'),
              _row('Video izleme', '${provider.watchEvents.length}'),
              _row('Storage', provider.lastStoragePath ?? '-'),
              _row('Durum', experiment?.status ?? '-'),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 14),
            if (result.dataInsufficient) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.dataInsufficientReason.isNotEmpty
                      ? result.dataInsufficientReason
                      : 'Veri yetersiz: gerçek EEG spektral bantları bulunamadı. '
                          'Contact quality bilişsel skora dahil edilmez.',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _overallChips(result),
            const SizedBox(height: 14),
            ExperimentInterpretationSection(
              result: result,
              participant: participant,
            ),
            const SizedBox(height: 14),
            _phaseCard('1. Reels', result.reels),
            const SizedBox(height: 14),
            _phaseCard('2. Metin', result.text),
            const SizedBox(height: 14),
            _bandsCard(result),
            const SizedBox(height: 14),
            _ratiosCard(result),
            const SizedBox(height: 14),
            _chartsCard(result),
            const SizedBox(height: 14),
            _videoStatsCard(result.videoStats),
            const SizedBox(height: 14),
            ExperimentSummaryCard(result: result),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDone,
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

  Widget _overallChips(ExperimentResult result) {
    return _StatCard(
      title: 'Genel Metrikler',
      children: [
        Wrap(
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
              'Baseline Δ Att.',
              result.baselineDifference,
              signed: true,
              display: result.hasBaselineData ? null : 'yok',
            ),
          ],
        ),
      ],
    );
  }

  Widget _phaseCard(String title, PhaseMetrics m) {
    return _StatCard(
      title: title,
      children: [
        Text(
          m.dataInsufficient
              ? 'Veri yetersiz'
              : m.sampleCount > 0
                  ? '${m.sampleCount} örnek · ${m.durationSeconds} sn'
                  : 'Bu aşamada örnek yok',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _metric('Attention', m.attention)),
            const SizedBox(width: 8),
            Expanded(child: _metric('Focus', m.focus)),
            const SizedBox(width: 8),
            Expanded(child: _metric('Stress', m.stress)),
            const SizedBox(width: 8),
            Expanded(child: _metric('Engagement', m.engagement)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _metric('Relax', m.relaxation)),
            const SizedBox(width: 8),
            Expanded(child: _metric('Fatigue', m.mentalFatigue)),
            const SizedBox(width: 8),
            Expanded(child: _metric('Distract', m.distraction)),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _bandsCard(ExperimentResult result) {
    return _StatCard(
      title: 'Relative Band Power (%)',
      children: [
        Row(
          children: [
            Expanded(child: _metric('α Alpha', result.alphaPower, d: 2)),
            const SizedBox(width: 8),
            Expanded(child: _metric('β Beta', result.betaPower, d: 2)),
            const SizedBox(width: 8),
            Expanded(child: _metric('θ Theta', result.thetaPower, d: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metric(
                'δ Delta',
                result.deltaPower,
                d: 2,
                display: result.isDeltaUnavailable ? 'N/A' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _metric('γ Gamma', result.gammaPower, d: 2)),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _ratiosCard(ExperimentResult result) {
    return _StatCard(
      title: 'Spektral Oranlar & Baseline',
      children: [
        Row(
          children: [
            Expanded(
              child: _metric('θ/β', result.thetaBetaRatio, d: 2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric('α/β', result.alphaBetaRatio, d: 2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric('β/α', result.betaAlphaRatio, d: 2),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Baseline Δ Att. %',
                result.baselineDifference,
                d: 1,
                display: result.hasBaselineData
                    ? null
                    : 'Baseline verisi bulunamadı',
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _chartsCard(ExperimentResult result) {
    return _StatCard(
      title: 'Grafikler',
      children: [
        _chart('Attention', result.attentionSeries, AppColors.primary),
        const SizedBox(height: 14),
        _chart('Focus', result.focusSeries, AppColors.accent),
        const SizedBox(height: 14),
        _chart('Stress', result.stressSeries, AppColors.danger),
        const SizedBox(height: 14),
        _chart('Engagement', result.engagementSeries, AppColors.warning),
      ],
    );
  }

  Widget _chart(String label, List<double> series, Color color) {
    if (series.isEmpty) {
      return Container(
        height: 100,
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
        const SizedBox(height: 6),
        SizedBox(
          height: 130,
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
                  spots: [
                    for (var i = 0; i < series.length; i++)
                      FlSpot(i.toDouble(), series[i]),
                  ],
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

  Widget _videoStatsCard(VideoExperimentStats v) {
    final cats = v.categoryWatchSeconds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _StatCard(
      title: 'Video İstatistikleri',
      children: [
        Row(
          children: [
            Expanded(child: _metric('Toplam Video', v.totalVideos.toDouble(), asInt: true)),
            const SizedBox(width: 8),
            Expanded(
              child: _metric('Toplam Kaydırma', v.totalScrolls.toDouble(),
                  asInt: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Tekrar İzlenen',
                v.rewatchedVideos.toDouble(),
                asInt: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric('Ort. İzleme (sn)', v.averageWatchSeconds),
            ),
          ],
        ),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: 14),
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
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(e.key)),
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

  Widget _metric(
    String label,
    double value, {
    bool asInt = false,
    int d = 1,
    String? display,
  }) {
    final shown = display ??
        (asInt ? value.round().toString() : value.toStringAsFixed(d));
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
