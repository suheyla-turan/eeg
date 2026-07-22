import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/app_logger.dart';
import '../models/experiment_step.dart';

/// Beklenmeyen kapanmada EEG buffer + oturum meta verisini yerelde saklar.
class SessionCheckpoint {
  const SessionCheckpoint({
    required this.experimentId,
    required this.participantId,
    required this.experimentType,
    required this.phase,
    required this.step,
    required this.samples,
    required this.savedAt,
    this.videoId,
    this.textId,
    this.readingPhase = false,
  });

  final String experimentId;
  final String participantId;
  final String experimentType;
  final String phase;
  final String step;
  final List<Map<String, dynamic>> samples;
  final DateTime savedAt;
  final String? videoId;
  final String? textId;
  final bool readingPhase;

  int get sampleCount => samples.length;

  Map<String, dynamic> toJson() => {
        'experimentId': experimentId,
        'participantId': participantId,
        'experimentType': experimentType,
        'phase': phase,
        'step': step,
        'samples': samples,
        'savedAt': savedAt.toIso8601String(),
        'videoId': videoId,
        'textId': textId,
        'readingPhase': readingPhase,
      };

  factory SessionCheckpoint.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['samples'];
    final samples = <Map<String, dynamic>>[];
    if (rawSamples is List) {
      for (final s in rawSamples) {
        if (s is Map<String, dynamic>) {
          samples.add(s);
        } else if (s is Map) {
          samples.add(Map<String, dynamic>.from(s));
        }
      }
    }

    return SessionCheckpoint(
      experimentId: json['experimentId'] as String? ?? '',
      participantId: json['participantId'] as String? ?? '',
      experimentType: json['experimentType'] as String? ?? 'full_protocol',
      phase: json['phase'] as String? ?? 'reels',
      step: json['step'] as String? ?? ExperimentStep.reelsBriefing.name,
      samples: samples,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
      videoId: json['videoId'] as String?,
      textId: json['textId'] as String?,
      readingPhase: json['readingPhase'] as bool? ?? false,
    );
  }
}

class SessionCheckpointService {
  static const _fileName = 'eeg_session_checkpoint.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> save(SessionCheckpoint checkpoint) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode(checkpoint.toJson()),
        flush: true,
      );
      AppLogger.instance.experiment(
        'Checkpoint kaydedildi '
        '(${checkpoint.sampleCount} örnek, ${checkpoint.experimentId})',
      );
    } catch (e, st) {
      AppLogger.instance.error('Checkpoint kaydı başarısız', error: e, stackTrace: st);
    }
  }

  Future<SessionCheckpoint?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cp = SessionCheckpoint.fromJson(json);
      if (cp.experimentId.isEmpty) return null;
      AppLogger.instance.experiment(
        'Checkpoint yüklendi (${cp.sampleCount} örnek)',
      );
      return cp;
    } catch (e, st) {
      AppLogger.instance.error('Checkpoint okuma hatası', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
      }
      AppLogger.instance.experiment('Checkpoint temizlendi');
    } catch (e, st) {
      AppLogger.instance.error('Checkpoint silinemedi', error: e, stackTrace: st);
    }
  }

  Future<bool> hasCheckpoint() async {
    final file = await _file();
    return file.exists();
  }
}
