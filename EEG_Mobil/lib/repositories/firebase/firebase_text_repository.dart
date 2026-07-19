import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/text_content.dart';
import '../text_repository.dart';

class FirebaseTextRepository implements TextRepository {
  FirebaseTextRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('texts');

  @override
  Future<List<TextContent>> getAll() async {
    final snap = await _col.get();
    final list = snap.docs
        .map((d) => TextContent.fromMap(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<TextContent>> getActive() async {
    final snap = await _col.where('active', isEqualTo: true).get();
    final list = snap.docs
        .map((d) => TextContent.fromMap(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<TextContent?> getById(String textId) async {
    final snap = await _col.doc(textId).get();
    if (!snap.exists || snap.data() == null) return null;
    return TextContent.fromMap(snap.data()!, id: snap.id);
  }

  @override
  Future<TextContent> create(TextContent text) async {
    final doc = _col.doc();
    final created = text.copyWith(textId: doc.id);
    await doc.set(created.toMap());
    return created;
  }

  @override
  Future<void> update(TextContent text) async {
    await _col.doc(text.textId).set(text.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> delete(String textId) async {
    await _col.doc(textId).delete();
  }
}
