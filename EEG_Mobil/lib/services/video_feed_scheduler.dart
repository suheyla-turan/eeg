import 'dart:math';

import '../models/video_content.dart';

/// 10 dk reels için tur bazlı rastgele video sırası.
///
/// - Deney başında [VideoFeedScheduler.forExperiment] ile sıra kilitlenir.
/// - Her turda tüm videolar tam olarak bir kez görünür.
/// - Bir sonraki tur, bir önceki turdan farklı sıradadır.
/// - Otomatik geçiş yok; sıradaki video yalnızca kullanıcı kaydırınca açılır.
class VideoFeedScheduler {
  VideoFeedScheduler(List<VideoContent> source, {Random? random})
      : _source = List<VideoContent>.from(source),
        _random = random ?? Random() {
    if (_source.isNotEmpty) {
      _appendRound();
    }
  }

  /// Deney oturumu için sıra: ilk turlar önceden üretilir, sıra sabittir.
  factory VideoFeedScheduler.forExperiment(
    List<VideoContent> source, {
    int prebuildRounds = 3,
    Random? random,
  }) {
    final playable = source
        .where((v) => v.storageUrl.trim().isNotEmpty)
        .toList(growable: false);
    final feed = VideoFeedScheduler(playable, random: random);
    if (playable.isNotEmpty) {
      final target = playable.length * prebuildRounds.clamp(1, 10);
      feed.ensureCapacity(target);
    }
    return feed;
  }

  final List<VideoContent> _source;
  final Random _random;
  final List<VideoContent> feed = [];
  List<String>? _lastRoundIds;

  int get sourceCount => _source.length;

  /// İlk turun video id sırası (log / debug).
  List<String> get firstRoundIds {
    if (_source.isEmpty) return const [];
    final n = _source.length;
    return feed.take(n).map((v) => v.videoId).toList(growable: false);
  }

  VideoContent at(int index) {
    ensureCapacity(index + 1);
    return feed[index];
  }

  void ensureCapacity(int minLength) {
    if (_source.isEmpty) return;
    while (feed.length < minLength) {
      _appendRound();
    }
  }

  void _appendRound() {
    if (_source.isEmpty) return;

    if (_source.length == 1) {
      feed.add(_source.first);
      _lastRoundIds = [_source.first.videoId];
      return;
    }

    final round = List<VideoContent>.from(_source)..shuffle(_random);
    var attempts = 0;
    while (_lastRoundIds != null &&
        _sameOrder(round, _lastRoundIds!) &&
        attempts < 40) {
      round.shuffle(_random);
      attempts++;
    }

    if (_lastRoundIds != null && _sameOrder(round, _lastRoundIds!)) {
      // Nadir durum: shuffle aynı kaldıysa ilk iki öğeyi yer değiştir.
      final tmp = round[0];
      round[0] = round[1];
      round[1] = tmp;
    }

    _lastRoundIds = round.map((v) => v.videoId).toList(growable: false);
    feed.addAll(round);
  }

  bool _sameOrder(List<VideoContent> round, List<String> previousIds) {
    if (round.length != previousIds.length) return false;
    for (var i = 0; i < round.length; i++) {
      if (round[i].videoId != previousIds[i]) return false;
    }
    return true;
  }
}
