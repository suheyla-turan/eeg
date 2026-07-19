import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_logger.dart';
import '../../models/experiment.dart';
import '../../models/experiment_status.dart';
import '../experiment_repository.dart';

class FirebaseExperimentRepository implements ExperimentRepository {
  FirebaseExperimentRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('experiments');

  @override
  Future<Experiment> create(Experiment experiment) async {
    try {
      final ref = experiment.experimentId.isEmpty
          ? _col.doc()
          : _col.doc(experiment.experimentId);
      final saved = experiment.copyWith(experimentId: ref.id);
      await ref.set(saved.toMap());
      AppLogger.instance.firebase('Experiment oluşturuldu: ${saved.experimentId}');
      return saved;
    } catch (e, st) {
      AppLogger.instance.error('Experiment create hatası', error: e, stackTrace: st);
      AppLogger.instance.firebase('Experiment create hatası', level: LogLevel.error, error: e);
      rethrow;
    }
  }

  @override
  Future<Experiment?> getById(String experimentId) async {
    final snap = await _col.doc(experimentId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Experiment.fromMap(snap.data()!, id: snap.id);
  }

  @override
  Future<void> update(Experiment experiment) async {
    try {
      await _col.doc(experiment.experimentId).update(experiment.toMap());
      AppLogger.instance.firebase(
        'Experiment güncellendi: ${experiment.experimentId} '
        '(${experiment.status})',
      );
    } catch (e, st) {
      AppLogger.instance.error('Experiment update hatası', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<Experiment>> getAll() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => Experiment.fromMap(d.data(), id: d.id))
        .toList();
  }

  @override
  Future<List<Experiment>> getByParticipantId(String participantId) async {
    final snap =
        await _col.where('participantId', isEqualTo: participantId).get();
    final list = snap.docs
        .map((d) => Experiment.fromMap(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<Experiment>> getByDateRange({
    DateTime? start,
    DateTime? end,
  }) async {
    final all = await getAll();
    return all.where((e) {
      if (start != null && e.createdAt.isBefore(start)) return false;
      if (end != null) {
        final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
        if (e.createdAt.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<Experiment>> getIncomplete() async {
    try {
      // completed == false olanlar; status filtreleme istemci tarafında
      // (composite index gerekmez).
      final snap = await _col.where('completed', isEqualTo: false).get();
      final list = snap.docs
          .map((d) => Experiment.fromMap(d.data(), id: d.id))
          .where(
            (e) =>
                ExperimentStatus.isIncomplete(e.status) ||
                e.status.isEmpty,
          )
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      AppLogger.instance.firebase(
        'Yarım kalan deneyler: ${list.length}',
      );
      return list;
    } catch (e, st) {
      AppLogger.instance.error(
        'getIncomplete hatası',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
