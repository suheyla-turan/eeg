import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_eeg.dart';
import '../providers/eeg_provider.dart';
import '../services/eeg_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brain_map.dart';
import '../widgets/contact_quality_grid.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';

class LiveEegScreen extends StatelessWidget {
  const LiveEegScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eeg = context.watch<EegProvider>();
    final live = eeg.live;
    final collecting = live.collecting;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: eeg.reconnect,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Canlı EEG Durumu',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.foreground(context),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'WebSocket akışı otomatik; bağlı olunca veri başlar',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondary(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: eeg.busy ? null : eeg.toggleCollection,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          collecting ? AppColors.warning : AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: eeg.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(collecting ? Icons.stop : Icons.play_arrow),
                    label: Text(collecting ? 'Durdur' : 'Başlat'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                collecting
                    ? 'EEG veri toplama açık'
                    : 'Cihaz durumu canlı — bağlantıda otomatik akış başlar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: collecting ? AppColors.success : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              if (live.error != null &&
                  live.connection != ConnectionStatus.connected)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8E4E4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    live.error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.danger,
                      height: 1.35,
                    ),
                  ),
                ),
              _ConnectionBanner(connection: live.connection, error: live.error),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Bağlantı',
                      child: StatusPill(
                        label: live.connectionLabelTr,
                        tone: _connectionTone(live.connection),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Pil',
                      child: Text(
                        '${live.batteryPercent}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Sensör',
                      child: Text(
                        '${live.sensorCount}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Beyin Haritası',
                subtitle:
                    'Temas kalitesine göre aktivite · sinyal ${live.signal.toStringAsFixed(1)}',
                child: BrainMap(
                  quality: live.contactQuality,
                  bandPower: live.bandPower,
                ),
              ),
              SectionCard(
                title: 'Temas Kalitesi',
                subtitle:
                    'Emotiv contact quality (0–4) · genel ${live.overallQuality}',
                child: ContactQualityGrid(quality: live.contactQuality),
              ),
              Text(
                'API: ${EegApiConfig.displayUrl}/ws/live · WebSocket',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.hint(context),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  StatusTone _connectionTone(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.connected => StatusTone.success,
      ConnectionStatus.connecting => StatusTone.warning,
      ConnectionStatus.deviceFound => StatusTone.info,
      ConnectionStatus.deviceNotWorn => StatusTone.warning,
      ConnectionStatus.disconnected => StatusTone.danger,
    };
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connection, this.error});

  final ConnectionStatus connection;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (connection == ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    final dark = AppColors.isDark(context);
    final (Color bg, Color fg, String text) = switch (connection) {
      ConnectionStatus.connecting => (
          AppColors.muted(context),
          AppColors.secondary(context),
          'Python Cortex’e bağlanıyor… Emotiv Launcher ve cihaz hazır olmalı.',
        ),
      ConnectionStatus.deviceFound => (
          AppColors.softPrimary(context),
          AppColors.primary,
          'Cihaz bulundu. Oturum ve EEG stream hazırlanıyor…',
        ),
      ConnectionStatus.deviceNotWorn => (
          dark ? const Color(0xFF332A14) : const Color(0xFFFBF0D4),
          AppColors.warning,
          error ?? 'Cihaz takılı değil. Headset’i başına yerleştirin.',
        ),
      _ => (
          dark ? const Color(0xFF332A14) : const Color(0xFFFBF0D4),
          AppColors.warning,
          error ??
              'PC’deki Python API’ye ulaşılamıyor. Aynı Wi‑Fi, host IP '
              'veya USB adb reverse kontrol et. Emotiv Launcher tek başına yetmez.',
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: fg, height: 1.35),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _StatCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.hint(context),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
