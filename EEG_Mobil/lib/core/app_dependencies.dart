import '../repositories/eeg_storage_repository.dart';
import '../repositories/experiment_repository.dart';
import '../repositories/firebase/firebase_eeg_storage_repository.dart';
import '../repositories/firebase/firebase_experiment_repository.dart';
import '../repositories/firebase/firebase_participant_repository.dart';
import '../repositories/firebase/firebase_result_repository.dart';
import '../repositories/firebase/firebase_text_repository.dart';
import '../repositories/firebase/firebase_video_repository.dart';
import '../repositories/firebase/firebase_video_watch_event_repository.dart';
import '../repositories/participant_repository.dart';
import '../repositories/result_repository.dart';
import '../repositories/text_repository.dart';
import '../repositories/video_repository.dart';
import '../repositories/video_watch_event_repository.dart';
import '../services/eeg_api_service.dart';
import '../services/eeg_service.dart';
import '../services/experiment_session_service.dart';

/// SOLID: bağımlılıklar soyutlamalara bağlanır (DI konteyneri).
class AppDependencies {
  AppDependencies({
    required this.participantRepository,
    required this.experimentRepository,
    required this.resultRepository,
    required this.videoRepository,
    required this.textRepository,
    required this.videoWatchEventRepository,
    required this.eegStorageRepository,
    required this.eegApiService,
    required this.eegService,
    required this.experimentSessionService,
  });

  final ParticipantRepository participantRepository;
  final ExperimentRepository experimentRepository;
  final ResultRepository resultRepository;
  final VideoRepository videoRepository;
  final TextRepository textRepository;
  final VideoWatchEventRepository videoWatchEventRepository;
  final EegStorageRepository eegStorageRepository;
  final EegApiService eegApiService;
  final EegService eegService;
  final ExperimentSessionService experimentSessionService;

  factory AppDependencies.create() {
    final participants = FirebaseParticipantRepository();
    final experiments = FirebaseExperimentRepository();
    final results = FirebaseResultRepository();
    final videos = FirebaseVideoRepository();
    final texts = FirebaseTextRepository();
    final watchEvents = FirebaseVideoWatchEventRepository();
    final storage = FirebaseEegStorageRepository();
    final api = EegApiService();
    final eeg = EegService(api: api);
    final session = ExperimentSessionService(
      participantRepository: participants,
      experimentRepository: experiments,
      resultRepository: results,
      eegStorageRepository: storage,
      eegApiService: api,
      eegService: eeg,
    );

    return AppDependencies(
      participantRepository: participants,
      experimentRepository: experiments,
      resultRepository: results,
      videoRepository: videos,
      textRepository: texts,
      videoWatchEventRepository: watchEvents,
      eegStorageRepository: storage,
      eegApiService: api,
      eegService: eeg,
      experimentSessionService: session,
    );
  }

  void dispose() {
    experimentSessionService.dispose();
    eegService.dispose();
    eegApiService.dispose();
  }
}
