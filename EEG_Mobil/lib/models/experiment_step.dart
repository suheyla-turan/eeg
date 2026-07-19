/// Profesyonel deney akışındaki adımlar.
enum ExperimentStep {
  /// Katılımcı formu (akış öncesi).
  participantInfo,

  /// EEG cihaz bağlantı kontrolü.
  eegConnection,

  /// Genel deney bilgilendirme.
  experimentBriefing,

  /// (Kaldırıldı) Eski checkpoint uyumluluğu için tutuluyor.
  baseline,

  /// Reels öncesi 15 sn bilgilendirme.
  reelsBriefing,

  /// 10 dk Reels deneyi.
  reels,

  /// Reels tamamlandı bekleme.
  reelsCompleted,

  /// Metin öncesi bilgilendirme.
  textBriefing,

  /// 10 dk metin okuma.
  textReading,

  /// Sonuç analizi.
  analyzing,

  /// Sonuç ekranı.
  results,

  /// Kullanıcı tarafından iptal.
  cancelled,
}

extension ExperimentStepX on ExperimentStep {
  String get labelTr {
    switch (this) {
      case ExperimentStep.participantInfo:
        return 'Katılımcı Bilgileri';
      case ExperimentStep.eegConnection:
        return 'EEG Bağlantısı';
      case ExperimentStep.experimentBriefing:
        return 'Deney Bilgilendirme';
      case ExperimentStep.baseline:
        return 'Baseline';
      case ExperimentStep.reelsBriefing:
        return 'Reels Bilgilendirme';
      case ExperimentStep.reels:
        return 'Reels Deneyi';
      case ExperimentStep.reelsCompleted:
        return 'Reels Tamamlandı';
      case ExperimentStep.textBriefing:
        return 'Metin Bilgilendirme';
      case ExperimentStep.textReading:
        return 'Metin Deneyi';
      case ExperimentStep.analyzing:
        return 'Analiz';
      case ExperimentStep.results:
        return 'Sonuçlar';
      case ExperimentStep.cancelled:
        return 'İptal Edildi';
    }
  }

  bool get isTerminal =>
      this == ExperimentStep.results || this == ExperimentStep.cancelled;
}
