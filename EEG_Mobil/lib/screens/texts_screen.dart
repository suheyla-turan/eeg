import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_page_route.dart';
import '../models/text_content.dart';
import '../providers/text_content_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/loading_view.dart';
import 'text_form_screen.dart';

class TextsScreen extends StatefulWidget {
  const TextsScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<TextsScreen> createState() => _TextsScreenState();
}

class _TextsScreenState extends State<TextsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TextContentProvider>().loadAll();
    });
  }

  Future<void> _openForm({TextContent? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      AppPageRoute<bool>(
        transition: AppTransition.sharedAxisY,
        builder: (_) => TextFormScreen(existing: existing),
      ),
    );
    if (changed == true && mounted) {
      await context.read<TextContentProvider>().loadAll();
    }
  }

  Future<void> _confirmDelete(TextContent text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Metni sil'),
        content: Text('"${text.title}" silinsin mi?'),
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
    final provider = context.read<TextContentProvider>();
    final success = await provider.delete(text.textId);
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
    final provider = context.watch<TextContentProvider>();

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(
              title: const Text('Metin Listesi'),
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
        label: const Text('Metin Ekle'),
      ),
      body: provider.loading
          ? const LoadingView(message: 'Metinler yükleniyor…')
          : provider.errorMessage != null && provider.texts.isEmpty
              ? EmptyStateView(
                  title: 'Metinler yüklenemedi',
                  subtitle: provider.errorMessage,
                  icon: Icons.error_outline,
                  actionLabel: 'Tekrar Dene',
                  onAction: () =>
                      context.read<TextContentProvider>().loadAll(),
                )
              : provider.texts.isEmpty
                  ? const EmptyStateView(
                      title: 'Henüz metin yok',
                      subtitle:
                          'Yeni metin eklemek için + butonunu kullanın.',
                      icon: Icons.article_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: provider.texts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final t = provider.texts[index];
                        return Material(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppColors.line(context)),
                            ),
                            onTap: () => _openForm(existing: t),
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primarySoft,
                              child: Icon(
                                Icons.article_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              t.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${t.difficulty.isEmpty ? '—' : t.difficulty}'
                              ' · ~${t.estimatedDuration} sn'
                              ' · ${t.questions.length} soru'
                              ' · ${t.active ? 'Aktif' : 'Pasif'}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openForm(existing: t);
                                } else if (value == 'delete') {
                                  _confirmDelete(t);
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
