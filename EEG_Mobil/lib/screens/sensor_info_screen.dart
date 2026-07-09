import 'package:flutter/material.dart';
import '../data/sensors.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

class SensorInfoScreen extends StatefulWidget {
  const SensorInfoScreen({super.key});

  @override
  State<SensorInfoScreen> createState() => _SensorInfoScreenState();
}

class _SensorInfoScreenState extends State<SensorInfoScreen> {
  final _queryController = TextEditingController();
  String? _selectedId;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<SensorInfo> get _filtered {
    final q = _queryController.text.trim().toLowerCase();
    if (q.isEmpty) return sensors;
    return sensors.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.region.toLowerCase().contains(q) ||
          s.measures.toLowerCase().contains(q) ||
          s.function.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedId == null
        ? null
        : sensors.where((s) => s.id == _selectedId).firstOrNull;
    final list = selected != null ? [selected] : _filtered;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Sensör Bilgileri',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AF3, F7, O1, T7 ve diğer kanalların anatomik / işlevsel açıklamaları',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Sensör ara (ör. AF3, temporal, görsel…)',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sensors.map((s) {
                final active = _selectedId == s.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedId = active ? null : s.id;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      s.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ...list.map(_SensorDetail.new),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'Eşleşen sensör bulunamadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SensorDetail extends StatelessWidget {
  final SensorInfo sensor;

  const _SensorDetail(this.sensor);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: sensor.name,
      subtitle: '${sensor.region} · ${sensor.hemisphere}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Block(label: 'Ne ölçer?', text: sensor.measures),
          _Block(label: 'İşlev', text: sensor.function),
          _Block(label: 'Anatomi', text: sensor.anatomy),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final String label;
  final String text;

  const _Block({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.text,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
