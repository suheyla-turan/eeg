import '../models/experiment_result.dart';

abstract class ResultRepository {
  Future<ExperimentResult> create(ExperimentResult result);

  Future<ExperimentResult?> getById(String resultId);

  Future<ExperimentResult?> getByExperimentId(String experimentId);
}
