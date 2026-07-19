import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/app_logger.dart';
import '../models/video_content.dart';
import '../providers/eeg_provider.dart';
import '../providers/experiment_provider.dart';
import '../services/video_feed_scheduler.dart';
import '../theme/app_colors.dart';
import '../widgets/forward_only_scroll_physics.dart';
import 'reading_experiment_screen.dart';

/// TikTok / Reels tarzı dikey video deneyi.
/// EEG kaydı kesilmez — mevcut oturum devam eder.
class VideoReelsExperimentScreen extends StatefulWidget {
  const VideoReelsExperimentScreen({
    super.key,
    this.continueExistingSession = false,
    this.returnToFlowOnComplete = false,
  });

  /// true ise oturum yeniden başlatılmaz (Baseline sonrası geçiş).
  final bool continueExistingSession;

  /// true ise Reading'e gitmez; Flow ekranına geri döner.
  final bool returnToFlowOnComplete;

  static const experimentDuration = Duration(minutes: 10);

  @override
  State<VideoReelsExperimentScreen> createState() =>
      _VideoReelsExperimentScreenState();
}

class _VideoReelsExperimentScreenState
    extends State<VideoReelsExperimentScreen> {
  final _pageController = PageController();

  Timer? _eegTimer;
  Timer? _experimentTimer;
  Timer? _uiTimer;

  List<VideoContent> _videos = [];
  VideoFeedScheduler? _feed;
  int _currentIndex = 0;
  bool _loading = true;
  String? _loadError;
  bool _transitioning = false;

  DateTime? _sessionStartedAt;
  Duration _elapsed = Duration.zero;

  DateTime? _videoStartedAt;

  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _eegTimer?.cancel();
    _experimentTimer?.cancel();
    _uiTimer?.cancel();
    _controller?.dispose();
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final provider = context.read<ExperimentProvider>();
    final eeg = context.read<EegProvider>();
    try {
      await provider.loadMediaOptions();
      _videos = List<VideoContent>.from(
        provider.videos.where((v) => v.storageUrl.trim().isNotEmpty),
      );
      if (_videos.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = provider.errorMessage ??
              'Oynatılabilir aktif video yok. Videolar ekranında '
                  'yükleme tamamlanmış ve Aktif olan kayıtlar olmalı '
                  '(storageUrl dolu).';
        });
        return;
      }

      // Tur 1: rastgele sıra. Sonraki turlar kullanıcı tüm videoları bitirince eklenir.
      _feed = VideoFeedScheduler(_videos);

      if (!provider.isRunning && !widget.continueExistingSession) {
        if (!eeg.canStartExperiment) {
          setState(() {
            _loading = false;
            _loadError =
                'EEG cihazı bağlı değil (durum: ${eeg.connectionLabel}). '
                'Cihazı bağlayıp tekrar deneyin.';
          });
          return;
        }
        await provider.startSession(initialPhase: 'reels');
        if (provider.errorMessage != null) {
          setState(() {
            _loading = false;
            _loadError = provider.errorMessage;
          });
          return;
        }
      } else if (provider.isRunning) {
        provider.enterReelsPhase();
      }
      if (!mounted) return;

      _sessionStartedAt = DateTime.now();
      _startEegTicker();
      _startExperimentCountdown();
      _startUiTicker();

      AppLogger.instance.experiment(
        'Reels: ${_videos.length} video hazır, oynatma başlıyor',
      );
      setState(() => _loading = false);
      await _openVideoAt(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  void _startEegTicker() {
    _eegTimer?.cancel();
    _eegTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;
      await context.read<ExperimentProvider>().tickCapture();
    });
  }

  void _startUiTicker() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _sessionStartedAt == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_sessionStartedAt!);
      });
    });
  }

  void _startExperimentCountdown() {
    _experimentTimer?.cancel();
    _experimentTimer = Timer(
      VideoReelsExperimentScreen.experimentDuration,
      () {
        if (mounted) _goToReading();
      },
    );
  }

  Future<void> _openVideoAt(int index, {int attempt = 0}) async {
    final feed = _feed;
    if (feed == null || _videos.isEmpty) return;

    if (attempt >= feed.sourceCount) {
      AppLogger.instance.error(
        'Reels: hiçbir video açılamadı (${feed.sourceCount} deneme)',
      );
      if (!mounted) return;
      setState(() {
        _loadError =
            'Videolar açılamadı. Bağlantıyı ve Firebase Storage URL\'lerini kontrol edin.';
      });
      return;
    }

    feed.ensureCapacity(index + feed.sourceCount + 1);

    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final video = feed.at(index);
    final url = video.storageUrl.trim();
    if (url.isEmpty) {
      await _openVideoAt(index + 1, attempt: attempt + 1);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      AppLogger.instance.experiment(
        'Reels video oynuyor: ${video.title} (${video.videoId})',
      );

      setState(() {
        _controller = controller;
        _currentIndex = index;
        _videoStartedAt = DateTime.now();
        _loadError = null;
      });

      if (_pageController.hasClients &&
          _pageController.page?.round() != index) {
        _pageController.jumpToPage(index);
      }
    } catch (e, st) {
      await controller.dispose();
      AppLogger.instance.error(
        'Reels video açılamadı: ${video.title}',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      await _openVideoAt(index + 1, attempt: attempt + 1);
    }
  }

  Future<void> _recordCurrentWatch({required DateTime transitionTime}) async {
    final feed = _feed;
    if (feed == null || feed.feed.isEmpty) return;
    final video = feed.at(_currentIndex);
    final start = _videoStartedAt ?? transitionTime;
    final end = transitionTime;
    final watchedSec = end.difference(start).inSeconds;
    final durationSec = video.duration > 0
        ? video.duration
        : (_controller?.value.duration.inSeconds ?? 0);
    final percent = durationSec <= 0
        ? 0.0
        : (watchedSec / durationSec * 100).clamp(0, 100).toDouble();

    await context.read<ExperimentProvider>().saveWatchEvent(
          videoId: video.videoId,
          startTime: start,
          endTime: end,
          watchDurationSeconds: watchedSec,
          percentWatched: percent,
          transitionTime: transitionTime,
          category: video.category,
        );
  }

  Future<void> _onPageChanged(int index) async {
    if (index == _currentIndex) return;
    final now = DateTime.now();
    unawaited(_recordCurrentWatch(transitionTime: now));
    await _openVideoAt(index);
  }

  Future<void> _goToReading() async {
    if (_transitioning) return;
    _transitioning = true;
    _experimentTimer?.cancel();

    final now = DateTime.now();
    await _recordCurrentWatch(transitionTime: now);

    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;

    if (!mounted) return;

    // EEG timer sonraki ekrana taşınır; collection/buffer kesilmez.
    _eegTimer?.cancel();
    _uiTimer?.cancel();

    if (widget.returnToFlowOnComplete) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final provider = context.read<ExperimentProvider>();
    provider.enterReadingPhase();

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ReadingExperimentScreen(
          continueExistingSession: true,
        ),
      ),
    );
  }

  String _formatRemaining() {
    final total = VideoReelsExperimentScreen.experimentDuration;
    final left = total - _elapsed;
    final safe = left.isNegative ? Duration.zero : left;
    final m = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sampleCount = context.watch<ExperimentProvider>().sampleCount;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Video Deneyi'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
            // 10 dk boyunca ileri kaydırma: tur tur rastgele feed.
            itemBuilder: (context, index) {
              final feed = _feed!;
              feed.ensureCapacity(index + 1);
              final isActive = index == _currentIndex;
              return _ReelPage(
                controller: isActive ? _controller : null,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Kalan ${_formatRemaining()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'EEG $sampleCount',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 48,
            child: Column(
              children: [
                const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                Text(
                  '${(_currentIndex % (_feed?.sourceCount ?? 1)) + 1}/${_feed?.sourceCount ?? 0}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    required this.controller,
  });

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          // IgnorePointer: VideoPlayer dokunmayı yutmaz; dikey kaydırma PageView'a geçer.
          // VideoPlayer varsayılan olarak kontrol çubuğu göstermez (pause/seek yok).
          child: controller != null && controller!.value.isInitialized
              ? IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
