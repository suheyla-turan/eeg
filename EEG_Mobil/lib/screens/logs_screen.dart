import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_logger.dart';
import '../core/responsive.dart';
import '../widgets/empty_state_view.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _logger = AppLogger.instance;

  static const _categories = LogCategory.values;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _logger.addListener(_onLog);
  }

  void _onLog(LogEntry _) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _logger.removeListener(_onLog);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem Logları'),
        actions: [
          IconButton(
            tooltip: 'Temizle',
            onPressed: () {
              final cat = _categories[_tabs.index];
              _logger.clear(cat);
              setState(() {});
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            for (final c in _categories)
              Tab(text: '${c.labelTr} (${_logger.count(c)})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final category in _categories)
            _LogList(
              entries: _logger.entries(category).toList().reversed.toList(),
              timeFmt: timeFmt,
              emptyTitle: '${category.labelTr} logu yok',
            ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.entries,
    required this.timeFmt,
    required this.emptyTitle,
  });

  final List<LogEntry> entries;
  final DateFormat timeFmt;
  final String emptyTitle;

  Color _levelColor(BuildContext context, LogLevel level) {
    final scheme = Theme.of(context).colorScheme;
    return switch (level) {
      LogLevel.error => scheme.error,
      LogLevel.warning => Colors.orange,
      LogLevel.info => scheme.primary,
      LogLevel.debug => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return EmptyStateView(
        title: emptyTitle,
        subtitle: 'Bu kategoride henüz kayıt yok.',
        icon: Icons.article_outlined,
      );
    }

    return ResponsiveBody(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final e = entries[index];
          return ListTile(
            dense: true,
            leading: Text(
              timeFmt.format(e.timestamp),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            title: Text(
              e.message,
              style: TextStyle(
                color: _levelColor(context, e.level),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: e.details != null
                ? Text(
                    e.details!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
          );
        },
      ),
    );
  }
}
