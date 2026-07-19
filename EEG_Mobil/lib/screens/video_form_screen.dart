import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/content_category.dart';
import '../models/video_content.dart';
import '../providers/video_content_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

class VideoFormScreen extends StatefulWidget {
  const VideoFormScreen({super.key, this.existing});

  final VideoContent? existing;

  @override
  State<VideoFormScreen> createState() => _VideoFormScreenState();
}

class _VideoFormScreenState extends State<VideoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  final _picker = ImagePicker();

  String _category = ContentCategory.all.first;
  bool _active = true;
  File? _videoFile;
  File? _thumbnailFile;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _description.text = e.description;
      _duration.text = e.duration.toString();
      _category = ContentCategory.all.contains(e.category)
          ? e.category
          : ContentCategory.all.first;
      _active = e.active;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    setState(() => _videoFile = File(x.path));
  }

  Future<void> _pickThumbnail() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() => _thumbnailFile = File(x.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir video dosyası seçin'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final provider = context.read<VideoContentProvider>();
    final duration = int.tryParse(_duration.text.trim()) ?? 0;

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        duration: duration,
        active: _active,
      );
      final ok = await provider.updateVideo(
        video: updated,
        newVideoFile: _videoFile,
        newThumbnailFile: _thumbnailFile,
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
        description: _description.text.trim(),
        category: _category,
        duration: duration,
        active: _active,
        videoFile: _videoFile!,
        thumbnailFile: _thumbnailFile,
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
    final saving = context.watch<VideoContentProvider>().saving;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Video Düzenle' : 'Video Ekle'),
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
                title: 'Video Bilgileri',
                child: Column(
                  children: [
                    _field(_title, 'Başlık', required: true),
                    _field(_description, 'Açıklama', maxLines: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: _decoration('Kategori'),
                        items: ContentCategory.all
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                    ),
                    _field(
                      _duration,
                      'Süre (saniye)',
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
              SectionCard(
                title: 'Dosyalar',
                subtitle: _isEdit
                    ? 'Yeni dosya seçerseniz mevcut dosyanın yerine yüklenir.'
                    : 'Video Firebase Storage\'a yüklenir.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving ? null : _pickVideo,
                      icon: const Icon(Icons.video_file_outlined),
                      label: Text(
                        _videoFile != null
                            ? 'Video seçildi'
                            : (_isEdit
                                ? 'Videoyu değiştir (opsiyonel)'
                                : 'Video seç'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: saving ? null : _pickThumbnail,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _thumbnailFile != null
                            ? 'Küçük resim seçildi'
                            : 'Küçük resim seç (opsiyonel)',
                      ),
                    ),
                    if (widget.existing?.thumbnail != null &&
                        _thumbnailFile == null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.existing!.thumbnail!,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
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
