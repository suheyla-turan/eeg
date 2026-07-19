import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/participant.dart';
import '../providers/participant_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';

/// Katılımcı kayıt ekranı — yalnızca Firestore'a kaydeder.
class ParticipantRegistrationScreen extends StatefulWidget {
  const ParticipantRegistrationScreen({
    super.key,
    this.embeddedInShell = false,
    this.onRegistered,
  });

  final bool embeddedInShell;
  final ValueChanged<Participant>? onRegistered;

  @override
  State<ParticipantRegistrationScreen> createState() =>
      _ParticipantRegistrationScreenState();
}

class _ParticipantRegistrationScreenState
    extends State<ParticipantRegistrationScreen> {
  static const _educationOptions = [
    'İlkokul',
    'Ortaokul',
    'Lise',
    'Ön Lisans',
    'Lisans',
    'Yüksek Lisans',
    'Doktora',
    'Okuryazar değil',
    'Diğer',
  ];

  static const _socialMediaOptions = [
    'Kullanmıyor',
    '30 dakikadan az',
    '30 dk – 1 saat',
    '1 – 2 saat',
    '2 – 3 saat',
    '3 – 4 saat',
    '4 – 6 saat',
    '6 saatten fazla',
  ];

  static const _sleepOptions = [
    '4 saatten az',
    '4 – 5 saat',
    '5 – 6 saat',
    '6 – 7 saat',
    '7 – 8 saat',
    '8 – 9 saat',
    '9 – 10 saat',
    '10 saatten fazla',
  ];

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _occupation = TextEditingController();
  final _notes = TextEditingController();

  String _gender = 'Kadın';
  String? _education;
  String? _socialMedia;
  String? _sleep;
  String _dominantHand = 'Sağ';
  bool _visionProblem = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParticipantProvider>().prepareRegistration();
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _occupation.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ParticipantProvider>();
    final age = int.parse(_age.text.trim());

    final draft = Participant(
      participantId: '',
      participantCode: provider.nextCode ?? '',
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      gender: _gender,
      age: age,
      education: _education!,
      occupation: _occupation.text.trim(),
      dailySocialMediaUsage: _socialMedia!,
      dominantHand: _dominantHand,
      visionProblem: _visionProblem,
      sleepDuration: _sleep!,
      notes: _notes.text.trim(),
      createdAt: DateTime.now(),
    );

    final participant = await provider.save(draft);
    if (!mounted) return;

    if (participant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Kayıt başarısız'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kaydedildi: ${participant.participantCode} · ${participant.fullName}',
        ),
        backgroundColor: AppColors.success,
      ),
    );

    if (widget.onRegistered != null) {
      widget.onRegistered!(participant);
      return;
    }

    _formKey.currentState!.reset();
    _firstName.clear();
    _lastName.clear();
    _age.clear();
    _occupation.clear();
    _notes.clear();
    setState(() {
      _gender = 'Kadın';
      _education = null;
      _socialMedia = null;
      _sleep = null;
      _dominantHand = 'Sağ';
      _visionProblem = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParticipantProvider>();
    final code = provider.nextCode ?? '…';
    final scheme = Theme.of(context).colorScheme;

    final form = provider.loading && provider.nextCode == null
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (widget.embeddedInShell) ...[
                  Text(
                    'Kayıt tamamlanınca otomatik olarak deney başlatma '
                    'ekranına geçilir.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondary(context),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 14),
                ],
                SectionCard(
                  title: 'Katılımcı Kodu',
                  subtitle: 'Otomatik oluşturulur',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softPrimary(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line(context)),
                    ),
                    child: Text(
                      code,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                    SectionCard(
                      title: 'Kişisel Bilgiler',
                      child: Column(
                        children: [
                          _field(_firstName, 'Ad', required: true),
                          _field(_lastName, 'Soyad', required: true),
                          _field(
                            _age,
                            'Yaş',
                            required: true,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Zorunlu alan';
                              }
                              final n = int.tryParse(v.trim());
                              if (n == null || n < 1 || n > 120) {
                                return 'Geçerli bir yaş girin';
                              }
                              return null;
                            },
                          ),
                          _dropdown(
                            label: 'Cinsiyet',
                            value: _gender,
                            items: const ['Kadın', 'Erkek', 'Diğer'],
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                          _nullableDropdown(
                            label: 'Eğitim Durumu',
                            value: _education,
                            items: _educationOptions,
                            onChanged: (v) =>
                                setState(() => _education = v),
                          ),
                          _field(_occupation, 'Meslek', required: true),
                        ],
                      ),
                    ),
                    SectionCard(
                      title: 'Alışkanlıklar ve Notlar',
                      child: Column(
                        children: [
                          _nullableDropdown(
                            label: 'Günlük Sosyal Medya Kullanımı',
                            value: _socialMedia,
                            items: _socialMediaOptions,
                            onChanged: (v) =>
                                setState(() => _socialMedia = v),
                          ),
                          _dropdown(
                            label: 'Baskın El',
                            value: _dominantHand,
                            items: const ['Sağ', 'Sol', 'Her ikisi'],
                            onChanged: (v) =>
                                setState(() => _dominantHand = v!),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Gözlük Kullanımı',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.foreground(context),
                              ),
                            ),
                            value: _visionProblem,
                            activeColor: AppColors.primary,
                            onChanged: (v) =>
                                setState(() => _visionProblem = v),
                          ),
                          _nullableDropdown(
                            label: 'Uyku Süresi',
                            value: _sleep,
                            items: _sleepOptions,
                            onChanged: (v) => setState(() => _sleep = v),
                          ),
                          _field(_notes, 'Notlar', maxLines: 3),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: provider.saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: provider.saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        provider.saving
                            ? 'Kaydediliyor…'
                            : 'Kaydet ve Deneye Geç',
                      ),
                    ),
              ],
            ),
          );

    if (widget.embeddedInShell) {
      return form;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Katılımcı Kaydı')),
      body: SafeArea(child: form),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _decoration(label, hint: hint),
        validator: validator ??
            (required
                ? (v) =>
                    (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null
                : null),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: _decoration(label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _nullableDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: _decoration(label),
        hint: const Text('Seçiniz'),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null || v.isEmpty ? 'Seçim yapın' : null,
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.muted(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.line(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.line(context)),
      ),
    );
  }
}
