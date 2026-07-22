import 'package:flutter/foundation.dart';

import '../models/experiment.dart';
import '../models/history_item.dart';
import '../models/participant.dart';
import '../repositories/experiment_repository.dart';
import '../repositories/participant_repository.dart';
import '../services/result_reanalyzer.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({
    required ParticipantRepository participantRepository,
    required ExperimentRepository experimentRepository,
    ResultReanalyzer? resultReanalyzer,
  })  : _participants = participantRepository,
        _experiments = experimentRepository,
        _reanalyzer = resultReanalyzer;

  final ParticipantRepository _participants;
  final ExperimentRepository _experiments;
  final ResultReanalyzer? _reanalyzer;

  bool loading = false;
  bool reanalyzing = false;
  String? errorMessage;
  String? reanalysisMessage;
  String nameQuery = '';
  DateTime? filterStart;
  DateTime? filterEnd;

  List<HistoryItem> items = [];
  List<Experiment> participantExperiments = [];
  Participant? selectedParticipant;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    reanalysisMessage = null;
    notifyListeners();

    try {
      final experiments = await _experiments.getByDateRange(
        start: filterStart,
        end: filterEnd,
      );

      final cache = <String, Participant>{};
      final result = <HistoryItem>[];

      for (final exp in experiments) {
        var p = cache[exp.participantId];
        if (p == null) {
          p = await _participants.getById(exp.participantId);
          if (p != null) cache[exp.participantId] = p;
        }
        if (p == null) continue;

        if (nameQuery.trim().isNotEmpty) {
          final q = nameQuery.trim().toLowerCase();
          final full = p.fullName.toLowerCase();
          if (!full.contains(q) &&
              !p.firstName.toLowerCase().contains(q) &&
              !p.lastName.toLowerCase().contains(q)) {
            continue;
          }
        }

        result.add(HistoryItem(participant: p, experiment: exp));
      }

      items = result;

      // Eski sonuçları v3 spektral analize yükselt (arka planda)
      await _upgradeInBackground(experiments);
    } catch (e) {
      errorMessage = e.toString();
      if (kDebugMode) debugPrint('History load: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setNameQuery(String value) {
    nameQuery = value;
    notifyListeners();
  }

  void setDateFilter({DateTime? start, DateTime? end}) {
    filterStart = start;
    filterEnd = end;
    notifyListeners();
  }

  void clearFilters() {
    nameQuery = '';
    filterStart = null;
    filterEnd = null;
    notifyListeners();
  }

  Future<void> loadParticipantHistory(Participant participant) async {
    selectedParticipant = participant;
    loading = true;
    errorMessage = null;
    reanalysisMessage = null;
    notifyListeners();

    try {
      participantExperiments =
          await _experiments.getByParticipantId(participant.participantId);

      await _upgradeInBackground(participantExperiments);

      // resultId yeni bağlandıysa listeyi tazele
      participantExperiments =
          await _experiments.getByParticipantId(participant.participantId);
    } catch (e) {
      errorMessage = e.toString();
      participantExperiments = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _upgradeInBackground(List<Experiment> experiments) async {
    final reanalyzer = _reanalyzer;
    if (reanalyzer == null || experiments.isEmpty) return;

    reanalyzing = true;
    notifyListeners();
    try {
      final summary = await reanalyzer.upgradeExperiments(experiments);
      if (summary.didUpgrade) {
        reanalysisMessage =
                    '${summary.upgraded} eski deney yeni spektral analize (v5) güncellendi';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('History reanalyze: $e');
    } finally {
      reanalyzing = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExperiment(String experimentId) async {
    try {
      await _experiments.delete(experimentId);
      items = items
          .where((e) => e.experiment.experimentId != experimentId)
          .toList();
      participantExperiments = participantExperiments
          .where((e) => e.experimentId != experimentId)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      if (kDebugMode) debugPrint('History delete: $e');
      return false;
    }
  }

  Future<bool> deleteAllHistory() async {
    try {
      await _experiments.deleteAll();
      items = [];
      participantExperiments = [];
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      if (kDebugMode) debugPrint('History deleteAll: $e');
      return false;
    }
  }
}
