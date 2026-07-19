import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/video_content.dart';
import '../../providers/experiment_provider.dart';
import '../../services/experiment_manager.dart';
import '../../services/video_feed_scheduler.dart';
import '../../theme/app_colors.dart';
import '../../widgets/forward_only_scroll_physics.dart';

/// Instagram Reels mantığında 10 dakikalık video deneyi.
class ReelsStepScreen extends StatefulWidget {
  const ReelsStepScreen({super.key});

  @override
  State<ReelsStepScreen> createState() => _ReelsStepScreenState();
}

class _ReelsStepScreenState extends State<ReelsStepScreen> {
  final _pageController = PageController();

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

  VideoPlayerController? _controller;
  bool _isPlaying = true;

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
    _controller?.dispose();
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
        manager.videos.where((v) => v.storageUrl.isNotEmpty),
      );

      if (_videos.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = 'Aktif video bulunamadı. Önce CMS\'den video ekleyin.';
        });
        return;
      }

      // Tur 1: rastgele sıra. Sonraki turlar kullanıcı tüm videoları bitirince eklenir.
      _feed = VideoFeedScheduler(_videos);

      _sessionStartedAt = DateTime.now();
      _startExperimentCountdown();
      _startUiTicker();

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

  Future<void> _openVideoAt(int index) async {
    final feed = _feed;
    if (feed == null || _videos.isEmpty) return;

    // Sonraki tur(lar) için kapasite: kullanıcı kaydırmadan önce hazır olsun.
    feed.ensureCapacity(index + feed.sourceCount + 1);

    _detachPositionListener();
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final video = feed.at(index);
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(video.storageUrl),
    );

    try {
      await controller.initialize();
      // Kullanıcı kaydırmadan otomatik geçiş yok — video kendi içinde döner.
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();

      _replayCount = 0;
      _lastPosition = Duration.zero;
      _positionListener = () {
        if (!controller.value.isInitialized) return;
        final pos = controller.value.position;
        // Loop algılama: pozisyon ani olarak başa döner.
        // Bu yalnızca istatistik içindir; sonraki videoya geçirmez.
        if (_lastPosition > const Duration(seconds: 1) &&
            pos < const Duration(milliseconds: 400)) {
          _replayCount++;
        }
        _lastPosition = pos;
      };
      controller.addListener(_positionListener!);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _currentIndex = index;
        _videoStartedAt = DateTime.now();
        _isPlaying = true;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      await _openVideoAt(index + 1);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index + 1);
      }
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

    await context.read<ExperimentProvider>().manager.saveWatchEvent(
          videoId: video.videoId,
          startTime: start,
          endTime: end,
          watchDurationSeconds: watchedSec,
          percentWatched: percent,
          replayCount: _replayCount,
          transitionTime: transitionTime,
          category: video.category,
        );
  }

  Future<void> _onPageChanged(int index) async {
    if (index <= _currentIndex) {
      // Geriye dönüş yok; sıra ileri (rastgele feed) üzerinden ilerler.
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
      return;
    }
    final now = DateTime.now();
    await _recordCurrentWatch(transitionTime: now);
    await _openVideoAt(index);
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

    final now = DateTime.now();
    await _recordCurrentWatch(transitionTime: now);

    await _controller?.pause();
    _detachPositionListener();
    await _controller?.dispose();
    _controller = null;

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

    if (_loading || _cancelling) {
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
              physics: const ForwardOnlyScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final feed = _feed!;
                feed.ensureCapacity(index + 1);
                final video = feed.at(index);
                final isActive = index == _currentIndex;
                return _ReelPage(
                  video: video,
                  controller: isActive ? _controller : null,
                  isPlaying: _isPlaying,
                  onTap: _togglePlayPause,
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
    required this.video,
    required this.controller,
    required this.isPlaying,
    required this.onTap,
  });

  final VideoContent video;
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
                      // Seek kontrolü yok — yalnızca VideoPlayer yüzeyi.
                      child: VideoPlayer(controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
          if (!isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 72,
              ),
            ),
          Positioned(
            left: 16,
            right: 72,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (video.category.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      video.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Text(
                  video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
