import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analysis/emotion_analyzer.dart';
import '../providers/eeg_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/emotion_bar.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';

class AiAnalysisScreen extends StatelessWidget {
  const AiAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eeg = context.watch<EegProvider>();
    final live = eeg.live;
    final analysis = EmotionAnalyzer.analyze(live);
    final dominant = analysis.dominant;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: eeg.reconnect,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const Text(
                'Yapay Zeka Analizi',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sensör bölgelerinin anatomik / işlevsel rollerine göre duygu tahmini',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (live.error != null && !eeg.isConnected)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF0D4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    live.error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.warning,
                      height: 1.35,
                    ),
                  ),
                ),
              SectionCard(
                title: 'Anlık Durum',
                subtitle: analysis.hasSignal
                    ? 'Canlı temas kalitesi + bölge anlamları · ${live.connectionLabelTr}'
                    : 'Zayıf / yok sinyal · ${live.connectionLabelTr}',
                right: StatusPill(
                  label: analysis.hasSignal ? 'Canlı' : 'Bekleniyor',
                  tone: analysis.hasSignal
                      ? StatusTone.success
                      : StatusTone.warning,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: dominant.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dominant.label,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            '${dominant.score}% olasılık',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Duygu Dağılımı',
                subtitle:
                    'Mutlu←sol frontal · Üzgün←sağ frontal · Odaklı←prefrontal · Sakin←oksipital',
                child: Column(
                  children: analysis.emotions
                      .map((e) => EmotionBar(emotion: e))
                      .toList(),
                ),
              ),
              SectionCard(
                title: 'Neden bu sonuç?',
                subtitle: 'Sensör anlamlarına dayalı açıklama',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < analysis.reasons.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              analysis.reasons[i],
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.text,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nasıl hesaplanıyor?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'AF3/F3/F7 (sol frontal) → mutlu · AF4/F4/F8 (sağ frontal) → üzgün · '
                      'F8/T8 → sinirli · O1/O2/P7/P8 → sakin · AF/FC → stresli · '
                      'AF3/AF4/F3/F4 → odaklı. Emotiv temas kalitesi + canlı EEG akışı kullanılır.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
