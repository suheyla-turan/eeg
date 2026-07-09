import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/eeg_session_controller.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.device,
    required this.connectionState,
    this.errorMessage,
  });

  final DeviceStatus device;
  final ServerConnectionState connectionState;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReady = connectionState == ServerConnectionState.connected && device.connected;

    final Color background;
    final IconData icon;
    final String title;
    final String subtitle;

    if (connectionState == ServerConnectionState.connecting) {
      background = Colors.orange.shade50;
      icon = Icons.sync;
      title = 'Sunucuya bağlanılıyor';
      subtitle = 'Backend bekleniyor';
    } else if (isReady) {
      background = Colors.green.shade50;
      icon = Icons.sensors;
      title = 'EEG cihazı aktif';
      subtitle = device.headsetId ?? 'Veri akışı devam ediyor';
    } else if (connectionState == ServerConnectionState.error) {
      background = Colors.red.shade50;
      icon = Icons.error_outline;
      title = 'Bağlantı sorunu';
      subtitle = errorMessage ?? 'Sunucuya ulaşılamıyor';
    } else {
      background = Colors.blueGrey.shade50;
      icon = Icons.bluetooth_disabled;
      title = 'Cihaz bekleniyor';
      subtitle = device.message ?? 'Emotiv Cortex bağlantısı kurulmadı';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
