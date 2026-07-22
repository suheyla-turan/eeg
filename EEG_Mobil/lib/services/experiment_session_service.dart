import 'dart:async';

import '../core/app_logger.dart';
import '../data/mock_eeg.dart';
import '../models/experiment.dart';
import '../models/experiment_result.dart';
import '../models/experiment_status.dart';
import '../models/participant.dart';
import '../models/video_watch_event.dart';
import '../repositories/eeg_storage_repository.dart';
import '../repositories/experiment_repository.dart';
import '../repositories/participant_repository.dart';
import '../repositories/result_repository.dart';
import 'eeg_api_service.dart';
import 'eeg_buffer_service.dart';
import 'eeg_service.dart';
import 'gemini_session_service.dart';
import 'result_calculator.dart';
import 'session_checkpoint_service.dart';

/// Katılımcı → tek parça EEG kaydı (Baseline → Reels → Metin) → Storage.
///
/// Önemli: [setPhase] yalnızca etiket değiştirir; API collection ve buffer
/// hiçbir aşamada kesilmez / temizlenmez.
///
/// Crash recovery: [SessionCheckpointService] ile periyodik yerel kayıt.
class ExperimentSessionService {
  ExperimentSessionService({
    required ParticipantRepository participantRepository,
    required ExperimentRepository experimentRepository,
    required ResultRepository resultRepository,
    required EegStorageRepository eegStorageRepository,
    required EegApiService eegApiService,
    EegService? eegService,
    EegBufferService? bufferService,
    ResultCalculator? resultCalculator,
    SessionCheckpointService? checkpointService,
    GeminiSessionService? geminiSessionService,
  })  : _participants = participantRepository,
        _experiments = experimentRepository,
        _results = resultRepository,
        _storage = eegStorageRepository,
        _api = eegApiService,
        _eeg = eegService,
        buffer = bufferService ?? EegBufferService(),
        _calculator = resultCalculator ?? ResultCalculator(),
        _checkpoint = checkpointService ?? SessionCheckpointService(),
        _gemini = geminiSessionService;

  final ParticipantRepository _participants;
  final ExperimentRepository _experiments;
  final ResultRepository _results;
  final EegStorageRepository _storage;
  final EegApiService _api;
  final EegService? _eeg;
  final ResultCalculator _calculator;
  final SessionCheckpointService _checkpoint;
  final GeminiSessionService? _gemini;

  final EegBufferService buffer;

  Participant? currentParticipant;
  Experiment? currentExperiment;
  bool isRunning = false;
  String currentPhase = 'reels';
  String currentStepName = 'reelsBriefing';
  bool readingPhase = false;

  Timer? _checkpointTimer;

  SessionCheckpointService get checkpointService => _checkpoint;

  Future<({Participant participant, Experiment experiment})>
      createParticipantAndExperiment({
    required Participant draft,
    String experimentType = 'full_protocol',
    String? videoId,
    String? textId,
  }) async {
    final participant = await _participants.create(draft);
    final experiment = await _experiments.create(
      Experiment(
        experimentId: '',
        participantId: participant.participantId,
        experimentType: experimentType,
        videoId: videoId,
        textId: textId,
        completed: false,
        status: ExperimentStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    currentParticipant = participant;
    currentExperiment = experiment;
    buffer.clear();
    currentPhase = 'reels';
    readingPhase = false;
    AppLogger.instance.experiment(
      'Oturum oluşturuldu: ${experiment.experimentId}',
    );
    return (participant: participant, experiment: experiment);
  }

  /// Mevcut katılımcı için yeni deney oturumu oluşturur.
  Future<({Participant participant, Experiment experiment})>
      createExperimentForParticipant({
    required Participant participant,
    String experimentType = 'full_protocol',
    String? videoId,
    String? textId,
  }) async {
    final experiment = await _experiments.create(
      Experiment(
        experimentId: '',
        participantId: participant.participantId,
        experimentType: experimentType,
        videoId: videoId,
        textId: textId,
        completed: false,
        status: ExperimentStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    currentParticipant = participant;
    currentExperiment = experiment;
    buffer.clear();
    currentPhase = 'reels';
    readingPhase = false;
    AppLogger.instance.experiment(
      'Mevcut katılımcı için oturum: ${experiment.experimentId}',
    );
    return (participant: participant, experiment: experiment);
  }

  Future<LiveEegState> requireConnected() async {
    LiveEegState live;
    final cached = _eeg?.latest;
    if (cached != null && cached.canStartExperiment) {
      live = cached;
    } else {
      try {
        final eeg = _eeg;
        live = eeg != null ? await eeg.fetchLive() : await _api.fetchLive();
      } catch (e) {
        AppLogger.instance.eeg(
          'Bağlantı kontrolü başarısız',
          level: LogLevel.error,
          error: e,
        );
        throw StateError(
          'EEG cihazı bağlı değil. Python API\'ye ulaşılamadı '
          '(${EegApiConfig.displayUrl}). '
          'Cihaz yoksa Ayarlar → Demo modunu açın.',
        );
      }
    }

    if (!live.canStartExperiment) {
      throw StateError(
        'EEG cihazı bağlı değil (durum: ${live.connectionLabelTr}). '
        'Cihazı takıp bağlantı "Bağlı" olana kadar bekleyin '
        '(veya Ayarlar → Demo modu).',
      );
    }
    return live;
  }

  Future<void> _startCollection() async {
    final eeg = _eeg;
    if (eeg != null) {
      await eeg.startCollection();
    } else {
      await _api.startCollection();
    }
  }

  Future<void> _stopCollection() async {
    final eeg = _eeg;
    if (eeg != null) {
      await eeg.stopCollection();
    } else {
      await _api.stopCollection();
    }
  }

  /// Tek seferlik kayıt başlatma. Sonraki aşamalarda tekrar çağrılmaz.
  Future<void> startSession({String initialPhase = 'reels'}) async {
    final experiment = currentExperiment;
    if (experiment == null) {
      throw StateError('Önce katılımcı ve experiment oluşturulmalı');
    }
    if (isRunning) {
      setPhase(initialPhase);
      return;
    }

    await requireConnected();

    buffer.clear();
    currentPhase = initialPhase;
    buffer.setPhase(initialPhase);
    isRunning = true;

    final started = experiment.copyWith(
      startTime: DateTime.now(),
      status: ExperimentStatus.running,
    );
    currentExperiment = started;
    await _experiments.update(started);

    // Test dump: PC'de reel/metin dosyalarını sıfırla
    try {
      await _api.resetTestDump();
      AppLogger.instance.experiment('Test EEG dump sıfırlandı (reels/text ayrı)');
    } catch (e) {
      AppLogger.instance.experiment('Test dump reset atlandı: $e');
    }

    try {
      await _startCollection();
      AppLogger.instance.experiment(
        'Kayıt başladı: ${started.experimentId} ($initialPhase)'
        '${_eeg?.isDemoMode == true ? " [demo]" : ""}',
      );
    } catch (e) {
      isRunning = false;
      AppLogger.instance.eeg(
        'Collection start hatası',
        level: LogLevel.error,
        error: e,
      );
      throw StateError('EEG veri toplama başlatılamadı: $e');
    }

    _startCheckpointTimer();
    await _saveCheckpoint();
  }

  /// Crash recovery: checkpoint'ten oturumu yeniden bağlar.
  Future<void> resumeFromCheckpoint(SessionCheckpoint cp) async {
    final experiment = await _experiments.getById(cp.experimentId);
    if (experiment == null) {
      throw StateError('Checkpoint deneyı bulunamadı: ${cp.experimentId}');
    }
    final participant = await _participants.getById(cp.participantId);
    if (participant == null) {
      throw StateError('Checkpoint katılımcısı bulunamadı: ${cp.participantId}');
    }

    currentExperiment = experiment;
    currentParticipant = participant;
    currentPhase = cp.phase;
    currentStepName = cp.step;
    readingPhase = cp.readingPhase;
    buffer.restoreSamples(cp.samples, phase: cp.phase);
    isRunning = true;

    final resumed = experiment.copyWith(status: ExperimentStatus.running);
    currentExperiment = resumed;
    await _experiments.update(resumed);

    try {
      await requireConnected();
      await _startCollection();
    } catch (e) {
      AppLogger.instance.eeg(
        'Resume collection uyarısı',
        level: LogLevel.warning,
        error: e,
      );
    }

    _startCheckpointTimer();
    AppLogger.instance.experiment(
      'Checkpoint\'ten devam: ${cp.experimentId} '
      '(${cp.sampleCount} örnek)',
    );
  }

  /// Uygulama açılışında yarım kalan deneyi taslak olarak işaretle
  /// (checkpoint yoksa veya kullanıcı sonlandırırsa).
  Future<void> markAsDraft(
    Experiment experiment, {
    String reason = 'Beklenmeyen kapanma',
  }) async {
    final draft = experiment.copyWith(
      status: ExperimentStatus.draft,
      completed: false,
      cancelReason: reason,
    );
    await _experiments.update(draft);
    AppLogger.instance.experiment(
      'Taslak işaretlendi: ${experiment.experimentId}',
    );
  }

  void _startCheckpointTimer() {
    _checkpointTimer?.cancel();
    // 5 sn + tüm sample deep-copy ExoPlayer ile birlikte OOM tetikliyordu.
    _checkpointTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_saveCheckpoint()),
    );
  }

  void _stopCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
  }

  Future<void> _saveCheckpoint() async {
    final experiment = currentExperiment;
    final participant = currentParticipant;
    if (!isRunning || experiment == null || participant == null) return;
    if (buffer.isEmpty && experiment.startTime == null) return;

    await _checkpoint.save(
      SessionCheckpoint(
        experimentId: experiment.experimentId,
        participantId: participant.participantId,
        experimentType: experiment.experimentType,
        phase: currentPhase,
        step: currentStepName,
        // Deep-copy yok — yalnızca liste anlık görüntüsü (heap baskısını azaltır).
        samples: List<Map<String, dynamic>>.from(buffer.samples),
        savedAt: DateTime.now(),
        videoId: experiment.videoId,
        textId: experiment.textId,
        readingPhase: readingPhase,
      ),
    );
  }

  /// Kayıt kesilmez — yalnızca örnek etiketini değiştirir.
  void setPhase(String phase) {
    currentPhase = phase;
    buffer.setPhase(phase);
    unawaited(_saveCheckpoint());
  }

  void setStepName(String stepName) {
    currentStepName = stepName;
  }

  Future<void> recordLiveSample() async {
    if (!isRunning) return;
    try {
      final eeg = _eeg;
      final LiveEegState live;
      if (eeg != null) {
        live = eeg.latest.canStartExperiment
            ? eeg.latest
            : await eeg.fetchLive();
      } else {
        live = await _api.fetchLive();
      }
      if (!live.canStartExperiment) return;
      buffer.addSample(live, phase: currentPhase);
      // Test dump: her örneği PC'ye phase bazlı yaz (reel / metin ayrı)
      final sample = buffer.samples.isNotEmpty ? buffer.samples.last : null;
      if (sample != null) {
        unawaited(() async {
          try {
            await _api.dumpTestSample(Map<String, dynamic>.from(sample));
          } catch (_) {}
        }());
      }
    } catch (_) {
      // Bağlantı kesilirse buffer'a ekleme; oturum devam eder.
    }
  }

  Future<({Experiment experiment, ExperimentResult result, String storagePath})>
      completeSession({
    List<VideoWatchEvent> watchEvents = const [],
    bool cancelled = false,
    String? cancelReason,
  }) async {
    final experiment = currentExperiment;
    final participant = currentParticipant;
    if (experiment == null || participant == null) {
      throw StateError('Aktif oturum yok');
    }

    _stopCheckpointTimer();
    // Son checkpoint — veri kaybını önle
    await _saveCheckpoint();

    isRunning = false;
    final endTime = DateTime.now();
    final start = experiment.startTime ?? experiment.createdAt;
    final durationSec = endTime.difference(start).inSeconds;

    try {
      await _stopCollection();
    } catch (_) {}

    final payload = buffer.toJsonPayload(
      experimentId: experiment.experimentId,
      participantId: participant.participantId,
      meta: {
        'cancelled': cancelled,
        if (cancelReason != null) 'cancelReason': cancelReason,
        'phases': ['reels', 'text'],
        'analysisVersion': ResultCalculator.analysisVersion,
      },
    );
    final csv = buffer.toCsv(
      experimentId: experiment.experimentId,
      participantId: participant.participantId,
    );

    // Test dump: reels / text ayrı JSON (PC _export/test_run)
    try {
      await _api.finalizeTestDump(payload);
      AppLogger.instance.experiment(
        'Test EEG dump finalize: '
        'reels=${buffer.samplesForPhase('reels').length} '
        'text=${buffer.samplesForPhase('text').length}',
      );
    } catch (e) {
      AppLogger.instance.experiment('Test dump finalize atlandı: $e');
    }

    final uploaded = await _storage.uploadPair(
      experimentId: experiment.experimentId,
      jsonPayload: payload,
      csvContent: csv,
    );

    final resultDraft = _calculator.calculate(
      experimentId: experiment.experimentId,
      participantId: participant.participantId,
      buffer: buffer,
      watchEvents: watchEvents,
    );
    var result = await _results.create(resultDraft);

    // PC API açıksa Gemini yorumunu üret ve kaydet (başarısız olursa kural tabanlı kalır).
    final gemini = _gemini;
    if (gemini != null && !cancelled) {
      result = await gemini.ensureInterpretation(result);
    }

    final status = cancelled
        ? ExperimentStatus.cancelled
        : ExperimentStatus.completed;

    final finished = experiment.copyWith(
      endTime: endTime,
      duration: durationSec,
      completed: !cancelled,
      status: status,
      storagePath: uploaded.folderPath,
      csvStoragePath: uploaded.csvPath,
      resultId: result.resultId,
      cancelReason: cancelReason,
    );
    await _experiments.update(finished);
    currentExperiment = finished;

    await _checkpoint.clear();

    AppLogger.instance.experiment(
      cancelled
          ? 'Oturum iptal: ${finished.experimentId}'
          : 'Oturum tamamlandı: ${finished.experimentId} '
              '(${buffer.sampleCount} örnek)',
    );

    return (
      experiment: finished,
      result: result,
      storagePath: uploaded.folderPath,
    );
  }

  /// Video aşaması sonrası duygu cevabını deneye yazar.
  Future<void> saveReelsMood({
    required List<String> moodOptions,
    String? moodOtherText,
  }) async {
    final experiment = currentExperiment;
    if (experiment == null) return;

    final joined = moodOptions.join(', ');
    final updated = experiment.copyWith(
      reelsMoodOption: joined,
      reelsMoodOptions: List<String>.from(moodOptions),
      reelsMoodOtherText: moodOtherText,
    );
    await _experiments.update(updated);
    currentExperiment = updated;
    AppLogger.instance.experiment(
      'Reels duygu kaydı: $joined'
      '${moodOtherText != null && moodOtherText.isNotEmpty ? ' ($moodOtherText)' : ''}',
    );
  }

  /// İptal: kayıt durur, kısmi JSON/CSV yine yüklenir, status=cancelled.
  Future<({Experiment? experiment, ExperimentResult? result, String? storagePath})>
      cancelSession({
    List<VideoWatchEvent> watchEvents = const [],
    String reason = 'Kullanıcı iptal etti',
  }) async {
    final experiment = currentExperiment;
    if (experiment == null) {
      return (experiment: null, result: null, storagePath: null);
    }

    _stopCheckpointTimer();

    if (buffer.isEmpty) {
      isRunning = false;
      try {
        await _stopCollection();
      } catch (_) {}

      final cancelled = experiment.copyWith(
        endTime: DateTime.now(),
        completed: false,
        status: ExperimentStatus.cancelled,
        cancelReason: reason,
        duration: experiment.startTime != null
            ? DateTime.now().difference(experiment.startTime!).inSeconds
            : 0,
      );
      await _experiments.update(cancelled);
      currentExperiment = cancelled;
      await _checkpoint.clear();
      AppLogger.instance.experiment(
        'Oturum iptal (boş buffer): ${cancelled.experimentId}',
      );
      return (experiment: cancelled, result: null, storagePath: null);
    }

    final done = await completeSession(
      watchEvents: watchEvents,
      cancelled: true,
      cancelReason: reason,
    );
    return (
      experiment: done.experiment,
      result: done.result,
      storagePath: done.storagePath,
    );
  }

  void reset() {
    _stopCheckpointTimer();
    isRunning = false;
    currentParticipant = null;
    currentExperiment = null;
    currentPhase = 'reels';
    currentStepName = 'reelsBriefing';
    readingPhase = false;
    buffer.clear();
  }

  void dispose() {
    _stopCheckpointTimer();
    // Kapanırken son checkpoint'i senkron yazmaya çalış
    if (isRunning) {
      unawaited(_saveCheckpoint());
    }
    reset();
  }
}
