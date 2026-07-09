import 'dart:async';

import 'package:flutter/material.dart';
import '../data/mock_eeg.dart';
import '../services/eeg_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/brain_map.dart';
import '../widgets/contact_quality_grid.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';

class LiveEegScreen extends StatefulWidget {
  const LiveEegScreen({super.key});

  @override
  State<LiveEegScreen> createState() => _LiveEegScreenState();
}

class _LiveEegScreenState extends State<LiveEegScreen> {
  final _api = EegApiService();
  Timer? _timer;
  LiveEegState _live = LiveEegState.disconnected();
  String? _lastError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    logApiHost();
    _refresh();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final next = await _api.fetchLive();
      if (!mounted) return;
      setState(() {
        _live = next;
        _lastError = next.error;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _live = LiveEegState.disconnected(error: e.toString());
        _lastError = 'Python API\'ye ulaşılamadı (${EegApiConfig.baseUrl})';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const Text(
                'Canlı EEG Durumu',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Python / Emotiv Cortex üzerinden anlık veri',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (_lastError != null &&
                  _live.connection != ConnectionStatus.connected)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8E4E4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _lastError!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.danger,
                      height: 1.35,
                    ),
                  ),
                ),
              if (_live.connection == ConnectionStatus.connected)
                const SizedBox.shrink()
              else if (_lastError == null ||
                  !_lastError!.contains('ulaşılamadı'))
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF0D4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _live.error ??
                        'API açık ama headset bağlı değil. Emotiv cihazını aç.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.warning,
                      height: 1.35,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Bağlantı',
                      child: StatusPill(
                        label: _connectionLabel(_live.connection),
                        tone: _connectionTone(_live.connection),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Pil',
                      child: Text(
                        '${_live.batteryPercent}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Sensör',
                      child: Text(
                        '${_live.sensorCount}',
                        style: const TextStyle(
                          fontSize: 22,
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
                title: 'Beyin Haritası',
                subtitle:
                    'Temas kalitesine göre aktivite · sinyal ${_live.signal.toStringAsFixed(1)}',
                child: BrainMap(
                  quality: _live.contactQuality,
                  bandPower: _live.bandPower,
                ),
              ),
              SectionCard(
                title: 'Temas Kalitesi',
                subtitle:
                    'Emotiv contact quality (0–4) · genel ${_live.overallQuality}',
                child: ContactQualityGrid(quality: _live.contactQuality),
              ),
              Text(
                'API: ${EegApiConfig.baseUrl}/live · 500 ms yenileme',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _connectionLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Bağlı';
      case ConnectionStatus.connecting:
        return 'Bağlanıyor…';
      case ConnectionStatus.disconnected:
        return 'Bağlı değil';
    }
  }

  StatusTone _connectionTone(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return StatusTone.success;
      case ConnectionStatus.connecting:
        return StatusTone.warning;
      case ConnectionStatus.disconnected:
        return StatusTone.danger;
    }
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
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
