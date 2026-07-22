import 'experiment.dart';
import 'participant.dart';

/// Geçmiş listesinde katılımcı + deney birleşik görünümü.
class HistoryItem {
  final Participant participant;
  final Experiment experiment;

  const HistoryItem({
    required this.participant,
    required this.experiment,
  });
}
