import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_content.dart';
import '../providers/video_content_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/loading_view.dart';
import 'video_form_screen.dart';

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

  Future<void> _openForm({VideoContent? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VideoFormScreen(existing: existing),
      ),
    );
    if (changed == true && mounted) {
      await context.read<VideoContentProvider>().loadAll();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoContentProvider>();

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(
              title: const Text('Video Listesi'),
              actions: [
                IconButton(
                  onPressed: provider.loading ? null : provider.loadAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Video Ekle'),
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
                          'Yeni video eklemek için + butonunu kullanın.',
                      icon: Icons.videocam_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: provider.videos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final v = provider.videos[index];
                        return Material(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppColors.line(context)),
                            ),
                            onTap: () => _openForm(existing: v),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.softPrimary(context),
                              backgroundImage: v.thumbnail != null &&
                                      v.thumbnail!.isNotEmpty
                                  ? NetworkImage(v.thumbnail!)
                                  : null,
                              child: v.thumbnail == null ||
                                      v.thumbnail!.isEmpty
                                  ? const Icon(
                                      Icons.videocam_outlined,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            title: Text(
                              v.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [
                                if (v.category.isNotEmpty) v.category,
                                '${v.duration} sn',
                                v.active ? 'Aktif' : 'Pasif',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openForm(existing: v);
                                } else if (value == 'delete') {
                                  _confirmDelete(v);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Düzenle'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Sil'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
