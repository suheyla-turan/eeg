import 'dart:convert';
import 'dart:typed_data';

/// Ham EEG dosyalarını Firebase Storage `eeg/` klasörüne yükler.
abstract class EegStorageRepository {
  /// [relativePath] örn: `eeg/{experimentId}.json`
  Future<String> uploadJson({
    required String relativePath,
    required Map<String, dynamic> payload,
  });

  /// [relativePath] örn: `eeg/{experimentId}.csv`
  Future<String> uploadCsv({
    required String relativePath,
    required String csvContent,
  });

  /// JSON + CSV birlikte; klasör yolu `eeg/{experimentId}` döner.
  Future<({String folderPath, String jsonPath, String csvPath})> uploadPair({
    required String experimentId,
    required Map<String, dynamic> jsonPayload,
    required String csvContent,
  });

  /// Storage'dan ham EEG JSON indirir (eski deneyleri yeniden yorumlamak için).
  Future<Map<String, dynamic>?> downloadJson(String relativePath);
}

extension EegJsonBytes on Map<String, dynamic> {
  Uint8List toUtf8Bytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(this)));
}

extension EegCsvBytes on String {
  Uint8List toUtf8Bytes() => Uint8List.fromList(utf8.encode(this));
}
