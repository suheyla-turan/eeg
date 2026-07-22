import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Log kategorileri — her kanal ayrı tutulur.
enum LogCategory {
  python,
  eeg,
  firebase,
  experiment,
  error,
}

extension LogCategoryX on LogCategory {
  String get labelTr => switch (this) {
        LogCategory.python => 'Python',
        LogCategory.eeg => 'EEG',
        LogCategory.firebase => 'Firebase',
        LogCategory.experiment => 'Deney',
        LogCategory.error => 'Hatalar',
      };

  String get tag => switch (this) {
        LogCategory.python => 'PY',
        LogCategory.eeg => 'EEG',
        LogCategory.firebase => 'FB',
        LogCategory.experiment => 'EXP',
        LogCategory.error => 'ERR',
      };
}

enum LogLevel { debug, info, warning, error }

class LogEntry {
  const LogEntry({
    required this.category,
    required this.level,
    required this.message,
    required this.timestamp,
    this.details,
  });

  final LogCategory category;
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? details;

  String get levelLabel => switch (level) {
        LogLevel.debug => 'DBG',
        LogLevel.info => 'INF',
        LogLevel.warning => 'WRN',
        LogLevel.error => 'ERR',
      };
}

/// Bellek içi yapılandırılmış log deposu (kategori bazlı).
///
/// SOLID: tek sorumluluk — sadece log tutma/okuma.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int maxPerCategory = 500;

  final Map<LogCategory, Queue<LogEntry>> _buffers = {
    for (final c in LogCategory.values) c: Queue<LogEntry>(),
  };

  final List<void Function(LogEntry)> _listeners = [];

  void addListener(void Function(LogEntry) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(LogEntry) listener) =>
      _listeners.remove(listener);

  List<LogEntry> entries(LogCategory category) =>
      List<LogEntry>.unmodifiable(_buffers[category]!);

  List<LogEntry> allEntries() {
    final all = <LogEntry>[];
    for (final q in _buffers.values) {
      all.addAll(q);
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  int count(LogCategory category) => _buffers[category]!.length;

  void clear([LogCategory? category]) {
    if (category != null) {
      _buffers[category]!.clear();
    } else {
      for (final q in _buffers.values) {
        q.clear();
      }
    }
  }

  void python(String message, {LogLevel level = LogLevel.info, Object? error}) =>
      _log(LogCategory.python, level, message, error);

  void eeg(String message, {LogLevel level = LogLevel.info, Object? error}) =>
      _log(LogCategory.eeg, level, message, error);

  void firebase(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
  }) =>
      _log(LogCategory.firebase, level, message, error);

  void experiment(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
  }) =>
      _log(LogCategory.experiment, level, message, error);

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    final details = [
      if (error != null) error.toString(),
      if (stackTrace != null) stackTrace.toString(),
    ].join('\n');
    _log(
      LogCategory.error,
      LogLevel.error,
      message,
      null,
      details: details.isEmpty ? null : details,
    );
  }

  void _log(
    LogCategory category,
    LogLevel level,
    String message,
    Object? error, {
    String? details,
  }) {
    final entry = LogEntry(
      category: category,
      level: level,
      message: message,
      timestamp: DateTime.now(),
      details: details ?? (error?.toString()),
    );

    final buf = _buffers[category]!;
    buf.addLast(entry);
    while (buf.length > maxPerCategory) {
      buf.removeFirst();
    }

    // Hata kategorisine de kopyala (python/eeg/firebase hataları)
    if (level == LogLevel.error && category != LogCategory.error) {
      final errBuf = _buffers[LogCategory.error]!;
      errBuf.addLast(entry);
      while (errBuf.length > maxPerCategory) {
        errBuf.removeFirst();
      }
    }

    if (kDebugMode) {
      final detail = entry.details != null ? ' | ${entry.details}' : '';
      debugPrint('[${entry.category.tag}/${entry.levelLabel}] $message$detail');
    }

    for (final listener in List.of(_listeners)) {
      listener(entry);
    }
  }
}
