import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../providers/participant_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/section_card.dart';

/// Özet istatistikler — mevcut provider verilerinden okur.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        context.read<ParticipantProvider>().loadAll(),
        context.read<HistoryProvider>().load(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final participants = context.watch<ParticipantProvider>();
    final history = context.watch<HistoryProvider>();
    final completed =
        history.items.where((e) => e.experiment.completed).length;
    final cancelled =
        history.items.where((e) => e.experiment.isCancelled).length;
    final total = history.items.length;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Uygulama genelindeki özet metrikler.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary(context),
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Özet',
          icon: Icons.insights_outlined,
          child: Column(
            children: [
              _StatRow(
                label: 'Katılımcılar',
                value: '${participants.participants.length}',
                icon: Icons.groups_outlined,
              ),
              const Divider(height: 24),
              _StatRow(
                label: 'Toplam deney',
                value: '$total',
                icon: Icons.science_outlined,
              ),
              const Divider(height: 24),
              _StatRow(
                label: 'Tamamlanan',
                value: '$completed',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
              const Divider(height: 24),
              _StatRow(
                label: 'İptal edilen',
                value: '$cancelled',
                icon: Icons.cancel_outlined,
                color: AppColors.danger,
              ),
            ],
          ),
        ),
        if (participants.loading || history.loading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );

    if (widget.embeddedInShell) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('İstatistikler')),
      body: SafeArea(child: body),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: c, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: c,
              ),
        ),
      ],
    );
  }
}
