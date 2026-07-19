import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/text_content.dart';
import '../providers/text_content_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

class TextFormScreen extends StatefulWidget {
  const TextFormScreen({super.key, this.existing});

  final TextContent? existing;

  @override
  State<TextFormScreen> createState() => _TextFormScreenState();
}

class _TextFormScreenState extends State<TextFormScreen> {
  static const _difficulties = ['Kolay', 'Orta', 'Zor'];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _duration = TextEditingController();

  String _difficulty = 'Orta';
  bool _active = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _content.text = e.content;
      _duration.text = e.estimatedDuration.toString();
      _difficulty = _difficulties.contains(e.difficulty)
          ? e.difficulty
          : 'Orta';
      _active = e.active;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TextContentProvider>();
    final estimated = int.tryParse(_duration.text.trim()) ?? 0;

    if (_isEdit) {
      final ok = await provider.updateText(
        widget.existing!.copyWith(
          title: _title.text.trim(),
          content: _content.text.trim(),
          difficulty: _difficulty,
          estimatedDuration: estimated,
          active: _active,
        ),
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Güncelleme başarısız'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    } else {
      final created = await provider.create(
        title: _title.text.trim(),
        content: _content.text.trim(),
        difficulty: _difficulty,
        estimatedDuration: estimated,
        active: _active,
      );
      if (!mounted) return;
      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Kayıt başarısız'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<TextContentProvider>().saving;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Metin Düzenle' : 'Metin Ekle'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              SectionCard(
                title: 'Metin Bilgileri',
                child: Column(
                  children: [
                    _field(_title, 'Başlık', required: true),
                    _field(_content, 'İçerik', required: true, maxLines: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _difficulty,
                        decoration: _decoration('Zorluk'),
                        items: _difficulties
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(d),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _difficulty = v);
                        },
                      ),
                    ),
                    _field(
                      _duration,
                      'Tahmini süre (saniye)',
                      required: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktif'),
                      value: _active,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: _decoration(label),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null
            : null,
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
