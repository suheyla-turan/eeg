import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_page_route.dart';
import '../models/text_content.dart';
import '../providers/text_content_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/loading_view.dart';

/// Kod içine gömülü metinleri listeler (ekleme/silme yok).
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

  void _openDetail(TextContent text) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        transition: AppTransition.sharedAxisY,
        builder: (_) => _TextDetailScreen(text: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TextContentProvider>();

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(
              title: const Text('Metinler'),
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
                      title: 'Yerel metin yok',
                      subtitle:
                          'lib/data/local_texts.dart listesine metin ekleyin.',
                      icon: Icons.article_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                            onTap: () => _openDetail(t),
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
                              t.questions.isEmpty
                                  ? 'Soru yok'
                                  : '${t.questions.length} soru'
                                      '${t.difficulty.isNotEmpty ? ' · ${t.difficulty}' : ''}',
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: AppColors.hint(context),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _TextDetailScreen extends StatelessWidget {
  const _TextDetailScreen({required this.text});

  final TextContent text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(text.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (text.difficulty.isNotEmpty || text.estimatedDuration > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                [
                  if (text.difficulty.isNotEmpty) text.difficulty,
                  if (text.estimatedDuration > 0)
                    '~${text.estimatedDuration} sn',
                  if (text.questions.isNotEmpty)
                    '${text.questions.length} soru',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondary(context),
                    ),
              ),
            ),
          Text(
            text.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.55,
                  color: AppColors.foreground(context),
                ),
          ),
          if (text.questions.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Sorular',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < text.questions.length; i++) ...[
              Text(
                '${i + 1}. ${text.questions[i].prompt}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              for (var c = 0; c < text.questions[i].choices.length; c++)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Text(
                    '${String.fromCharCode(65 + c)}) ${text.questions[i].choices[c]}'
                    '${c == text.questions[i].correctIndex ? '  ✓' : ''}',
                    style: TextStyle(
                      color: c == text.questions[i].correctIndex
                          ? AppColors.primary
                          : AppColors.foreground(context),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}
