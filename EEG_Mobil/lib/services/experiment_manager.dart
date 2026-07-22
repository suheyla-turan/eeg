import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_logger.dart';
import '../models/experiment.dart';
import '../models/experiment_result.dart';
import '../models/experiment_step.dart';
import '../models/participant.dart';
import '../models/text_content.dart';
import '../models/text_quiz_response.dart';
import '../models/video_content.dart';
import '../models/video_watch_event.dart';
import '../repositories/text_quiz_response_repository.dart';
import '../repositories/text_repository.dart';
import '../repositories/video_repository.dart';
import '../repositories/video_watch_event_repository.dart';
import 'experiment_session_service.dart';
import 'reels_warmup.dart';
import 'video_feed_scheduler.dart';

/// Profesyonel deney akışını yöneten merkezi orkestratör.
///
/// Provider mimarisi korunur: [ExperimentProvider] bu sınıfı sarmalar.
/// Repository Pattern ile kalıcı veri erişimi session/repo katmanından yapılır.
class ExperimentManager extends ChangeNotifier {
  ExperimentManager({
    required ExperimentSessionService sessionService,
    required VideoRepository videoRepository,
    required TextRepository textRepository,
    required VideoWatchEventRepository watchEventRepository,
    required TextQuizResponseRepository textQuizResponseRepository,
  })  : _session = sessionService,
        _videos = videoRepository,
        _texts = textRepository,
        _watchEvents = watchEventRepository,
        _quizResponses = textQuizResponseRepository;

  final ExperimentSessionService _session;
  final VideoRepository _videos;
  final TextRepository _texts;
  final VideoWatchEventRepository _watchEvents;
  final TextQuizResponseRepository _quizResponses;

  static const briefingCountdown = Duration(seconds: 15);
  static const reelsDuration = Duration(minutes: 10);
  /// Metin okuma oturumu süresi (reels ile aynı).
  static const textDuration = Duration(minutes: 10);
  /// Snapshot aralığı. Ham EEG (~128 Hz) PC API'de Welch ile işlenir;
  /// Flutter yalnızca hazır bandPower özetini kaydeder — undersampling
  /// spektral hesabı bozmaz. Bilişsel skorlar bu özetten türetilir.
  static const eegTickInterval = Duration(milliseconds: 500);

  ExperimentStep step = ExperimentStep.participantInfo;
  String? errorMessage;
  Participant? participant;
  Experiment? experiment;
  ExperimentResult? lastResult;
  String? lastStoragePath;
  int sampleCount = 0;

  List<VideoContent> videos = [];
  List<TextContent> texts = [];
  List<VideoWatchEvent> watchEvents = [];
  TextQuizResponse? lastQuizResponse;
  String? selectedTextId;

  Timer? _eegTimer;
  bool _busy = false;
  final ReelsWarmup reelsWarmup = ReelsWarmup();

  /// Bu deney için kilitlenen reels sırası (beginFlow'ta üretilir).
  VideoFeedScheduler? reelsPlaylist;

  bool get isBusy => _busy;
  bool get isRecording => _session.isRunning;
  bool get canPop => step.isTerminal;

  /// Akışı başlatır (katılımcı + experiment oluşturulduktan sonra).
  Future<void> beginFlow({
    required Participant participant,
    required Experiment experiment,
    String? selectedTextId,
  }) async {
    this.participant = participant;
    this.experiment = experiment;
    this.selectedTextId = selectedTextId;
    errorMessage = null;
    watchEvents = [];
    lastQuizResponse = null;
    sampleCount = 0;
    lastResult = null;
    lastStoragePath = null;

    await _enableWakeLock();
    await loadMediaOptions();
    _lockReelsPlaylist();
    goTo(ExperimentStep.eegConnection);
  }

  /// Checkpoint sonrası akışı mevcut kayıtla devam ettirir.
  Future<void> resumeFlow({
    required Participant participant,
    required Experiment experiment,
    required ExperimentStep atStep,
    String? selectedTextId,
    int restoredSampleCount = 0,
  }) async {
    this.participant = participant;
    this.experiment = experiment;
    this.selectedTextId = selectedTextId;
    errorMessage = null;
    lastResult = null;
    lastStoragePath = null;
    sampleCount = restoredSampleCount;

    await _enableWakeLock();
    await loadMediaOptions();
    _lockReelsPlaylist();
    goTo(atStep);
    if (_session.isRunning) {
      _startEegTicker();
    }
  }

  Future<void> loadMediaOptions({bool force = false}) async {
    if (!force && videos.isNotEmpty) return;
    try {
      videos = await _videos.getActive();
      texts = await _texts.getActive();
      AppLogger.instance.experiment(
        'Yerel medya yüklendi: ${videos.length} aktif video, '
        '${texts.length} aktif metin',
      );
      notifyListeners();
    } catch (e, st) {
      videos = [];
      texts = [];
      errorMessage = 'Medya yüklenemedi: $e';
      AppLogger.instance.error(
        'Aktif medya yüklenemedi',
        error: e,
        stackTrace: st,
      );
      if (kDebugMode) debugPrint('Media load: $e');
      notifyListeners();
    }
  }

  /// Reels bilgilendirme sırasında sabit sıradaki ilk videoları hazırlar.
  Future<void> prepareReelsWarmup() async {
    await loadMediaOptions();
    _lockReelsPlaylist();
    final playlist = reelsPlaylist;
    if (playlist == null) return;
    await reelsWarmup.ensureReady(playlist);
  }

  Future<void> ensureReelsWarmupReady() async {
    await loadMediaOptions();
    _lockReelsPlaylist();
    final playlist = reelsPlaylist;
    if (playlist == null) return;
    await reelsWarmup.ensureReady(playlist);
  }

  ReelsWarmupBundle? takeReelsWarmup() => reelsWarmup.take();

  /// Deney başında bir kez rastgele sıra üretir; oturum boyunca değişmez.
  void _lockReelsPlaylist() {
    if (reelsPlaylist != null) return;
    reelsPlaylist = VideoFeedScheduler.forExperiment(videos);
    final ids = reelsPlaylist!.firstRoundIds;
    AppLogger.instance.experiment(
      'Reels sırası kilitlendi (${reelsPlaylist!.sourceCount} video, '
      '${reelsPlaylist!.feed.length} slot): '
      '${ids.take(12).join(" → ")}${ids.length > 12 ? " → …" : ""}',
    );
  }

  void goTo(ExperimentStep next) {
    step = next;
    errorMessage = null;
    _session.setStepName(next.name);

    // EEG faz etiketi — kayıt kesilmez.
    if (next == ExperimentStep.reels ||
        next == ExperimentStep.reelsBriefing ||
        next == ExperimentStep.reelsCompleted) {
      if (_session.isRunning) _session.setPhase('reels');
    } else if (next == ExperimentStep.textReading ||
        next == ExperimentStep.textBriefing) {
      if (_session.isRunning) {
        _session.readingPhase = true;
        _session.setPhase('text');
      }
    }

    notifyListeners();
  }

  Future<void> proceedFromEegConnection() async {
    goTo(ExperimentStep.experimentBriefing);
  }

  /// Bilgilendirme sonrası EEG kaydını başlatır ve Reels öncesi adıma geçer.
  Future<bool> proceedFromBriefing() async {
    final ok = await startRecording(initialPhase: 'reels');
    if (!ok) return false;
    goTo(ExperimentStep.reelsBriefing);
    return true;
  }

  /// EEG kaydını başlatır (veya zaten açıksa ticker'ı sürdürür).
  Future<bool> startRecording({String initialPhase = 'reels'}) async {
    if (_session.isRunning) {
      _session.setPhase(initialPhase);
      _startEegTicker();
      return true;
    }
    _busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _session.startSession(initialPhase: initialPhase);
      experiment = _session.currentExperiment;
      sampleCount = _session.buffer.sampleCount;
      _startEegTicker();
      _busy = false;
      AppLogger.instance.experiment('EEG kayıt başladı ($initialPhase)');
      notifyListeners();
      return true;
    } catch (e) {
      _busy = false;
      errorMessage = e.toString();
      AppLogger.instance.error('EEG kayıt başlatılamadı', error: e);
      notifyListeners();
      return false;
    }
  }

  Future<void> proceedFromReelsBriefing() async {
    await ensureReelsWarmupReady();
    goTo(ExperimentStep.reels);
  }

  void onReelsFinished() {
    goTo(ExperimentStep.reelsCompleted);
  }

  Future<void> saveReelsMoodAndContinue({
    required List<String> moodOptions,
    String? moodOtherText,
  }) async {
    try {
      await _session.saveReelsMood(
        moodOptions: moodOptions,
        moodOtherText: moodOtherText,
      );
      experiment = _session.currentExperiment;
    } catch (e) {
      if (kDebugMode) debugPrint('Reels mood save: $e');
    }
    goTo(ExperimentStep.textBriefing);
  }

  void proceedFromReelsCompleted() {
    goTo(ExperimentStep.textBriefing);
  }

  void proceedFromTextBriefing() {
    goTo(ExperimentStep.textReading);
  }

  Future<void> saveWatchEvent({
    required String videoId,
    required DateTime startTime,
    required DateTime endTime,
    required int watchDurationSeconds,
    required double percentWatched,
    required int replayCount,
    required DateTime transitionTime,
    required String category,
  }) async {
    final exp = experiment ?? _session.currentExperiment;
    if (exp == null) return;

    final event = VideoWatchEvent(
      eventId: '',
      experimentId: exp.experimentId,
      videoId: videoId,
      startTime: startTime,
      endTime: endTime,
      watchDurationSeconds: watchDurationSeconds,
      percentWatched: percentWatched.clamp(0, 100),
      replayCount: replayCount,
      transitionTime: transitionTime,
      category: category,
    );

    try {
      final saved = await _watchEvents.create(event);
      watchEvents = [...watchEvents, saved];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Watch event save: $e');
    }
  }

  Future<TextContent?> resolveReadingText() async {
    final list = await resolveReadingTexts();
    if (list.isEmpty) return null;
    return list.first;
  }

  /// 10 dk oturumda sırayla gösterilecek tüm aktif metinler.
  Future<List<TextContent>> resolveReadingTexts() async {
    if (texts.isEmpty) {
      texts = await _texts.getActive();
    }
    final list = List<TextContent>.from(texts);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Metin testi + (oturum sonunda) duygu cevabını kaydeder.
  Future<void> saveQuizResponse({
    required String textId,
    required List<TextQuizAnswer> answers,
    List<String> moodOptions = const [],
    String? moodOtherText,
  }) async {
    final exp = experiment ?? _session.currentExperiment;
    if (exp == null) return;

    final response = TextQuizResponse(
      responseId: '',
      experimentId: exp.experimentId,
      textId: textId,
      answers: answers,
      moodOption: moodOptions.join(', '),
      moodOptions: moodOptions,
      moodOtherText: moodOtherText,
      createdAt: DateTime.now(),
    );

    try {
      lastQuizResponse = await _quizResponses.create(response);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Quiz response save: $e');
    }
  }

  /// Metin bitti → analiz → sonuç.
  Future<void> finishAndAnalyze() async {
    goTo(ExperimentStep.analyzing);
    _busy = true;
    notifyListeners();

    try {
      final done = await _session.completeSession(
        watchEvents: watchEvents,
      );
      experiment = done.experiment;
      lastResult = done.result;
      lastStoragePath = done.storagePath;
      sampleCount = _session.buffer.sampleCount;
      _stopEegTicker();
      await _disableWakeLock();
      _busy = false;
      goTo(ExperimentStep.results);
    } catch (e) {
      _busy = false;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Deneyi iptal eder; o ana kadar EEG verisi Firebase'e yüklenir.
  Future<bool> cancelExperiment() async {
    _busy = true;
    errorMessage = null;
    notifyListeners();
    await reelsWarmup.discard();

    try {
      final done = await _session.cancelSession(
        watchEvents: watchEvents,
        reason: 'Kullanıcı iptal etti',
      );
      experiment = done.experiment;
      lastResult = done.result;
      lastStoragePath = done.storagePath;
      sampleCount = _session.buffer.sampleCount;
      _stopEegTicker();
      await _disableWakeLock();
      _busy = false;
      goTo(ExperimentStep.cancelled);
      return true;
    } catch (e) {
      _busy = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _startEegTicker() {
    _eegTimer?.cancel();
    _eegTimer = Timer.periodic(eegTickInterval, (_) async {
      if (!_session.isRunning) return;
      await _session.recordLiveSample();
      final next = _session.buffer.sampleCount;
      if (next != sampleCount) {
        sampleCount = next;
        notifyListeners();
      }
    });
  }

  void _stopEegTicker() {
    _eegTimer?.cancel();
    _eegTimer = null;
  }

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      if (kDebugMode) debugPrint('Wakelock enable: $e');
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      if (kDebugMode) debugPrint('Wakelock disable: $e');
    }
  }

  Future<void> reset() async {
    _stopEegTicker();
    await reelsWarmup.discard();
    reelsPlaylist = null;
    await _disableWakeLock();
    _session.reset();
    step = ExperimentStep.participantInfo;
    errorMessage = null;
    participant = null;
    experiment = null;
    lastResult = null;
    lastStoragePath = null;
    sampleCount = 0;
    watchEvents = [];
    lastQuizResponse = null;
    selectedTextId = null;
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopEegTicker();
    unawaited(reelsWarmup.discard());
    unawaited(_disableWakeLock());
    super.dispose();
  }
}
