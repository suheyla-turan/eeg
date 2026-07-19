import 'package:flutter/foundation.dart';

import '../models/experiment.dart';
import '../models/history_item.dart';
import '../models/participant.dart';
import '../repositories/experiment_repository.dart';
import '../repositories/participant_repository.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider({
    required ParticipantRepository participantRepository,
    required ExperimentRepository experimentRepository,
  })  : _participants = participantRepository,
        _experiments = experimentRepository;

  final ParticipantRepository _participants;
  final ExperimentRepository _experiments;

  bool loading = false;
  String? errorMessage;
  String nameQuery = '';
  DateTime? filterStart;
  DateTime? filterEnd;

  List<HistoryItem> items = [];
  List<Experiment> participantExperiments = [];
  Participant? selectedParticipant;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
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
    notifyListeners();

    try {
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
}
