import 'dart:async';
import 'dart:math' as math;

import 'package:video_player/video_player.dart';

import '../core/app_logger.dart';
import '../utils/video_controller_factory.dart';
import 'video_feed_scheduler.dart';

/// Reels bilgilendirme sırasında sabit sıradaki ilk videoları initialize eder.
/// Reels ekranı açılınca ağ yok — asset'ten hazır controller ile başlar.
class ReelsWarmupBundle {
  ReelsWarmupBundle({
    required this.feed,
    required this.controllers,
  });

  final VideoFeedScheduler feed;
  final Map<int, VideoPlayerController> controllers;

  Future<void> disposeControllers() async {
    final list = List<VideoPlayerController>.from(controllers.values);
    controllers.clear();
    for (final c in list) {
      try {
        await c.dispose();
      } catch (_) {}
    }
  }
}

class ReelsWarmup {
  /// Aktif + sıradaki (OOM sınırı ile uyumlu).
  static const preloadCount = 2;

  ReelsWarmupBundle? _bundle;
  Future<ReelsWarmupBundle?>? _inFlight;

  bool get hasBundle => _bundle != null;

  Future<void> prepare(VideoFeedScheduler playlist) async {
    await ensureReady(playlist);
  }

  /// Briefing sırasında çağrılır; kilitli sıradaki ilk videoları hazırlar.
  Future<ReelsWarmupBundle?> ensureReady(VideoFeedScheduler playlist) {
    final existing = _bundle;
    if (existing != null) return Future.value(existing);

    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _build(playlist);
    _inFlight = future;
    return future;
  }

  Future<ReelsWarmupBundle?> _build(VideoFeedScheduler playlist) async {
    if (playlist.sourceCount == 0) {
      _inFlight = null;
      return null;
    }

    final count = math.min(preloadCount, playlist.sourceCount);
    playlist.ensureCapacity(count);

    final controllers = <int, VideoPlayerController>{};
    for (var i = 0; i < count; i++) {
      final url = playlist.at(i).storageUrl.trim();
      if (url.isEmpty) continue;
      try {
        final controller = createVideoController(url);
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        await controller.pause();
        controllers[i] = controller;
      } catch (e, st) {
        AppLogger.instance.error(
          'Reels warmup başarısız: ${playlist.at(i).title}',
          error: e,
          stackTrace: st,
        );
      }
    }

    final bundle = ReelsWarmupBundle(
      feed: playlist,
      controllers: controllers,
    );
    _bundle = bundle;
    _inFlight = null;

    AppLogger.instance.experiment(
      'Reels warmup hazır: ${controllers.length}/$count asset '
      '(sıra: ${playlist.firstRoundIds.take(5).join(" → ")}…)',
    );
    return bundle;
  }

  /// Reels ekranı sahipliği alır; warmup bir daha dispose etmez.
  ReelsWarmupBundle? take() {
    final bundle = _bundle;
    _bundle = null;
    _inFlight = null;
    return bundle;
  }

  Future<void> discard() async {
    final pending = _inFlight;
    _inFlight = null;
    if (pending != null) {
      try {
        final built = await pending;
        await built?.disposeControllers();
      } catch (_) {}
    }
    final bundle = _bundle;
    _bundle = null;
    await bundle?.disposeControllers();
  }
}
