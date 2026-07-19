import '../models/experiment.dart';

abstract class ExperimentRepository {
  Future<Experiment> create(Experiment experiment);

  Future<Experiment?> getById(String experimentId);

  Future<void> update(Experiment experiment);

  Future<List<Experiment>> getAll();

  Future<List<Experiment>> getByParticipantId(String participantId);

  Future<List<Experiment>> getByDateRange({
    DateTime? start,
    DateTime? end,
  });

  /// Yarım kalan / taslak / running deneyler (crash recovery).
  Future<List<Experiment>> getIncomplete();
}
