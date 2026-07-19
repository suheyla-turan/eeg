import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../models/experiment.dart';
import '../models/experiment_status.dart';
import '../models/participant.dart';
import '../repositories/experiment_repository.dart';
import '../repositories/participant_repository.dart';
import '../services/experiment_session_service.dart';
import '../services/session_checkpoint_service.dart';

/// Uygulama açılışında yarım kalan deneyleri tespit eder.
class RecoveryProvider extends ChangeNotifier {
  RecoveryProvider({
    required ExperimentRepository experimentRepository,
    required ParticipantRepository participantRepository,
    required ExperimentSessionService sessionService,
  })  : _experiments = experimentRepository,
        _participants = participantRepository,
        _session = sessionService;

  final ExperimentRepository _experiments;
  final ParticipantRepository _participants;
  final ExperimentSessionService _session;

  bool checking = true;
  bool dialogShown = false;
  SessionCheckpoint? checkpoint;
  Experiment? incompleteExperiment;
  Participant? incompleteParticipant;

  bool get hasRecoverableSession =>
      checkpoint != null || incompleteExperiment != null;

  Future<void> checkOnStartup() async {
    checking = true;
    notifyListeners();

    try {
      checkpoint = await _session.checkpointService.load();

      if (checkpoint != null) {
        incompleteExperiment =
            await _experiments.getById(checkpoint!.experimentId);
        if (incompleteExperiment != null) {
          incompleteParticipant = await _participants
              .getById(incompleteExperiment!.participantId);
        }

        // Checkpoint var ama experiment completed ise temizle
        if (incompleteExperiment == null ||
            incompleteExperiment!.completed ||
            incompleteExperiment!.status == ExperimentStatus.completed ||
            incompleteExperiment!.status == ExperimentStatus.cancelled) {
          await _session.checkpointService.clear();
          checkpoint = null;
          incompleteExperiment = null;
          incompleteParticipant = null;
        } else {
          // Beklenmeyen kapanma → taslak işaretle (kullanıcı karar verene kadar)
          if (incompleteExperiment!.status == ExperimentStatus.running) {
            await _session.markAsDraft(
              incompleteExperiment!,
              reason: 'Beklenmeyen kapanma — kurtarma bekleniyor',
            );
            incompleteExperiment = incompleteExperiment!.copyWith(
              status: ExperimentStatus.draft,
            );
          }
        }
      } else {
        // Checkpoint yok; Firestore'da orphan running/pending ara
        final incomplete = await _experiments.getIncomplete();
        if (incomplete.isNotEmpty) {
          incompleteExperiment = incomplete.first;
          incompleteParticipant = await _participants
              .getById(incompleteExperiment!.participantId);
          if (incompleteExperiment!.status == ExperimentStatus.running) {
            await _session.markAsDraft(
              incompleteExperiment!,
              reason: 'Beklenmeyen kapanma',
            );
            incompleteExperiment = incompleteExperiment!.copyWith(
              status: ExperimentStatus.draft,
            );
          }
        }
      }

      if (hasRecoverableSession) {
        AppLogger.instance.experiment(
          'Yarım kalan deney bulundu: '
          '${incompleteExperiment?.experimentId ?? checkpoint?.experimentId}',
        );
      }
    } catch (e, st) {
      AppLogger.instance.error(
        'Recovery kontrolü hatası',
        error: e,
        stackTrace: st,
      );
      if (kDebugMode) debugPrint('Recovery: $e');
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  void markDialogShown() {
    dialogShown = true;
    notifyListeners();
  }

  Future<void> discardAsCancelled() async {
    final exp = incompleteExperiment;
    if (exp != null) {
      final cancelled = exp.copyWith(
        status: ExperimentStatus.cancelled,
        completed: false,
        endTime: DateTime.now(),
        cancelReason: 'Kullanıcı sonlandırdı (kurtarma diyaloğu)',
      );
      await _experiments.update(cancelled);
      AppLogger.instance.experiment(
        'Yarım kalan deney sonlandırıldı: ${exp.experimentId}',
      );
    }
    await _session.checkpointService.clear();
    checkpoint = null;
    incompleteExperiment = null;
    incompleteParticipant = null;
    notifyListeners();
  }

  void clearLocalState() {
    checkpoint = null;
    incompleteExperiment = null;
    incompleteParticipant = null;
    notifyListeners();
  }
}
