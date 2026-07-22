import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../core/app_dependencies.dart';
import '../models/experiment_result.dart';
import '../models/participant.dart';
import '../services/result_interpreter.dart';
import '../theme/app_colors.dart';

/// Deney sonuç ekranlarında Gemini (veya kural tabanlı) yorum bölümü.
///
/// Gemini yoksa açılışta PC API'den üretir; yüklenirken durum gösterir.
class ExperimentInterpretationSection extends StatefulWidget {
  const ExperimentInterpretationSection({
    super.key,
    required this.result,
    this.participant,
    this.autoFetchGemini = true,
  });

  final ExperimentResult result;
  final Participant? participant;
  final bool autoFetchGemini;

  @override
  State<ExperimentInterpretationSection> createState() =>
      _ExperimentInterpretationSectionState();
}

class _ExperimentInterpretationSectionState
    extends State<ExperimentInterpretationSection> {
  late ExperimentResult _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    if (widget.autoFetchGemini && !_result.hasGeminiInterpretation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGemini());
    }
  }

  @override
  void didUpdateWidget(covariant ExperimentInterpretationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.resultId != widget.result.resultId ||
        oldWidget.result.geminiMarkdown != widget.result.geminiMarkdown) {
      _result = widget.result;
      _error = null;
      if (widget.autoFetchGemini && !_result.hasGeminiInterpretation) {
        _fetchGemini();
      }
    }
  }

  Future<void> _fetchGemini() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final gemini = context.read<AppDependencies>().geminiSessionService;
      final updated = await gemini.ensureInterpretation(
        _result,
        participant: widget.participant,
      );
      if (!mounted) return;
      setState(() {
        _result = updated;
        _loading = false;
        if (!updated.hasGeminiInterpretation) {
          _error = gemini.lastError?.isNotEmpty == true
              ? 'Yorum alınamadı: ${gemini.lastError}'
              : 'Yorum alınamadı. PC API çalışıyor mu kontrol edin.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gemini bağlantı hatası: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _statusCard(
        context,
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Sonuçlar incelenip yorumlanıyor…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_result.hasGeminiInterpretation) {
      return _geminiCard(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          _statusCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _fetchGemini,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Tekrar dene'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        _ruleBasedCard(context),
      ],
    );
  }

  Widget _statusCard(BuildContext context, {required Widget child}) {
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
          const Text(
            'Değerlendirme',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _geminiCard(BuildContext context) {
    final modelLabel =
        _result.geminiModel.isNotEmpty ? _result.geminiModel : 'Gemini';

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
          const Text(
            'Değerlendirme',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reels (sosyal medya) ve metin okuma karşılaştırmasının sade AI yorumu '
            '($modelLabel). Klinik tanı içermez.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.secondary(context),
            ),
          ),
          if (_result.dataInsufficient) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF0D4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Bazı aşamalarda veri sınırlıdır; yorumlar mevcut '
                'örneklere göre oluşturulmuştur.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          MarkdownBody(
            data: _result.geminiMarkdown,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.text,
              ),
              h1: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
              h2: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              h3: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              listBullet: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
              ),
              strong: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              em: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.secondary(context),
              ),
              blockquote: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.secondary(context),
              ),
              horizontalRuleDecoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleBasedCard(BuildContext context) {
    final interpretation = ResultInterpreter.interpret(_result);

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
          const Text(
            'Otomatik Değerlendirme',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reels (~10 dk) ve metin okuma (~10 dk) aşamalarına dayalı '
            'tek-oturum yorumu. Klinik tanı içermez.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.secondary(context),
            ),
          ),
          if (interpretation.dataLimited) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF0D4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Bazı aşamalarda veri sınırlıdır; yorumlar mevcut '
                'örneklere göre oluşturulmuştur.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _section('1. Reels Analizi', interpretation.reelsAnalysis),
          const SizedBox(height: 14),
          _section('2. Metin Analizi', interpretation.textAnalysis),
          const SizedBox(height: 14),
          _section('3. Karşılaştırma', interpretation.comparison),
          const SizedBox(height: 14),
          _section('4. Genel Sonuç', interpretation.generalConclusion),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            height: 1.55,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

/// Deney özeti kartı — 4–6 maddelik kısa akademik özet.
class ExperimentSummaryCard extends StatelessWidget {
  const ExperimentSummaryCard({
    super.key,
    required this.result,
  });

  final ExperimentResult result;

  @override
  Widget build(BuildContext context) {
    final items = ResultInterpreter.interpret(result).sessionSummary;

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
          const Text(
            'DENEY ÖZETİ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tek oturum EEG eğilimlerinin kısa özeti',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.secondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.text,
                      ),
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
