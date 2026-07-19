import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/video_content.dart';
import '../video_repository.dart';

class FirebaseVideoRepository implements VideoRepository {
  FirebaseVideoRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestoreOverride = firestore,
        _storageOverride = storage;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseStorage get _storage =>
      _storageOverride ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('videos');

  @override
  Future<List<VideoContent>> getAll() async {
    final snap = await _col.get();
    final list = snap.docs
        .map((d) => VideoContent.fromMap(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<VideoContent>> getActive() async {
    // Firestore `where('active' == true)` alanı olmayan belgeleri dışlar.
    // Liste ekranı getAll + fromMap(active ?? true) kullandığı için
    // istemci tarafında aynı kuralı uygularız.
    final all = await getAll();
    return all
        .where((v) => v.active && v.storageUrl.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<VideoContent?> getById(String videoId) async {
    final snap = await _col.doc(videoId).get();
    if (!snap.exists || snap.data() == null) return null;
    return VideoContent.fromMap(snap.data()!, id: snap.id);
  }

  @override
  Future<VideoContent> create(VideoContent video) async {
    final doc = _col.doc();
    final created = video.copyWith(videoId: doc.id);
    await doc.set(created.toMap());
    return created;
  }

  @override
  Future<void> update(VideoContent video) async {
    await _col.doc(video.videoId).set(video.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> delete(String videoId) async {
    await _deleteStorageForVideo(videoId);
    await _col.doc(videoId).delete();
  }

  /// Yalnızca Firestore kaydını siler (başarısız yükleme geri alma).
  Future<void> deleteMetadata(String videoId) async {
    await _col.doc(videoId).delete();
  }

  @override
  Future<int> deleteAll() async {
    final snap = await _col.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
    await _deleteAllStorageVideos();
    return snap.docs.length;
  }

  Future<void> _deleteStorageForVideo(String videoId) async {
    for (final folder in ['videos', 'videos/thumbnails']) {
      try {
        final listed = await _storage.ref(folder).listAll();
        for (final item in listed.items) {
          if (!item.name.startsWith('$videoId.')) continue;
          try {
            await item.delete();
          } catch (_) {
            // Dosya yoksa veya zaten silinmişse yoksay.
          }
        }
      } catch (_) {
        // Storage listesi başarısız olsa bile Firestore silinsin.
      }
    }
  }

  Future<void> _deleteAllStorageVideos() async {
    try {
      final root = await _storage.ref('videos').listAll();
      for (final item in root.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
      for (final prefix in root.prefixes) {
        final nested = await prefix.listAll();
        for (final item in nested.items) {
          try {
            await item.delete();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Storage temizliği başarısız olsa bile Firestore silinmiş olur.
    }
  }

  @override
  Future<String> uploadVideoFile({
    required String videoId,
    required File file,
  }) async {
    final ext = _extension(file.path, fallback: 'mp4');
    final ref = _storage.ref('videos/$videoId.$ext');
    await ref.putFile(file, SettableMetadata(contentType: 'video/$ext'));
    return ref.getDownloadURL();
  }

  @override
  Future<String> uploadThumbnailFile({
    required String videoId,
    required File file,
  }) async {
    final ext = _extension(file.path, fallback: 'jpg');
    final ref = _storage.ref('videos/thumbnails/$videoId.$ext');
    await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
    return ref.getDownloadURL();
  }

  String _extension(String path, {required String fallback}) {
    final i = path.lastIndexOf('.');
    if (i < 0 || i == path.length - 1) return fallback;
    return path.substring(i + 1).toLowerCase();
  }
}
