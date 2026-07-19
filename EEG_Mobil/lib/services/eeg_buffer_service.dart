import 'dart:convert';

import '../data/mock_eeg.dart';

/// Deney boyunca EEG örneklerini tek buffer'da tutar.
/// Aşamalar değişse bile kayıt kesilmez; yalnızca [phase] etiketi güncellenir.
class EegBufferService {
  final List<Map<String, dynamic>> _samples = [];
  String _currentPhase = 'baseline';

  int get sampleCount => _samples.length;

  bool get isEmpty => _samples.isEmpty;

  String get currentPhase => _currentPhase;

  List<Map<String, dynamic>> get samples =>
      List<Map<String, dynamic>>.unmodifiable(_samples);

  void clear() {
    _samples.clear();
    _currentPhase = 'baseline';
  }

  /// Crash recovery: kaydedilmiş örnekleri geri yükler.
  void restoreSamples(
    List<Map<String, dynamic>> samples, {
    String phase = 'baseline',
  }) {
    _samples
      ..clear()
      ..addAll(samples.map((s) => Map<String, dynamic>.from(s)));
    _currentPhase = phase;
  }

  /// Kayıt durmaz — yalnızca sonraki örneklerin aşama etiketi değişir.
  void setPhase(String phase) {
    _currentPhase = phase;
  }

  void addSample(LiveEegState state, {DateTime? capturedAt, String? phase}) {
    final at = capturedAt ?? DateTime.now();
    final tag = phase ?? _currentPhase;
    _samples.add({
      'capturedAt': at.toIso8601String(),
      'phase': tag,
      'connection': state.connection.name,
      'collecting': state.collecting,
      'batteryPercent': state.batteryPercent,
      'sensorCount': state.sensorCount,
      'signal': state.signal,
      'overallQuality': state.overallQuality,
      'contactQuality': state.rawContactQuality,
      'bandPower': state.bandPower,
      'eeg': state.eeg.toJson(),
      'timestamp': state.eeg.timestamp,
      'updatedAt': state.updatedAt,
      if (state.error != null) 'error': state.error,
    });
  }

  List<Map<String, dynamic>> samplesForPhase(String phase) {
    return _samples.where((s) => s['phase'] == phase).toList();
  }

  Map<String, dynamic> toJsonPayload({
    required String experimentId,
    required String participantId,
    Map<String, dynamic>? meta,
  }) {
    return {
      'experimentId': experimentId,
      'participantId': participantId,
      'sampleCount': _samples.length,
      'exportedAt': DateTime.now().toIso8601String(),
      if (meta != null) 'meta': meta,
      'samples': _samples,
    };
  }

  /// Düz CSV: her satır bir örnek.
  String toCsv({
    required String experimentId,
    required String participantId,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      'experimentId,participantId,capturedAt,phase,signal,overallQuality,'
      'batteryPercent,connection,collecting',
    );
    for (final s in _samples) {
      final row = [
        _csv(experimentId),
        _csv(participantId),
        _csv(s['capturedAt']),
        _csv(s['phase']),
        s['signal'] ?? 0,
        s['overallQuality'] ?? 0,
        s['batteryPercent'] ?? 0,
        _csv(s['connection']),
        s['collecting'] == true,
      ];
      buf.writeln(row.join(','));
    }
    return buf.toString();
  }

  String _csv(dynamic value) {
    final raw = '$value';
    if (raw.contains(',') || raw.contains('"') || raw.contains('\n')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }

  /// JSON payload'ın UTF-8 baytları.
  List<int> jsonUtf8Bytes({
    required String experimentId,
    required String participantId,
    Map<String, dynamic>? meta,
  }) {
    return utf8.encode(
      jsonEncode(
        toJsonPayload(
          experimentId: experimentId,
          participantId: participantId,
          meta: meta,
        ),
      ),
    );
  }
}
