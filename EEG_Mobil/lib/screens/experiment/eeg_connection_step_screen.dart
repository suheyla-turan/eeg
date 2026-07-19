import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_eeg.dart';
import '../../providers/eeg_provider.dart';
import '../../providers/experiment_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/experiment_scaffold.dart';
import '../../widgets/section_card.dart';

/// EEG bağlantı adımı — uygulama teması içinde modern bağlantı kartı.
/// Gerçek bağlantı `EegProvider` üzerinden izlenir; adımlar yalnızca UX.
class EegConnectionStepScreen extends StatefulWidget {
  const EegConnectionStepScreen({super.key});

  @override
  State<EegConnectionStepScreen> createState() =>
      _EegConnectionStepScreenState();
}

class _EegConnectionStepScreenState extends State<EegConnectionStepScreen> {
  static const _labels = <String>[
    'Cihaza bağlanılıyor...',
    'Yetkilendiriliyor...',
    'Session oluşturuluyor...',
    'EEG verileri hazırlanıyor...',
    'Deney hazır.',
  ];

  int _visualStep = 0;
  bool _autoAdvanced = false;
  bool _finishing = false;
  Timer? _finishTimer;
  EegProvider? _eeg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eeg = context.read<EegProvider>();
      _eeg = eeg;
      eeg.addListener(_onEegChanged);
      if (!eeg.canStartExperiment) {
        unawaited(eeg.reconnect());
      }
      _onEegChanged();
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _eeg?.removeListener(_onEegChanged);
    super.dispose();
  }

  void _onEegChanged() {
    final eeg = _eeg;
    if (eeg == null || !mounted || _finishing || _autoAdvanced) return;

    final mapped = _mapConnectionToStep(eeg);
    if (mapped > _visualStep) {
      setState(() => _visualStep = mapped);
    }

    if (eeg.canStartExperiment) {
      _runFinishSequence();
    }
  }

  int _mapConnectionToStep(EegProvider eeg) {
    if (eeg.canStartExperiment) return 3;
    switch (eeg.connection) {
      case ConnectionStatus.connecting:
        return 0;
      case ConnectionStatus.deviceFound:
        return 1;
      case ConnectionStatus.deviceNotWorn:
        return 2;
      case ConnectionStatus.connected:
        return 3;
      case ConnectionStatus.disconnected:
        return 0;
    }
  }

  void _runFinishSequence() {
    if (_autoAdvanced || _finishing) return;
    _finishing = true;

    var step = _visualStep.clamp(0, 3);
    void tick() {
      if (!mounted) return;
      if (step < 4) {
        setState(() {
          step++;
          _visualStep = step;
        });
        _finishTimer = Timer(const Duration(milliseconds: 550), tick);
        return;
      }
      _autoAdvanced = true;
      context.read<ExperimentProvider>().manager.proceedFromEegConnection();
    }

    tick();
  }

  @override
  Widget build(BuildContext context) {
    final eeg = context.watch<EegProvider>();
    final scheme = Theme.of(context).colorScheme;
    final connected = eeg.canStartExperiment;

    return ExperimentScaffold(
      title: 'EEG Bağlantısı',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bağlantı kuruluyor',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              eeg.isDemoMode
                  ? 'Demo modu açık — sahte EEG ile deneye devam edilecek.'
                  : 'EEG cihazı bağlandığında deney otomatik olarak devam eder.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondary(context),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: SingleChildScrollView(
                child: SectionCard(
                  title: 'Bağlantı Adımları',
                  subtitle: connected
                      ? (eeg.isDemoMode ? 'Bağlı (Demo)' : 'Bağlı')
                      : eeg.connectionLabel,
                  icon: connected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_searching,
                  child: Column(
                    children: [
                      for (var i = 0; i < _labels.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _ConnectionStepRow(
                          label: _labels[i],
                          status: i < _visualStep
                              ? _StepStatus.done
                              : i == _visualStep
                                  ? (_visualStep >= 4
                                      ? _StepStatus.done
                                      : _StepStatus.active)
                                  : _StepStatus.pending,
                        ),
                      ],
                      if (eeg.live.batteryPercent > 0) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Icon(Icons.battery_charging_full,
                                size: 18, color: scheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Batarya: ${eeg.live.batteryPercent}%',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _finishing
                  ? null
                  : () {
                      setState(() {
                        _visualStep = 0;
                        _finishing = false;
                        _autoAdvanced = false;
                      });
                      eeg.reconnect();
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Bağlan'),
            ),
            if (connected && !_autoAdvanced) ...[
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  _autoAdvanced = true;
                  context
                      .read<ExperimentProvider>()
                      .manager
                      .proceedFromEegConnection();
                },
                child: const Text('Devam Et'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _StepStatus { pending, active, done }

class _ConnectionStepRow extends StatelessWidget {
  const _ConnectionStepRow({
    required this.label,
    required this.status,
  });

  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget leading;
    switch (status) {
      case _StepStatus.done:
        leading = Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 18),
        );
      case _StepStatus.active:
        leading = SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: scheme.primary,
          ),
        );
      case _StepStatus.pending:
        leading = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line(context), width: 2),
          ),
        );
    }

    final isActive = status == _StepStatus.active;
    final isDone = status == _StepStatus.done;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: status == _StepStatus.pending ? 0.55 : 1,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight:
                    isActive || isDone ? FontWeight.w700 : FontWeight.w500,
                color: isDone
                    ? AppColors.success
                    : isActive
                        ? AppColors.foreground(context)
                        : AppColors.secondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
