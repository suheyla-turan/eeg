import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../models/experiment.dart';
import '../models/experiment_result.dart';
import '../models/experiment_step.dart';
import '../models/participant.dart';
import '../models/text_content.dart';
import '../models/video_content.dart';
import '../models/video_watch_event.dart';
import '../repositories/text_quiz_response_repository.dart';
import '../repositories/text_repository.dart';
import '../repositories/video_repository.dart';
import '../repositories/video_watch_event_repository.dart';
import '../services/experiment_manager.dart';
import '../services/experiment_session_service.dart';
import '../services/session_checkpoint_service.dart';

enum ExperimentPhase {
  idle,
  creating,
  ready,
  running,
  completing,
  completed,
  cancelled,
  error,
}

/// UI katmanı için Provider. Tam akış [ExperimentManager] üzerinden yönetilir.
class ExperimentProvider extends ChangeNotifier {
  ExperimentProvider({
    required ExperimentSessionService sessionService,
    required VideoRepository videoRepository,
    required TextRepository textRepository,
    required VideoWatchEventRepository watchEventRepository,
    required TextQuizResponseRepository textQuizResponseRepository,
  })  : _session = sessionService,
        manager = ExperimentManager(
          sessionService: sessionService,
          videoRepository: videoRepository,
          textRepository: textRepository,
          watchEventRepository: watchEventRepository,
          textQuizResponseRepository: textQuizResponseRepository,
        ) {
    manager.addListener(_onManagerChanged);
  }

  final ExperimentSessionService _session;
  final ExperimentManager manager;

  ExperimentPhase phase = ExperimentPhase.idle;
  String? errorMessage;
  Participant? participant;
  Experiment? experiment;
  ExperimentResult? lastResult;
  String? lastStoragePath;
  int sampleCount = 0;

  List<VideoContent> videos = [];
  List<TextContent> texts = [];
  List<VideoWatchEvent> watchEvents = [];
  String experimentType = 'full';
  String? selectedVideoId;
  String? selectedTextId;

  /// Reels aşamasından okuma aşamasına geçildiğinde true kalır.
  bool readingPhase = false;

  bool get isRunning =>
      phase == ExperimentPhase.running || manager.isRecording;

  ExperimentStep get currentStep => manager.step;

  ExperimentSessionService get sessionService => _session;

  void _onManagerChanged() {
    participant = manager.participant ?? participant;
    experiment = manager.experiment ?? experiment;
    lastResult = manager.lastResult ?? lastResult;
    lastStoragePath = manager.lastStoragePath ?? lastStoragePath;
    sampleCount = manager.sampleCount;
    watchEvents = manager.watchEvents;
    videos = manager.videos;
    texts = manager.texts;
    if (manager.isRecording) {
      phase = ExperimentPhase.running;
    } else if (manager.step == ExperimentStep.results) {
      phase = ExperimentPhase.completed;
    } else if (manager.step == ExperimentStep.analyzing) {
      phase = ExperimentPhase.completing;
    } else if (manager.step == ExperimentStep.cancelled) {
      phase = ExperimentPhase.cancelled;
    }
    if (manager.errorMessage != null) {
      errorMessage = manager.errorMessage;
    }
    // Checkpoint adım senkronu
    _session.setStepName(manager.step.name);
    notifyListeners();
  }

  Future<void> loadMediaOptions() async {
    try {
      await manager.loadMediaOptions();
      videos = manager.videos;
      texts = manager.texts;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Media load: $e');
    }
  }

  void setExperimentType(String type) {
    experimentType = type;
    notifyListeners();
  }

  void setSelectedVideo(String? id) {
    selectedVideoId = id;
    notifyListeners();
  }

  void setSelectedText(String? id) {
    selectedTextId = id;
    notifyListeners();
  }

  Future<bool> createParticipantAndExperiment(Participant draft) async {
    phase = ExperimentPhase.creating;
    errorMessage = null;
    readingPhase = false;
    watchEvents = [];
    notifyListeners();

    try {
      final created = await _session.createParticipantAndExperiment(
        draft: draft,
        experimentType: experimentType,
        videoId: selectedVideoId,
        textId: selectedTextId,
      );
      participant = created.participant;
      experiment = created.experiment;
      phase = ExperimentPhase.ready;
      sampleCount = 0;
      notifyListeners();
      return true;
    } catch (e) {
      phase = ExperimentPhase.error;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createExperimentForParticipant(Participant existing) async {
    phase = ExperimentPhase.creating;
    errorMessage = null;
    readingPhase = false;
    watchEvents = [];
    notifyListeners();

    try {
      final created = await _session.createExperimentForParticipant(
        participant: existing,
        experimentType: experimentType,
        videoId: selectedVideoId,
        textId: selectedTextId,
      );
      participant = created.participant;
      experiment = created.experiment;
      phase = ExperimentPhase.ready;
      sampleCount = 0;
      notifyListeners();
      return true;
    } catch (e) {
      phase = ExperimentPhase.error;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Tam profesyonel akışı başlatır (EEG bağlantısı → … → sonuçlar).
  Future<void> startFullExperimentFlow() async {
    final p = participant;
    final e = experiment;
    if (p == null || e == null) return;
    await manager.beginFlow(
      participant: p,
      experiment: e,
      selectedTextId: selectedTextId,
    );
  }

  Future<void> startSession({String initialPhase = 'reels'}) async {
    if (experiment == null) return;
    errorMessage = null;
    try {
      await _session.startSession(initialPhase: initialPhase);
      experiment = _session.currentExperiment;
      phase = ExperimentPhase.running;
      sampleCount = _session.buffer.sampleCount;
      AppLogger.instance.experiment('Oturum başladı ($initialPhase)');
      notifyListeners();
    } catch (e) {
      phase = ExperimentPhase.error;
      errorMessage = e.toString();
      AppLogger.instance.error('Oturum başlatılamadı', error: e);
      notifyListeners();
    }
  }

  /// Checkpoint'ten devam (crash recovery).
  Future<bool> resumeFromCheckpoint(SessionCheckpoint checkpoint) async {
    phase = ExperimentPhase.creating;
    errorMessage = null;
    notifyListeners();

    try {
      await _session.resumeFromCheckpoint(checkpoint);
      participant = _session.currentParticipant;
      experiment = _session.currentExperiment;
      experimentType = checkpoint.experimentType;
      selectedVideoId = checkpoint.videoId;
      selectedTextId = checkpoint.textId;
      readingPhase = checkpoint.readingPhase;
      sampleCount = _session.buffer.sampleCount;
      phase = ExperimentPhase.running;

      var restoredStep = ExperimentStep.values.firstWhere(
        (s) => s.name == checkpoint.step,
        orElse: () => checkpoint.readingPhase
            ? ExperimentStep.textReading
            : ExperimentStep.reelsBriefing,
      );
      // Baseline adımı kaldırıldı — eski kayıtları Reels bilgilendirmeye aktar.
      if (restoredStep == ExperimentStep.baseline) {
        restoredStep = ExperimentStep.reelsBriefing;
      }

      await manager.resumeFlow(
        participant: participant!,
        experiment: experiment!,
        atStep: restoredStep,
        selectedTextId: selectedTextId,
        restoredSampleCount: sampleCount,
      );

      AppLogger.instance.experiment(
        'Checkpoint devam: ${checkpoint.experimentId}',
      );
      notifyListeners();
      return true;
    } catch (e) {
      phase = ExperimentPhase.error;
      errorMessage = e.toString();
      AppLogger.instance.error('Checkpoint devam hatası', error: e);
      notifyListeners();
      return false;
    }
  }

  Future<void> tickCapture() async {
    if (phase != ExperimentPhase.running && !manager.isRecording) return;
    await _session.recordLiveSample();
    final next = _session.buffer.sampleCount;
    if (next != sampleCount) {
      sampleCount = next;
      notifyListeners();
    }
  }

  /// EEG kaydını kesmeden okuma aşamasına geçiş.
  void enterReadingPhase() {
    readingPhase = true;
    _session.readingPhase = true;
    _session.setPhase('text');
    notifyListeners();
  }

  void enterReelsPhase() {
    _session.setPhase('reels');
    notifyListeners();
  }

  Future<void> saveWatchEvent({
    required String videoId,
    required DateTime startTime,
    required DateTime endTime,
    required int watchDurationSeconds,
    required double percentWatched,
    required DateTime transitionTime,
    required String category,
    int replayCount = 0,
  }) async {
    // Tam akışta manager üzerinden kaydet.
    if (manager.step == ExperimentStep.reels ||
        manager.step == ExperimentStep.reelsCompleted) {
      await manager.saveWatchEvent(
        videoId: videoId,
        startTime: startTime,
        endTime: endTime,
        watchDurationSeconds: watchDurationSeconds,
        percentWatched: percentWatched,
        replayCount: replayCount,
        transitionTime: transitionTime,
        category: category,
      );
      return;
    }

    final exp = experiment;
    if (exp == null) return;

    await manager.saveWatchEvent(
      videoId: videoId,
      startTime: startTime,
      endTime: endTime,
      watchDurationSeconds: watchDurationSeconds,
      percentWatched: percentWatched,
      replayCount: replayCount,
      transitionTime: transitionTime,
      category: category,
    );
  }

  Future<TextContent?> resolveReadingText() async {
    return manager.resolveReadingText();
  }

  Future<bool> completeSession() async {
    phase = ExperimentPhase.completing;
    notifyListeners();

    try {
      final done = await _session.completeSession(watchEvents: watchEvents);
      experiment = done.experiment;
      lastResult = done.result;
      lastStoragePath = done.storagePath;
      phase = ExperimentPhase.completed;
      notifyListeners();
      return true;
    } catch (e) {
      phase = ExperimentPhase.error;
      errorMessage = e.toString();
      AppLogger.instance.error('Oturum tamamlama hatası', error: e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelSession({String reason = 'Kullanıcı iptal etti'}) async {
    phase = ExperimentPhase.completing;
    notifyListeners();
    try {
      final done = await _session.cancelSession(
        watchEvents: watchEvents,
        reason: reason,
      );
      experiment = done.experiment;
      lastResult = done.result;
      lastStoragePath = done.storagePath;
      phase = ExperimentPhase.cancelled;
      notifyListeners();
      return true;
    } catch (e) {
      phase = ExperimentPhase.error;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> reset() async {
    await manager.reset();
    phase = ExperimentPhase.idle;
    errorMessage = null;
    participant = null;
    experiment = null;
    lastResult = null;
    lastStoragePath = null;
    sampleCount = 0;
    readingPhase = false;
    watchEvents = [];
    notifyListeners();
  }

  @override
  void dispose() {
    manager.removeListener(_onManagerChanged);
    manager.dispose();
    super.dispose();
  }
}
