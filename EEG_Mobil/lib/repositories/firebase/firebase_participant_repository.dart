import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/participant.dart';
import '../participant_repository.dart';

class FirebaseParticipantRepository implements ParticipantRepository {
  FirebaseParticipantRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('participants');

  @override
  Future<Participant> create(Participant participant) async {
    final ref = participant.participantId.isEmpty
        ? _col.doc()
        : _col.doc(participant.participantId);

    var code = participant.participantCode.trim();
    if (code.isEmpty) {
      code = await generateNextCode();
    }

    final saved = participant.copyWith(
      participantId: ref.id,
      participantCode: code,
    );
    await ref.set(saved.toMap());
    return saved;
  }

  @override
  Future<Participant?> getById(String participantId) async {
    final snap = await _col.doc(participantId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Participant.fromMap(snap.data()!, id: snap.id);
  }

  @override
  Future<List<Participant>> getAll() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => Participant.fromMap(d.data(), id: d.id))
        .toList();
  }

  @override
  Future<List<Participant>> searchByName(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return getAll();

    final all = await getAll();
    return all.where((p) {
      final full = p.fullName.toLowerCase();
      return full.contains(trimmed) ||
          p.firstName.toLowerCase().contains(trimmed) ||
          p.lastName.toLowerCase().contains(trimmed) ||
          p.participantCode.toLowerCase().contains(trimmed);
    }).toList();
  }

  @override
  Future<String> generateNextCode() async {
    final snap = await _col.get();
    var maxNum = 0;

    for (final doc in snap.docs) {
      final code = doc.data()['participantCode'] as String? ?? '';
      final match = RegExp(r'(\d+)').firstMatch(code);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!) ?? 0;
      if (n > maxNum) maxNum = n;
    }

    return 'P-${(maxNum + 1).toString().padLeft(4, '0')}';
  }
}
