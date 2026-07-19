import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Ortak duygu sorusu: birden fazla chip + Diğer (serbest metin).
class MoodQuestionPanel extends StatefulWidget {
  const MoodQuestionPanel({
    super.key,
    required this.subtitle,
    required this.onSubmit,
    this.submitLabel = 'Devam Et',
    this.submitting = false,
  });

  final String subtitle;
  final String submitLabel;
  final bool submitting;
  final Future<void> Function(List<String> moodOptions, String? moodOtherText)
      onSubmit;

  /// Videolar / metin sonrası ortak duygu seçenekleri.
  static const options = <String>[
    'Mutlu',
    'Heyecanlı',
    'Sakin',
    'Nötr',
    'Meraklı',
    'Şaşkın',
    'Yorgun',
    'Sıkılmış',
    'Stresli',
    'Endişeli',
    'Üzgün',
    'Kızgın',
    'Diğer',
  ];

  static const otherLabel = 'Diğer';

  @override
  State<MoodQuestionPanel> createState() => _MoodQuestionPanelState();
}

class _MoodQuestionPanelState extends State<MoodQuestionPanel> {
  final Set<String> _selected = {};
  bool _emotionsExpanded = true;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _hasOther => _selected.contains(MoodQuestionPanel.otherLabel);

  bool get _canSubmit {
    if (_selected.isEmpty || widget.submitting) return false;
    if (_hasOther && _otherController.text.trim().isEmpty) return false;
    return true;
  }

  void _toggle(String option) {
    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
      } else {
        _selected.add(option);
      }
    });
  }

  String get _selectionSummary {
    if (_selected.isEmpty) {
      return _emotionsExpanded
          ? 'Bir veya birden fazla duygu seçin'
          : 'Listeyi açıp duygu seçin';
    }
    final labels = _selected
        .where((o) => o != MoodQuestionPanel.otherLabel)
        .toList();
    if (_hasOther) {
      labels.add('Diğer');
    }
    if (labels.length == 1) return 'Seçim: ${labels.first}';
    return 'Seçimler (${labels.length}): ${labels.join(', ')}';
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (_hasOther && _otherController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen nasıl hissettiğinizi yazın'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Sabit seçenek sırasını koru.
    final ordered = MoodQuestionPanel.options
        .where(_selected.contains)
        .toList(growable: false);

    await widget.onSubmit(
      ordered,
      _hasOther ? _otherController.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nasıl hissediyorsun?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: TextStyle(
              color: AppColors.secondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListView(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line(context)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      maintainState: true,
                      onExpansionChanged: (open) =>
                          setState(() => _emotionsExpanded = open),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      leading: Icon(
                        Icons.sentiment_satisfied_alt_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(
                        'Duygular',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground(context),
                        ),
                      ),
                      subtitle: Text(
                        _selectionSummary,
                        style: TextStyle(
                          color: AppColors.secondary(context),
                          fontSize: 13,
                        ),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in MoodQuestionPanel.options)
                              _EmotionChip(
                                label: option,
                                selected: _selected.contains(option),
                                onTap: () => _toggle(option),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_hasOther) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otherController,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nasıl hissettiğinizi yazın',
                      hintText: 'Kısaca belirtin…',
                    ),
                  ),
                ],
              ],
            ),
          ),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
            ),
            child: widget.submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

class _EmotionChip extends StatelessWidget {
  const _EmotionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? scheme.onPrimary
              : AppColors.foreground(context),
        ),
      ),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: scheme.onPrimary,
      selectedColor: scheme.primary,
      backgroundColor: AppColors.muted(context),
      side: BorderSide(
        color: selected ? scheme.primary : AppColors.line(context),
      ),
      onSelected: (_) => onTap(),
    );
  }
}
