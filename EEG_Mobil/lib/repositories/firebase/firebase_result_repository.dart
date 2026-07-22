import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/experiment_result.dart';
import '../result_repository.dart';

class FirebaseResultRepository implements ResultRepository {
  FirebaseResultRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('results');

  @override
  Future<ExperimentResult> create(ExperimentResult result) async {
    final ref =
        result.resultId.isEmpty ? _col.doc() : _col.doc(result.resultId);
    final saved = result.copyWith(resultId: ref.id);
    await ref.set(saved.toMap());
    return saved;
  }

  @override
  Future<ExperimentResult?> getById(String resultId) async {
    final snap = await _col.doc(resultId).get();
    if (!snap.exists || snap.data() == null) return null;
    return ExperimentResult.fromMap(snap.data()!, id: snap.id);
  }

  @override
  Future<ExperimentResult?> getByExperimentId(String experimentId) async {
    final snap = await _col
        .where('experimentId', isEqualTo: experimentId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return ExperimentResult.fromMap(doc.data(), id: doc.id);
  }

  @override
  Future<ExperimentResult> update(ExperimentResult result) async {
    if (result.resultId.isEmpty) {
      throw ArgumentError('resultId gerekli');
    }
    await _col.doc(result.resultId).set(result.toMap());
    return result;
  }
}
