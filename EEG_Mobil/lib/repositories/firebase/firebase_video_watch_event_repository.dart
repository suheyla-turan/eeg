import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/video_watch_event.dart';
import '../video_watch_event_repository.dart';

class FirebaseVideoWatchEventRepository implements VideoWatchEventRepository {
  FirebaseVideoWatchEventRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('video_watch_events');

  @override
  Future<VideoWatchEvent> create(VideoWatchEvent event) async {
    final doc = _col.doc();
    final created = VideoWatchEvent(
      eventId: doc.id,
      experimentId: event.experimentId,
      videoId: event.videoId,
      startTime: event.startTime,
      endTime: event.endTime,
      watchDurationSeconds: event.watchDurationSeconds,
      percentWatched: event.percentWatched,
      replayCount: event.replayCount,
      transitionTime: event.transitionTime,
      category: event.category,
    );
    await doc.set(created.toMap());
    return created;
  }

  @override
  Future<List<VideoWatchEvent>> getByExperimentId(String experimentId) async {
    final snap =
        await _col.where('experimentId', isEqualTo: experimentId).get();
    final list = snap.docs
        .map((d) => VideoWatchEvent.fromMap(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }
}
