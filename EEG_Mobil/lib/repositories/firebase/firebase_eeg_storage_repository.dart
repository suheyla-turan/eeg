import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';

import '../eeg_storage_repository.dart';

class FirebaseEegStorageRepository implements EegStorageRepository {
  FirebaseEegStorageRepository({FirebaseStorage? storage})
      : _storageOverride = storage;

  final FirebaseStorage? _storageOverride;

  FirebaseStorage get _storage =>
      _storageOverride ?? FirebaseStorage.instance;

  String _normalize(String relativePath) {
    return relativePath.startsWith('eeg/')
        ? relativePath
        : 'eeg/$relativePath';
  }

  @override
  Future<String> uploadJson({
    required String relativePath,
    required Map<String, dynamic> payload,
  }) async {
    final path = _normalize(relativePath);
    final ref = _storage.ref(path);
    await ref.putData(
      payload.toUtf8Bytes(),
      SettableMetadata(contentType: 'application/json'),
    );
    return path;
  }

  @override
  Future<String> uploadCsv({
    required String relativePath,
    required String csvContent,
  }) async {
    final path = _normalize(relativePath);
    final ref = _storage.ref(path);
    await ref.putData(
      csvContent.toUtf8Bytes(),
      SettableMetadata(contentType: 'text/csv'),
    );
    return path;
  }

  @override
  Future<({String folderPath, String jsonPath, String csvPath})> uploadPair({
    required String experimentId,
    required Map<String, dynamic> jsonPayload,
    required String csvContent,
  }) async {
    final folderPath = 'eeg/$experimentId';
    final jsonPath = await uploadJson(
      relativePath: '$folderPath/eeg.json',
      payload: jsonPayload,
    );
    final csvPath = await uploadCsv(
      relativePath: '$folderPath/eeg.csv',
      csvContent: csvContent,
    );
    return (folderPath: folderPath, jsonPath: jsonPath, csvPath: csvPath);
  }

  @override
  Future<Map<String, dynamic>?> downloadJson(String relativePath) async {
    try {
      final path = _normalize(relativePath);
      final data = await _storage.ref(path).getData(32 * 1024 * 1024);
      if (data == null || data.isEmpty) return null;
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
