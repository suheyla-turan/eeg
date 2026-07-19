import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/participant_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/loading_view.dart';
import 'participant_history_screen.dart';

class ParticipantsScreen extends StatefulWidget {
  const ParticipantsScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParticipantProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParticipantProvider>();
    final dateFmt = DateFormat('d MMM yyyy', 'tr');

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Ad, soyad veya kod ara',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.card(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.line(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.line(context)),
              ),
            ),
            onChanged: (q) =>
                context.read<ParticipantProvider>().loadAll(query: q),
          ),
        ),
        Expanded(
          child: provider.loading
              ? const LoadingView(message: 'Katılımcılar yükleniyor…')
              : provider.participants.isEmpty
                  ? EmptyStateView(
                      title: 'Henüz katılımcı yok',
                      subtitle: 'Yeni katılımcı kaydı oluşturarak başlayın.',
                      icon: Icons.groups_outlined,
                      actionLabel: 'Yenile',
                      onAction: () =>
                          context.read<ParticipantProvider>().loadAll(),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: provider.participants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = provider.participants[index];
                        return Material(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppColors.line(context)),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.softPrimary(context),
                              foregroundColor: AppColors.primary,
                              child: Text(
                                p.firstName.isNotEmpty
                                    ? p.firstName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(
                              p.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${p.participantCode} · ${p.age} yaş · '
                              '${dateFmt.format(p.createdAt)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ParticipantHistoryScreen(
                                    participant: p,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(title: const Text('Katılımcılar')),
      body: body,
    );
  }
}
