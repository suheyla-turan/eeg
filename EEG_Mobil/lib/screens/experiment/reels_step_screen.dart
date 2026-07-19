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
import '../../widgets/demo_skip_button.dart';

/// Instagram Reels mantığında 10 dakikalık video deneyi.
class ReelsStepScreen extends StatefulWidget {
  const ReelsStepScreen({super.key});

  @override
  State<ReelsStepScreen> createState() => _ReelsStepScreenState();
}

class _ReelsStepScreenState extends State<ReelsStepScreen> {
  final _pageController = PageController();

  /// Aktif + komşu videolar (geri/ileri anında geçiş için).
  final Map<int, VideoPlayerController> _controllers = {};

  Timer? _experimentTimer;
  Timer? _uiTimer;

  List<VideoContent> _videos = [];
  VideoFeedScheduler? _feed;
  int _currentIndex = 0;
  bool _loading = true;
  String? _loadError;
  bool _finishing = false;
  bool _cancelling = false;

  DateTime? _sessionStartedAt;
  Duration _elapsed = Duration.zero;

  DateTime? _videoStartedAt;
  int _replayCount = 0;
  Duration _lastPosition = Duration.zero;
  VoidCallback? _positionListener;

  bool _isPlaying = true;
  bool _switching = false;
  int? _pendingIndex;

  VideoPlayerController? get _controller => _controllers[_currentIndex];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
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
      await manager.loadMediaOptions();
      _videos = List<VideoContent>.from(
        manager.videos.where((v) => v.storageUrl.trim().isNotEmpty),
      );

      if (_videos.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = manager.errorMessage ??
              'Oynatılabilir aktif video yok. Videolar ekranında '
                  'yükleme tamamlanmış ve Aktif olan kayıtlar olmalı '
                  '(storageUrl dolu).';
        });
        return;
      }

      _feed = VideoFeedScheduler(_videos);

      _sessionStartedAt = DateTime.now();
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
    final c = _controller;
    final listener = _positionListener;
    if (c != null && listener != null) {
      c.removeListener(listener);
    }
    _positionListener = null;
  }

  Future<VideoPlayerController> _createController(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      return controller;
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  Future<void> _evictFarControllers(int center) async {
    // ±2 komşu tutulur — hızlı ileri/geri kaydırma için.
    final keep = <int>{
      for (var i = center - 2; i <= center + 2; i++) i,
    };
    final toRemove =
        _controllers.keys.where((i) => !keep.contains(i)).toList();
    for (final i in toRemove) {
      final c = _controllers.remove(i);
      await c?.dispose();
    }
  }

  bool _isNearCurrent(int index) => (index - _currentIndex).abs() <= 2;

  Future<void> _ensureCached(int index) async {
    final feed = _feed;
    if (feed == null || index < 0 || !mounted || _finishing) return;
    if (_controllers.containsKey(index) &&
        _controllers[index]!.value.isInitialized) {
      return;
    }

    feed.ensureCapacity(index + 1);
    final video = feed.at(index);
    final url = video.storageUrl.trim();
    if (url.isEmpty) return;

    try {
      final controller = await _createController(url);
      if (!mounted || _finishing || !_isNearCurrent(index)) {
        await controller.dispose();
        return;
      }
      final existing = _controllers[index];
      if (existing != null && existing.value.isInitialized) {
        await controller.dispose();
        return;
      }
      await existing?.dispose();
      _controllers[index] = controller;
      if (mounted) setState(() {});
    } catch (e, st) {
      AppLogger.instance.error(
        'Reels preload başarısız: ${video.title}',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _preloadNeighbors(int index) {
    for (final i in [index - 2, index - 1, index + 1, index + 2]) {
      if (i >= 0) unawaited(_ensureCached(i));
    }
  }

  Future<void> _openVideoAt(int index, {int attempt = 0}) async {
    final feed = _feed;
    if (feed == null || _videos.isEmpty || index < 0 || _finishing) return;

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

    final video = feed.at(index);
    final url = video.storageUrl.trim();
    if (url.isEmpty) {
      final next = index >= _currentIndex ? index + 1 : index - 1;
      if (next < 0) return;
      await _openVideoAt(next, attempt: attempt + 1);
      return;
    }

    VideoPlayerController controller;
    final cached = _controllers[index];
    if (cached != null && cached.value.isInitialized) {
      controller = cached;
    } else {
      try {
        controller = await _createController(url);
        if (!mounted || _finishing) {
          await controller.dispose();
          return;
        }
        // Hızlı kaydırmada hedef değiştiyse bu sonucu at.
        if (_pendingIndex != null && _pendingIndex != index) {
          await controller.dispose();
          return;
        }
        await _controllers[index]?.dispose();
        _controllers[index] = controller;
      } catch (e, st) {
        AppLogger.instance.error(
          'Reels video açılamadı: ${video.title}',
          error: e,
          stackTrace: st,
        );
        if (!mounted) return;
        final next = index >= _currentIndex ? index + 1 : index - 1;
        if (next < 0) return;
        await _openVideoAt(next, attempt: attempt + 1);
        return;
      }
    }

    _detachPositionListener();

    // Eski aktif videoyu duraklat (cache'de kalsın — geri dönüş anında hazır).
    final oldIndex = _currentIndex;
    final old = _controllers[oldIndex];
    if (old != null && old != controller && old.value.isPlaying) {
      unawaited(old.pause());
    }

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

    // Önce UI'ı güncelle, play'i bekletme — geçiş anında takılma olmasın.
    setState(() {
      _currentIndex = index;
      _videoStartedAt = DateTime.now();
      _isPlaying = true;
      _loadError = null;
    });

    unawaited(() async {
      try {
        await controller.play();
      } catch (_) {}
    }());

    AppLogger.instance.experiment(
      'Reels video oynuyor: ${video.title} (${video.videoId})',
    );

    unawaited(_evictFarControllers(index));
    _preloadNeighbors(index);
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
    final replayCount = _replayCount;

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

  Future<void> _onPageChanged(int index) async {
    if (index == _currentIndex && !_switching) return;

    // Hızlı kaydırmada son hedefi işle; ara geçişleri atlama.
    if (_switching) {
      _pendingIndex = index;
      return;
    }

    _switching = true;
    try {
      var target = index;
      while (true) {
        if (target != _currentIndex) {
          unawaited(_recordCurrentWatch(transitionTime: DateTime.now()));
          await _openVideoAt(target);
        }
        if (_pendingIndex == null || _pendingIndex == _currentIndex) {
          _pendingIndex = null;
          break;
        }
        target = _pendingIndex!;
        _pendingIndex = null;
      }
    } finally {
      _switching = false;
    }
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
    await _recordCurrentWatch(transitionTime: now);
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
    _experimentTimer?.cancel();
    _uiTimer?.cancel();

    final now = DateTime.now();
    await _recordCurrentWatch(transitionTime: now);
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
    final sampleCount = context.watch<ExperimentProvider>().sampleCount;
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
              allowImplicitScrolling: true,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final feed = _feed!;
                feed.ensureCapacity(index + 1);
                final pageController = _controllers[index];
                return _ReelPage(
                  controller: pageController,
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
                    _Chip(text: 'EEG $sampleCount'),
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

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    required this.controller,
    required this.isPlaying,
    required this.onTap,
  });

  final VideoPlayerController? controller;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: controller != null && controller!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (!isPlaying)
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
