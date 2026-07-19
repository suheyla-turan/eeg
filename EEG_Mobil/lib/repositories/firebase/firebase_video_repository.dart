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
    final snap = await _col.where('active', isEqualTo: true).get();
    final list = snap.docs
        .map((d) => VideoContent.fromMap(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
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
    await _col.doc(videoId).delete();
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
