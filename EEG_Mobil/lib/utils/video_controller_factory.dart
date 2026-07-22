import 'package:video_player/video_player.dart';

/// [source] asset yolu (`assets/...`) veya http(s) URL olabilir.
VideoPlayerController createVideoController(
  String source, {
  VideoPlayerOptions? videoPlayerOptions,
}) {
  final trimmed = source.trim();
  if (trimmed.startsWith('assets/')) {
    return VideoPlayerController.asset(
      trimmed,
      videoPlayerOptions: videoPlayerOptions,
    );
  }
  return VideoPlayerController.networkUrl(
    Uri.parse(trimmed),
    videoPlayerOptions: videoPlayerOptions,
  );
}
