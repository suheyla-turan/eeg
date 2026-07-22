import '../models/participant.dart';

abstract class ParticipantRepository {
  Future<Participant> create(Participant participant);

  Future<Participant?> getById(String participantId);

  Future<List<Participant>> getAll();

  Future<List<Participant>> searchByName(String query);

  /// Sıradaki otomatik katılımcı kodunu üretir (örn. P-0001).
  Future<String> generateNextCode();
}
