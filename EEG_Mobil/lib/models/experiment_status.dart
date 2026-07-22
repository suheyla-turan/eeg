/// Deney oturumunun kalıcı durumu (Firestore).
abstract final class ExperimentStatus {
  static const String pending = 'pending';
  static const String draft = 'draft';
  static const String running = 'running';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static String labelTr(String status) => switch (status) {
        pending => 'Beklemede',
        draft => 'Taslak',
        running => 'Devam Ediyor',
        completed => 'Tamamlandı',
        cancelled => 'İptal Edildi',
        _ => status,
      };

  static bool isIncomplete(String status) =>
      status == pending || status == draft || status == running;
}
