import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/app_page_route.dart';
import '../models/video_content.dart';
import '../providers/video_content_provider.dart';
import '../theme/app_colors.dart';
import '../utils/video_controller_factory.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/loading_view.dart';
import 'video_player_screen.dart';

/// Yerel asset videolarını listeler (ekleme/silme yok).
class VideosScreen extends StatefulWidget {
  const VideosScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoContentProvider>().loadAll();
    });
  }

  void _openPlayer(VideoContent video) {
    final path = video.storageUrl.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu videonun asset yolu tanımlı değil'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      AppPageRoute<void>(
        transition: AppTransition.fadeThrough,
        builder: (_) => VideoPlayerScreen(
          title: video.title,
          url: path,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoContentProvider>();

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(
              title: const Text('Videolar'),
            ),
      body: provider.loading
          ? const LoadingView(message: 'Videolar yükleniyor…')
          : provider.errorMessage != null && provider.videos.isEmpty
              ? EmptyStateView(
                  title: 'Videolar yüklenemedi',
                  subtitle: provider.errorMessage,
                  icon: Icons.error_outline,
                  actionLabel: 'Tekrar Dene',
                  onAction: () =>
                      context.read<VideoContentProvider>().loadAll(),
                )
              : provider.videos.isEmpty
                  ? const EmptyStateView(
                      title: 'Yerel video yok',
                      subtitle:
                          'assets/videos/ klasörüne mp4 ekleyip '
                          'lib/data/local_videos.dart listesini güncelleyin.',
                      icon: Icons.videocam_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: provider.videos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final v = provider.videos[index];
                        return _VideoListTile(
                          video: v,
                          onPlay: () => _openPlayer(v),
                        );
                      },
                    ),
    );
  }
}

class _VideoListTile extends StatelessWidget {
  const _VideoListTile({
    required this.video,
    required this.onPlay,
  });

  final VideoContent video;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _VideoPreview(path: video.storageUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.storageUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.path});

  final String path;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path.trim();
    if (path.isEmpty) {
      setState(() => _failed = true);
      return;
    }

    final controller = createVideoController(path);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.pause();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      await controller.dispose();
      if (_controller == controller) _controller = null;
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: Colors.white.withValues(alpha: 0.55),
            size: 40,
          ),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return const ColoredBox(
        color: Colors.black87,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
        const ColoredBox(color: Color(0x33000000)),
        const Center(
          child: Icon(
            Icons.play_circle_filled_rounded,
            color: Colors.white,
            size: 52,
          ),
        ),
      ],
    );
  }
}
