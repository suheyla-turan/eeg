import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_eeg.dart';
import '../data/sensors.dart';
import '../providers/eeg_provider.dart';
import '../services/eeg_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/eeg_realtime_chart.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';

class LiveStreamScreen extends StatelessWidget {
  const LiveStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eeg = context.watch<EegProvider>();
    final live = eeg.live;
    final connected = eeg.isConnected;
    final history = eeg.history.toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerçek Zamanlı EEG',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '14 kanal WebSocket akışı · tek kanal seçilebilir',
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
                    backgroundColor: live.collecting
                        ? AppColors.warning
                        : AppColors.success,
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
                      : Icon(
                          live.collecting ? Icons.stop : Icons.play_arrow,
                        ),
                  label: Text(live.collecting ? 'Durdur' : 'Başlat'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: eeg.clearHistory,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Grafiği temizle'),
                ),
                const Spacer(),
                Text(
                  connected
                      ? (live.collecting
                          ? 'Cihaz bağlı · EEG kaydı açık'
                          : 'Cihaz bağlı · akış aktif')
                      : live.connectionLabelTr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: connected ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (live.error != null && !connected)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8E4E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  live.error!,
                  style: const TextStyle(fontSize: 13, color: AppColors.danger),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Durum',
                    child: StatusPill(
                      label: live.connectionLabelTr,
                      tone: _tone(live.connection),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Örnek',
                    child: Text(
                      '${history.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Pil',
                    child: Text(
                      '${live.batteryPercent}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Sinyal',
                    child: Text(
                      live.signal.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Kanal Seçimi',
              subtitle: eeg.selectedChannel == null
                  ? '14 kanal birlikte gösteriliyor'
                  : 'Seçili: ${eeg.selectedChannel}',
              child: EegChannelSelector(
                selectedChannel: eeg.selectedChannel,
                onSelected: eeg.selectChannel,
              ),
            ),
            SectionCard(
              title: eeg.selectedChannel == null
                  ? '14 Kanal — Canlı EEG'
                  : '${eeg.selectedChannel} — Canlı EEG',
              subtitle: 'WebSocket · ${EegApiConfig.displayUrl}/ws/live',
              child: EegRealtimeChart(
                history: history,
                selectedChannel: eeg.selectedChannel,
                height: eeg.selectedChannel == null ? 260 : 300,
              ),
            ),
            SectionCard(
              title: 'Anlık Kanal Değerleri',
              subtitle: 'Son EEG örneği',
              child: Column(
                children: [
                  for (final id in sensorIds)
                    _ChannelValueRow(
                      id: id,
                      value: live.eeg[id],
                      selected: eeg.selectedChannel == id,
                      onTap: () => eeg.selectChannel(
                        eeg.selectedChannel == id ? null : id,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  StatusTone _tone(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.connected => StatusTone.success,
      ConnectionStatus.connecting => StatusTone.warning,
      ConnectionStatus.deviceFound => StatusTone.info,
      ConnectionStatus.deviceNotWorn => StatusTone.warning,
      ConnectionStatus.disconnected => StatusTone.danger,
    };
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final Widget child;

  const _MiniStat({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ChannelValueRow extends StatelessWidget {
  const _ChannelValueRow({
    required this.id,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                id,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.text,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
