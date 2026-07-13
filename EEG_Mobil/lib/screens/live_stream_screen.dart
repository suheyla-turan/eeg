import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import '../data/mock_eeg.dart';
import '../data/sensors.dart';
import '../services/eeg_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';

class _StreamSample {
  final DateTime time;
  final Map<String, int> values;
  final int battery;
  final double signal;
  final int overall;

  _StreamSample({
    required this.time,
    required this.values,
    required this.battery,
    required this.signal,
    required this.overall,
  });
}

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final _api = EegApiService();
  final _history = ListQueue<_StreamSample>(60);
  final _log = ListQueue<String>(40);

  Timer? _timer;
  LiveEegState _live = LiveEegState.disconnected();
  String? _error;
  int _packetCount = 0;
  DateTime? _lastPacketAt;
  bool _busy = false;
  bool _fetching = false;

  bool get _collecting => _live.collecting;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _toggleCollection() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_collecting) {
        await _api.stopCollection();
      } else {
        await _api.startCollection();
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Komut gönderilemedi (${EegApiConfig.baseUrl})';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _collecting
                ? 'Durdurulamadı — Python API çalışıyor mu?'
                : 'Başlatılamadı — Python API çalışıyor mu?',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearLog() {
    setState(() {
      _history.clear();
      _log.clear();
      _packetCount = 0;
      _lastPacketAt = null;
    });
  }

  /// Cihaz bağlı ve API canlı veri döndürüyor mu?
  /// Değerler aynı kalsa bile akış devam eder; yalnızca bağlantı kopunca durur.
  /// Bağlı ve Cortex paketi taze mi? (updated_at yaşı ≤ 3 sn)
  bool _hasDataFlow(LiveEegState state) {
    if (state.connection != ConnectionStatus.connected) return false;
    final ts = state.updatedAt;
    if (ts == null) return false;
    final ageSec = DateTime.now().millisecondsSinceEpoch / 1000.0 - ts;
    // Epoch uyumsuzluğu (çok büyük/negatif) → connection alanına güven
    if (ageSec.abs() > 3600 * 24) return true;
    return ageSec <= 3.0;
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final next = await _api.fetchLive();
      if (!mounted) return;

      final flowing = _hasDataFlow(next);

      setState(() {
        _live = next;
        _error = null;

        // Değerler değişmese bile bağlıyken her poll bir örnek sayılır
        if (flowing) {
          _packetCount++;
          final sample = _StreamSample(
            time: DateTime.now(),
            values: Map<String, int>.from(next.rawContactQuality),
            battery: next.batteryPercent,
            signal: next.signal,
            overall: next.overallQuality,
          );
          _lastPacketAt = sample.time;

          _history.addFirst(sample);
          while (_history.length > 50) {
            _history.removeLast();
          }

          final summary = sensorIds
              .map((id) => '$id:${sample.values[id] ?? 0}')
              .join(' ');
          final stamp =
              '${sample.time.hour.toString().padLeft(2, '0')}:'
              '${sample.time.minute.toString().padLeft(2, '0')}:'
              '${sample.time.second.toString().padLeft(2, '0')}.'
              '${(sample.time.millisecond ~/ 10).toString().padLeft(2, '0')}';
          _log.addFirst(
            '[$stamp] bat=${sample.battery}% sig=${sample.signal.toStringAsFixed(1)} '
            'all=${sample.overall} | $summary',
          );
          while (_log.length > 35) {
            _log.removeLast();
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _live = LiveEegState.disconnected(error: e.toString());
        _error = 'API bağlantısı yok (${EegApiConfig.baseUrl})';
      });
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _live.connection == ConnectionStatus.connected;
    final streaming = connected && _collecting;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anlık Veri Akışı',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Başlat ile Python veri toplar; Durdur Cortex’i keser',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _toggleCollection,
                  style: FilledButton.styleFrom(
                    backgroundColor: _collecting
                        ? AppColors.warning
                        : AppColors.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_collecting ? Icons.stop : Icons.play_arrow),
                  label: Text(_collecting ? 'Durdur' : 'Başlat'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _clearLog,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Logu temizle'),
                ),
                const Spacer(),
                Text(
                  !_collecting
                      ? 'Python durdu — Başlat ile devam'
                      : (streaming
                          ? 'Canlı veri alınıyor'
                          : 'Bağlanıyor / cihaz bekleniyor'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !_collecting
                        ? AppColors.warning
                        : (streaming
                            ? AppColors.success
                            : AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8E4E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: AppColors.danger),
                ),
              ),
            if (_collecting && !connected)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF0D4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Veri akışı yok. Headset kapalı veya bağlantı kopmuş olabilir.',
                  style: TextStyle(fontSize: 13, color: AppColors.warning, height: 1.35),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Durum',
                    child: StatusPill(
                      label: !_collecting
                          ? 'Durdu'
                          : (streaming
                              ? 'Akıyor'
                              : (connected ? 'Bekliyor' : 'Bağlanıyor')),
                      tone: !_collecting
                          ? StatusTone.warning
                          : (streaming
                              ? StatusTone.success
                              : (connected
                                  ? StatusTone.info
                                  : StatusTone.warning)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Paket',
                    child: Text(
                      '$_packetCount',
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
                      '${_live.batteryPercent}%',
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
                      _live.signal.toStringAsFixed(1),
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
              title: '14 Kanal — Canlı Değerler',
              subtitle:
                  'Emotiv contact quality (0–4) · genel ${_live.overallQuality}',
              child: Column(
                children: [
                  for (final id in sensorIds)
                    _ChannelStreamRow(
                      id: id,
                      value: _live.rawContactQuality[id] ?? 0,
                      history: _history
                          .map((s) => (s.values[id] ?? 0).toDouble())
                          .toList(),
                    ),
                ],
              ),
            ),
            SectionCard(
              title: 'Paket Günlüğü',
              subtitle: _lastPacketAt == null
                  ? 'Henüz örnek yok'
                  : 'Son örnek: ${_formatTime(_lastPacketAt!)}',
              child: Container(
                width: double.infinity,
                height: 220,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2A33),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _log.isEmpty
                    ? const Center(
                        child: Text(
                          'Veri akışı bekleniyor…',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _log.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _log.elementAt(index),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFFB8E0E8),
                                height: 1.35,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
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

class _ChannelStreamRow extends StatelessWidget {
  final String id;
  final int value;
  final List<double> history;

  const _ChannelStreamRow({
    required this.id,
    required this.value,
    required this.history,
  });

  Color get _color {
    if (value >= 4) return AppColors.qualityGood;
    if (value == 3) return AppColors.qualityFair;
    if (value >= 1) return AppColors.qualityPoor;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              id,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value / 4),
                duration: const Duration(milliseconds: 200),
                builder: (context, v, _) {
                  return LinearProgressIndicator(
                    value: v.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: AppColors.surfaceMuted,
                    color: _color,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 22,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: history.reversed.toList(),
                color: _color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final maxV = 4.0;
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - (values[i].clamp(0, maxV) / maxV) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
