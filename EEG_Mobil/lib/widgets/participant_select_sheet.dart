import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/participant.dart';
import '../providers/participant_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Deney başlatmadan önce katılımcı seçimi.
Future<void> showParticipantSelectSheet(
  BuildContext context, {
  required ValueChanged<Participant> onSelectExisting,
  required VoidCallback onAddNew,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ParticipantSelectSheet(
      onSelectExisting: onSelectExisting,
      onAddNew: onAddNew,
    ),
  );
}

class _ParticipantSelectSheet extends StatefulWidget {
  const _ParticipantSelectSheet({
    required this.onSelectExisting,
    required this.onAddNew,
  });

  final ValueChanged<Participant> onSelectExisting;
  final VoidCallback onAddNew;

  @override
  State<_ParticipantSelectSheet> createState() =>
      _ParticipantSelectSheetState();
}

class _ParticipantSelectSheetState extends State<_ParticipantSelectSheet> {
  bool _pickingExisting = false;
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

  Future<void> _openExistingList() async {
    setState(() => _pickingExisting = true);
    await context.read<ParticipantProvider>().loadAll();
  }

  List<Participant> _filtered(List<Participant> all) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (p) =>
              p.fullName.toLowerCase().contains(q) ||
              p.participantCode.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final provider = context.watch<ParticipantProvider>();

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _pickingExisting
              ? _ExistingList(
                  key: const ValueKey('list'),
                  loading: provider.loading,
                  search: _search,
                  participants: _filtered(provider.participants),
                  onBack: () => setState(() => _pickingExisting = false),
                  onSearchChanged: (_) => setState(() {}),
                  onSelect: (p) {
                    Navigator.of(context).pop();
                    widget.onSelectExisting(p);
                  },
                )
              : _ChoiceView(
                  key: const ValueKey('choice'),
                  onExisting: _openExistingList,
                  onNew: () {
                    Navigator.of(context).pop();
                    widget.onAddNew();
                  },
                ),
        ),
      ),
    );
  }
}

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({
    super.key,
    required this.onExisting,
    required this.onNew,
  });

  final VoidCallback onExisting;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Katılımcı Seç',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Deneye devam etmek için bir katılımcı seçin veya yeni kayıt oluşturun.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary(context),
                height: 1.4,
              ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _OptionTile(
          icon: Icons.people_alt_outlined,
          title: 'Mevcut Katılımcıyı Seç',
          subtitle: 'Kayıtlı katılımcılar arasından seçin',
          onTap: onExisting,
        ),
        const SizedBox(height: AppSpacing.md),
        _OptionTile(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Yeni Katılımcı Ekle',
          subtitle: 'Yeni kayıt oluşturup deneye geçin',
          onTap: onNew,
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.line(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.hint(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingList extends StatelessWidget {
  const _ExistingList({
    super.key,
    required this.loading,
    required this.search,
    required this.participants,
    required this.onBack,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final bool loading;
  final TextEditingController search;
  final List<Participant> participants;
  final VoidCallback onBack;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Participant> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'Mevcut Katılımcı',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: search,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Ad veya kod ile ara…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: participants.isEmpty && !loading
              ? Center(
                  child: Text(
                    'Katılımcı bulunamadı',
                    style: TextStyle(color: AppColors.secondary(context)),
                  ),
                )
              : ListView.separated(
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    return ListTile(
                      tileColor: AppColors.muted(context),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.softPrimary(context),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          p.firstName.isNotEmpty
                              ? p.firstName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(
                        p.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${p.participantCode} · ${p.age} yaş'),
                      trailing: const Icon(Icons.play_arrow_rounded),
                      onTap: () => onSelect(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
