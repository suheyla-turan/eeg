import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_logger.dart';
import '../../models/video_content.dart';
import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../services/video_feed_scheduler.dart';
import '../../theme/app_colors.dart';
import '../../utils/video_controller_factory.dart';
import '../../widgets/demo_skip_button.dart';

/// Instagram Reels mantığında 10 dakikalık video deneyi.
class ReelsStepScreen extends StatefulWidget {
  const ReelsStepScreen({super.key});

  @override
  State<ReelsStepScreen> createState() => _ReelsStepScreenState();
}

class _ReelsStepScreenState extends State<ReelsStepScreen> {
  final _pageController = PageController();

  /// En fazla aktif + sonraki 1 (ExoPlayer OOM önlemi).
  static const _keepAhead = 1;
  static const _keepBehind = 0;

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _loadingIndexes = {};

  /// Aynı anda tek initialize — MediaCodec tükenmesin.
  Future<void> _createGate = Future<void>.value();

  Timer? _experimentTimer;
  Timer? _uiTimer;

  List<VideoContent> _videos = [];
  VideoFeedScheduler? _feed;
  int _currentIndex = 0;
  bool _loading = true;
  String? _loadError;
  bool _finishing = false;
  bool _cancelling = false;

  /// Hızlı kaydırmada eski initialize sonuçlarını iptal etmek için.
  int _activateGen = 0;

  DateTime? _sessionStartedAt;
  Duration _elapsed = Duration.zero;

  DateTime? _videoStartedAt;
  int _replayCount = 0;
  Duration _lastPosition = Duration.zero;
  VoidCallback? _positionListener;
  VideoPlayerController? _listeningController;

  bool _isPlaying = true;

  VideoPlayerController? get _controller => _controllers[_currentIndex];

  Set<int> _keepSet(int center) => {
        center,
        for (var i = 1; i <= _keepAhead; i++) center + i,
        for (var i = 1; i <= _keepBehind; i++)
          if (center - i >= 0) center - i,
      };

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _activateGen++;
    _experimentTimer?.cancel();
    _uiTimer?.cancel();
    _detachPositionListener();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final provider = context.read<ExperimentProvider>();
    final manager = provider.manager;

    try {
      final warmup = manager.takeReelsWarmup();
      if (warmup != null) {
        _feed = warmup.feed;
        _videos = List<VideoContent>.from(
          warmup.feed.feed.take(warmup.feed.sourceCount),
        );
        // Warmup'tan gelen hazır asset controller'ları al (max aktif+1).
        for (final entry in warmup.controllers.entries) {
          if (entry.key <= 1) {
            _controllers[entry.key] = entry.value;
          } else {
            unawaited(entry.value.dispose());
          }
        }
      } else {
        await manager.loadMediaOptions();
        // Playlist yoksa (nadir) burada kilitle.
        final playlist = manager.reelsPlaylist ??
            VideoFeedScheduler.forExperiment(manager.videos);
        manager.reelsPlaylist ??= playlist;
        _feed = playlist;
        _videos = List<VideoContent>.from(
          manager.videos.where((v) => v.storageUrl.trim().isNotEmpty),
        );
      }

      if (_videos.isEmpty && (_feed?.sourceCount ?? 0) == 0) {
        setState(() {
          _loading = false;
          _loadError = manager.errorMessage ??
              'Oynatılabilir video yok. assets/videos/ altına mp4 koyup '
                  'lib/data/local_videos.dart listesini güncelleyin.';
        });
        return;
      }

      _feed ??= VideoFeedScheduler.forExperiment(_videos);

      final firstReady = _controllers[0]?.value.isInitialized == true;

      _sessionStartedAt = DateTime.now();
      _startExperimentCountdown();
      _startUiTicker();

      AppLogger.instance.experiment(
        'Reels: ${_feed!.sourceCount} lokal video, sıra sabit'
        '${firstReady ? " — anında başlıyor" : ""}',
      );

      // Briefing'de initialize edildiyse yükleme ekranı gösterme.
      setState(() => _loading = false);
      await _activateVideo(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
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
    _experimentTimer = Timer(ExperimentManager.reelsDuration, () {
      if (mounted) _finishReels();
    });
  }

  void _detachPositionListener() {
    final c = _listeningController;
    final listener = _positionListener;
    if (c != null && listener != null) {
      c.removeListener(listener);
    }
    _positionListener = null;
    _listeningController = null;
  }

  Future<VideoPlayerController> _createController(String url) {
    final previous = _createGate;
    final done = Completer<void>();
    _createGate = done.future;

    return () async {
      try {
        await previous;
      } catch (_) {}
      final controller = createVideoController(
        url,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        await controller.pause();
        return controller;
      } catch (e) {
        try {
          await controller.dispose();
        } catch (_) {}
        rethrow;
      } finally {
        if (!done.isCompleted) done.complete();
      }
    }();
  }

  Future<void> _disposeController(VideoPlayerController? c) async {
    if (c == null) return;
    if (identical(c, _listeningController)) {
      _detachPositionListener();
    }
    try {
      await c.pause();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  /// Uzak controller'ları önce serbest bırak (yeni initialize öncesi zorunlu).
  Future<void> _evictFarControllers(int center) async {
    final keep = _keepSet(center);
    final toRemove =
        _controllers.keys.where((i) => !keep.contains(i)).toList();
    for (final i in toRemove) {
      final c = _controllers.remove(i);
      await _disposeController(c);
    }
  }

  bool _isNearCurrent(int index) => _keepSet(_currentIndex).contains(index);

  Future<void> _ensureCached(int index) async {
    final feed = _feed;
    if (feed == null || index < 0 || !mounted || _finishing) return;
    if (_controllers[index]?.value.isInitialized == true) return;
    if (_loadingIndexes.contains(index)) return;
    if (!_isNearCurrent(index)) return;

    feed.ensureCapacity(index + 1);
    final video = feed.at(index);
    final url = video.storageUrl.trim();
    if (url.isEmpty) return;

    _loadingIndexes.add(index);
    try {
      // Yeni decode öncesi eski ExoPlayer'ları kapat.
      await _evictFarControllers(_currentIndex);
      if (!mounted || _finishing || !_isNearCurrent(index)) return;
      if (_controllers[index]?.value.isInitialized == true) return;

      final controller = await _createController(url);
      if (!mounted || _finishing || !_isNearCurrent(index)) {
        await _disposeController(controller);
        return;
      }
      final existing = _controllers[index];
      if (existing != null && existing.value.isInitialized) {
        await _disposeController(controller);
        return;
      }
      await _disposeController(existing);
      _controllers[index] = controller;
      if (mounted && index == _currentIndex) setState(() {});
    } catch (e, st) {
      AppLogger.instance.error(
        'Reels preload başarısız: ${video.title}',
        error: e,
        stackTrace: st,
      );
    } finally {
      _loadingIndexes.remove(index);
    }
  }

  void _preloadNeighbors(int index) {
    // Yalnızca bir sonraki — Instagram hızlı swipe için yeterli, OOM riski düşük.
    final next = index + 1;
    if (next >= 0) unawaited(_ensureCached(next));
  }

  void _attachPositionListener(VideoPlayerController controller) {
    _detachPositionListener();
    _replayCount = 0;
    _lastPosition = Duration.zero;
    _positionListener = () {
      if (!controller.value.isInitialized) return;
      final pos = controller.value.position;
      if (_lastPosition > const Duration(seconds: 1) &&
          pos < const Duration(milliseconds: 400)) {
        _replayCount++;
      }
      _lastPosition = pos;
    };
    controller.addListener(_positionListener!);
    _listeningController = controller;
  }

  Future<void> _silence(VideoPlayerController? c) async {
    if (c == null) return;
    try {
      await c.setVolume(0);
    } catch (_) {}
    try {
      await c.pause();
    } catch (_) {}
  }

  /// Instagram tarzı: hedef sayfayı hemen aktif et, yükleme arka planda.
  Future<void> _activateVideo(
    int index, {
    int attempt = 0,
    int? generation,
  }) async {
    final feed = _feed;
    if (feed == null || _videos.isEmpty || index < 0 || _finishing) return;

    final gen = generation ?? ++_activateGen;

    if (attempt >= feed.sourceCount) {
      AppLogger.instance.error(
        'Reels: hiçbir video açılamadı (${feed.sourceCount} deneme)',
      );
      if (!mounted || gen != _activateGen) return;
      setState(() {
        _loadError =
            'Videolar açılamadı. assets/videos/ dosyalarını ve '
                'lib/data/local_videos.dart listesini kontrol edin.';
      });
      return;
    }

    feed.ensureCapacity(index + feed.sourceCount + 1);
    final video = feed.at(index);
    final url = video.storageUrl.trim();
    if (url.isEmpty) {
      await _activateVideo(index + 1, attempt: attempt + 1, generation: gen);
      return;
    }

    // Eski aktif videoyu hemen sustur.
    final oldIndex = _currentIndex;
    if (oldIndex != index) {
      unawaited(_silence(_controllers[oldIndex]));
    }

    if (mounted && gen == _activateGen) {
      setState(() {
        _currentIndex = index;
        _videoStartedAt = DateTime.now();
        _isPlaying = true;
        _loadError = null;
      });
    }

    // Yeni decode'dan önce uzak player'ları kapat (OOM'un ana önlemi).
    await _evictFarControllers(index);
    if (gen != _activateGen || !mounted || _finishing) return;

    VideoPlayerController? controller = _controllers[index];
    if (controller == null || !controller.value.isInitialized) {
      try {
        controller = await _createController(url);
        if (!mounted || _finishing || gen != _activateGen) {
          await _disposeController(controller);
          return;
        }
        await _disposeController(_controllers[index]);
        _controllers[index] = controller;
        if (mounted) setState(() {});
      } catch (e, st) {
        AppLogger.instance.error(
          'Reels video açılamadı: ${video.title}',
          error: e,
          stackTrace: st,
        );
        if (!mounted || gen != _activateGen) return;
        await _activateVideo(index + 1, attempt: attempt + 1, generation: gen);
        return;
      }
    }

    if (gen != _activateGen || !mounted) return;

    _attachPositionListener(controller);

    try {
      await controller.setVolume(1);
    } catch (_) {}
    try {
      await controller.seekTo(Duration.zero);
    } catch (_) {}
    try {
      await controller.play();
    } catch (_) {}

    if (!mounted || gen != _activateGen) return;
    setState(() => _isPlaying = true);

    AppLogger.instance.experiment(
      'Reels video oynuyor: ${video.title} (${video.videoId})',
    );

    _preloadNeighbors(index);
  }

  Future<void> _recordWatchForIndex(
    int index, {
    required DateTime transitionTime,
    DateTime? startedAt,
    int replayCount = 0,
  }) async {
    final feed = _feed;
    if (feed == null || feed.feed.isEmpty || index < 0) return;
    feed.ensureCapacity(index + 1);
    final video = feed.at(index);
    final start = startedAt ?? transitionTime;
    final end = transitionTime;
    final watchedSec = end.difference(start).inSeconds;
    final ctrl = _controllers[index];
    final durationSec = video.duration > 0
        ? video.duration
        : (ctrl?.value.duration.inSeconds ?? 0);
    final percent = durationSec <= 0
        ? 0.0
        : (watchedSec / durationSec * 100).clamp(0, 100).toDouble();

    await context.read<ExperimentProvider>().manager.saveWatchEvent(
          videoId: video.videoId,
          startTime: start,
          endTime: end,
          watchDurationSeconds: watchedSec,
          percentWatched: percent,
          replayCount: replayCount,
          transitionTime: transitionTime,
          category: video.category,
        );
  }

  /// PageView kaydırması asla bekletilmez — ardışık swipe Instagram gibi akar.
  void _onPageChanged(int index) {
    if (_finishing || index == _currentIndex) return;

    final from = _currentIndex;
    final startedAt = _videoStartedAt;
    final replayCount = _replayCount;
    final now = DateTime.now();

    // Önce yeni videoyu aç; watch kaydı arka planda (yarış olmasın diye
    // startedAt/replay anlık kopyalandı).
    unawaited(_activateVideo(index));
    unawaited(
      _recordWatchForIndex(
        from,
        transitionTime: now,
        startedAt: startedAt,
        replayCount: replayCount,
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
      setState(() => _isPlaying = false);
    } else {
      await c.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _finishReels() async {
    if (_finishing) return;
    _finishing = true;
    _activateGen++;
    _experimentTimer?.cancel();
    _uiTimer?.cancel();

    _detachPositionListener();

    // VideoPlayer hâlâ ağaçtayken dispose edilirse
    // "used after being disposed" hatası oluşur. Önce referansları
    // kopar, bir frame bekle, sonra dispose et.
    final controllers = List<VideoPlayerController>.from(_controllers.values);
    _controllers.clear();
    if (mounted) setState(() {});

    final now = DateTime.now();
    await _recordWatchForIndex(
      _currentIndex,
      transitionTime: now,
      startedAt: _videoStartedAt,
      replayCount: _replayCount,
    );
    await WidgetsBinding.instance.endOfFrame;

    for (final c in controllers) {
      try {
        await c.pause();
      } catch (_) {}
      await c.dispose();
    }

    if (!mounted) return;
    context.read<ExperimentProvider>().manager.onReelsFinished();
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Deneyi Durdur'),
        content: const Text(
          'Deneyi sonlandırmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final manager = context.read<ExperimentProvider>().manager;
    setState(() => _cancelling = true);
    _activateGen++;
    _experimentTimer?.cancel();
    _uiTimer?.cancel();

    final now = DateTime.now();
    await _recordWatchForIndex(
      _currentIndex,
      transitionTime: now,
      startedAt: _videoStartedAt,
      replayCount: _replayCount,
    );
    await _controller?.pause();

    final ok = await manager.cancelExperiment();
    if (!mounted) return;
    if (!ok) {
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(manager.errorMessage ?? 'İptal başarısız'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _formatRemaining() {
    final total = ExperimentManager.reelsDuration;
    final left = total - _elapsed;
    final safe = left.isNegative ? Duration.zero : left;
    final m = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.viewPaddingOf(context).top;

    if (_loading || _cancelling || _finishing) {
      return const PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (_loadError != null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context
                        .read<ExperimentProvider>()
                        .manager
                        .onReelsFinished(),
                    child: const Text('Metin Aşamasına Geç'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              // false: komşu sayfada Texture/MediaCodec tutma (OOM).
              allowImplicitScrolling: false,
              physics: const _ReelsScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final feed = _feed!;
                feed.ensureCapacity(index + 1);
                final near = (index - _currentIndex).abs() <= 1;
                final pageController = near ? _controllers[index] : null;
                return _ReelPage(
                  key: ValueKey<int>(index),
                  controller: pageController,
                  isActive: index == _currentIndex,
                  isPlaying: index == _currentIndex && _isPlaying,
                  onTap: _togglePlayPause,
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 0),
                child: Row(
                  children: [
                    _Chip(text: _formatRemaining()),
                    const SizedBox(width: 8),
                    // EEG sayacı PageView'ı her 500ms rebuild etmesin.
                    Selector<ExperimentProvider, int>(
                      selector: (_, p) => p.sampleCount,
                      builder: (_, count, __) => _Chip(text: 'EEG $count'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _confirmCancel,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Deneyi Durdur',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: DemoSkipButton(
                label: 'Videoyu Geç',
                onPressed: _finishing ? null : _finishReels,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Instagram Reels benzeri hızlı dikey kaydırma.
class _ReelsScrollPhysics extends PageScrollPhysics {
  const _ReelsScrollPhysics({super.parent});

  @override
  _ReelsScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ReelsScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.4,
        stiffness: 350,
        damping: 28,
      );
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    super.key,
    required this.controller,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
  });

  final VideoPlayerController? controller;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = controller != null && controller!.value.isInitialized;

    return GestureDetector(
      onTap: isActive ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: ready
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  )
                : const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white54,
                      ),
                    ),
                  ),
          ),
          if (isActive && !isPlaying && ready)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 72,
              ),
            ),
        ],
      ),
    );
  }
}
