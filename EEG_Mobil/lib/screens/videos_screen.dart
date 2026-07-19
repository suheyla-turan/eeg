import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/app_page_route.dart';
import '../models/video_content.dart';
import '../providers/video_content_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/loading_view.dart';
import 'video_player_screen.dart';

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
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoContentProvider>().loadAll();
    });
  }

  void _openPlayer(VideoContent video) {
    final url = video.storageUrl.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu videonun dosyası henüz yüklenmemiş'),
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
          url: url,
        ),
      ),
    );
  }

  Future<void> _rename(VideoContent video) async {
    final controller = TextEditingController(text: video.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('İsim değiştir'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Video adı',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null || !mounted) return;
    if (next.isEmpty || next == video.title) return;

    final provider = context.read<VideoContentProvider>();
    final ok = await provider.rename(video.videoId, next);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'İsim değiştirilemedi'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete(VideoContent video) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Videoyu sil'),
        content: Text('"${video.title}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<VideoContentProvider>();
    final success = await provider.delete(video.videoId);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Silinemedi'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _pickAndUploadVideos() async {
    final provider = context.read<VideoContentProvider>();
    if (provider.saving) return;

    final picked = await _picker.pickMultiVideo();
    if (picked.isEmpty || !mounted) return;

    final files = picked.map((x) => File(x.path)).toList();
    final progress = ValueNotifier<({int current, int total})>(
      (current: 0, total: files.length),
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: ValueListenableBuilder<({int current, int total})>(
              valueListenable: progress,
              builder: (_, value, __) {
                final current = value.current.clamp(0, value.total);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      current == 0
                          ? '${value.total} video hazırlanıyor…'
                          : '$current / ${value.total} yükleniyor…',
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    final result = await provider.createManyFromFiles(
      files,
      onProgress: (current, total) {
        progress.value = (current: current, total: total);
      },
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();

    final messenger = ScaffoldMessenger.of(context);
    if (result.uploaded > 0 && result.failed == 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('${result.uploaded} video yüklendi')),
      );
    } else if (result.uploaded > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${result.uploaded} yüklendi, ${result.failed} başarısız',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Videolar yüklenemedi'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoContentProvider>();

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(
              title: const Text('Videolar'),
              actions: [
                IconButton(
                  onPressed: provider.loading ? null : provider.loadAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.saving ? null : _pickAndUploadVideos,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Video Yükle'),
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
                      title: 'Henüz video yok',
                      subtitle:
                          'İstediğin kadar videoyu tek seferde seçip yükleyebilirsin.',
                      icon: Icons.videocam_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: provider.videos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final v = provider.videos[index];
                        return _VideoListTile(
                          video: v,
                          onPlay: () => _openPlayer(v),
                          onRename: () => _rename(v),
                          onDelete: () => _confirmDelete(v),
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
    required this.onRename,
    required this.onDelete,
  });

  final VideoContent video;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
              child: _VideoPreview(url: video.storageUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'İşlemler',
                    icon: Icon(
                      Icons.more_vert,
                      color: scheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.drive_file_rename_outline),
                          title: Text('İsim değiştir'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Sil'),
                        ),
                      ),
                    ],
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

/// Liste önizlemesi: ilk kareyi gösterir, otomatik oynatmaz.
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.url});

  final String url;

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
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url.trim();
    if (url.isEmpty) {
      setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
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
