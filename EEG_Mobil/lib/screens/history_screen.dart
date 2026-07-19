import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import 'participant_history_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final history = context.read<HistoryProvider>();
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: history.filterStart != null && history.filterEnd != null
          ? DateTimeRange(
              start: history.filterStart!,
              end: history.filterEnd!,
            )
          : null,
    );
    if (range == null) return;
    history.setDateFilter(start: range.start, end: range.end);
    await history.load();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final dateFmt = DateFormat('d MMM yyyy HH:mm', 'tr');

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(
              title: const Text('Geçmiş Deneyler'),
              automaticallyImplyLeading: Navigator.canPop(context),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Katılımcı adına göre arayın, tarihe göre filtreleyin.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondary(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Katılımcı adı…',
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
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          history.setNameQuery('');
                          history.load();
                        },
                      ),
                    ),
                    onChanged: history.setNameQuery,
                    onSubmitted: (_) => history.load(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          history.filterStart == null
                              ? 'Tarih filtresi'
                              : '${DateFormat('d MMM', 'tr').format(history.filterStart!)} – ${DateFormat('d MMM', 'tr').format(history.filterEnd!)}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          history.clearFilters();
                          _search.clear();
                          history.load();
                        },
                        child: const Text('Temizle'),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: history.loading ? null : history.load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (history.loading) const LinearProgressIndicator(minHeight: 2),
            if (history.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  history.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: history.load,
                child: history.items.isEmpty && !history.loading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 48),
                          EmptyStateView(
                            title: 'Henüz deney kaydı yok',
                            subtitle:
                                'Tamamlanan veya iptal edilen deneyler burada görünür.',
                            icon: Icons.history_outlined,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: history.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = history.items[index];
                          final exp = item.experiment;
                          final p = item.participant;
                          return Material(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ParticipantHistoryScreen(
                                      participant: p,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.line(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.softPrimary(context),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.fullName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  AppColors.foreground(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${exp.experimentType} · ${dateFmt.format(exp.createdAt)}'
                                            '${exp.isCancelled ? ' · İptal' : exp.completed ? ' · Tamamlandı' : ''}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  AppColors.secondary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      exp.isCancelled
                                          ? Icons.cancel_outlined
                                          : exp.completed
                                              ? Icons.check_circle
                                              : Icons.timelapse,
                                      color: exp.isCancelled
                                          ? AppColors.danger
                                          : exp.completed
                                              ? AppColors.success
                                              : AppColors.warning,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
