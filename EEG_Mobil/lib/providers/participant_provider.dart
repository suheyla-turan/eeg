import 'package:flutter/foundation.dart';

import '../models/participant.dart';
import '../repositories/participant_repository.dart';

class ParticipantProvider extends ChangeNotifier {
  ParticipantProvider({required ParticipantRepository repository})
      : _repository = repository;

  final ParticipantRepository _repository;

  bool loading = false;
  bool saving = false;
  String? errorMessage;
  String? nextCode;
  List<Participant> participants = [];
  Participant? lastSaved;

  Future<void> prepareRegistration() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      nextCode = await _repository.generateNextCode();
    } catch (e) {
      errorMessage = e.toString();
      nextCode = null;
      if (kDebugMode) debugPrint('prepareRegistration: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAll({String query = ''}) async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      participants = query.trim().isEmpty
          ? await _repository.getAll()
          : await _repository.searchByName(query);
    } catch (e) {
      errorMessage = e.toString();
      participants = [];
      if (kDebugMode) debugPrint('loadAll participants: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Participant?> save(Participant draft) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final code = draft.participantCode.isNotEmpty
          ? draft.participantCode
          : (nextCode ?? await _repository.generateNextCode());

      lastSaved = await _repository.create(
        draft.copyWith(participantCode: code),
      );
      nextCode = await _repository.generateNextCode();
      return lastSaved;
    } catch (e) {
      errorMessage = e.toString();
      if (kDebugMode) debugPrint('save participant: $e');
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
