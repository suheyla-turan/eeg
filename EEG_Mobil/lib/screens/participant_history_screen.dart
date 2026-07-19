import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_dependencies.dart';
import '../core/app_page_route.dart';
import '../models/experiment.dart';
import '../models/experiment_status.dart';
import '../models/participant.dart';
import '../providers/history_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import 'experiment_result_screen.dart';

class ParticipantHistoryScreen extends StatefulWidget {
  const ParticipantHistoryScreen({super.key, required this.participant});

  final Participant participant;

  @override
  State<ParticipantHistoryScreen> createState() =>
      _ParticipantHistoryScreenState();
}

class _ParticipantHistoryScreenState extends State<ParticipantHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<HistoryProvider>()
          .loadParticipantHistory(widget.participant);
    });
  }

  Future<void> _openResult(Experiment exp) async {
    final deps = context.read<AppDependencies>();
    if (exp.resultId == null || exp.resultId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu deney için sonuç kaydı yok')),
      );
      return;
    }

    final result = await deps.resultRepository.getById(exp.resultId!);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sonuç bulunamadı')),
      );
      return;
    }

    await Navigator.of(context).push(
      AppPageRoute<void>(
        transition: AppTransition.sharedAxisY,
        builder: (_) => ExperimentResultScreen(
          result: result,
          experiment: exp,
          participant: widget.participant,
          cancelled: exp.isCancelled,
        ),
      ),
    );
  }

  String _statusLabel(Experiment exp) {
    if (exp.status == ExperimentStatus.cancelled || exp.isCancelled) {
      return 'İptal edildi';
    }
    if (exp.completed || exp.status == ExperimentStatus.completed) {
      return 'Tamamlandı';
    }
    if (exp.status == ExperimentStatus.running) return 'Devam ediyor';
    return 'Beklemede';
  }

  Color _statusColor(Experiment exp) {
    if (exp.isCancelled) return AppColors.danger;
    if (exp.completed) return AppColors.success;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final p = widget.participant;
    final dateFmt = DateFormat('d MMM yyyy HH:mm', 'tr');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(p.fullName),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          SectionCard(
            title: 'Katılımcı',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _info('Yaş / Cinsiyet', '${p.age} · ${p.gender}'),
                _info('Eğitim', p.education),
                _info('Meslek', p.occupation),
                _info('Sosyal medya', p.dailySocialMediaUsage),
                _info('Baskın el', p.dominantHand),
                _info(
                  'Gözlük',
                  p.visionProblem ? 'Evet' : 'Hayır',
                ),
                _info('Uyku', p.sleepDuration),
                if (p.notes.isNotEmpty) _info('Notlar', p.notes),
              ],
            ),
          ),
          SectionCard(
            title: 'Deney Geçmişi',
            subtitle: history.loading
                ? 'Yükleniyor…'
                : '${history.participantExperiments.length} deney '
                    '(tamamlanan + iptal)',
            child: history.participantExperiments.isEmpty
                ? const Text(
                    'Bu katılımcıya ait deney yok.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : Column(
                    children: history.participantExperiments.map((exp) {
                      return Material(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: exp.resultId != null
                              ? () => _openResult(exp)
                              : null,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exp.experimentType,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                    if (exp.resultId != null)
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.textMuted,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFmt.format(exp.createdAt),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (exp.duration != null)
                                  Text(
                                    'Süre: ${exp.duration} sn',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (exp.storagePath != null)
                                  Text(
                                    'EEG: ${exp.storagePath}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  _statusLabel(exp),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _statusColor(exp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
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
}
