import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_messenger.dart';
import '../core/app_page_route.dart';
import '../models/participant.dart';
import '../providers/eeg_provider.dart';
import '../providers/experiment_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import 'experiment/experiment_flow_screen.dart';
import 'experiment_session_screen.dart';
import 'reading_experiment_screen.dart';

class NewParticipantScreen extends StatefulWidget {
  const NewParticipantScreen({
    super.key,
    this.existingParticipant,
    this.embeddedInShell = false,
  });

  /// Kayıt sonrası gelen katılımcı — form atlanır, deney tipi seçilir.
  final Participant? existingParticipant;
  final bool embeddedInShell;

  @override
  State<NewParticipantScreen> createState() => _NewParticipantScreenState();
}

class _NewParticipantScreenState extends State<NewParticipantScreen> {
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
  final _occupation = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _birthDate;
  String _gender = 'Kadın';
  String? _education;
  String? _socialMedia;
  String? _sleep;
  String _dominantHand = 'Sağ';
  bool _visionProblem = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExperimentProvider>().loadMediaOptions();
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _occupation.dispose();
    _notes.dispose();
    super.dispose();
  }

  int _ageFromBirthDate(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  bool get _hasExisting => widget.existingParticipant != null;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    var temp = _birthDate ?? DateTime(now.year - 20, now.month, now.day);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Doğum tarihi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground(context),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _birthDate = temp);
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Tamam',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: temp,
                    minimumDate: DateTime(1920),
                    maximumDate: now,
                    onDateTimeChanged: (d) => temp = d,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final provider = context.read<ExperimentProvider>();
    final eeg = context.read<EegProvider>();
    if (provider.experimentType == 'live_eeg' && !eeg.canStartExperiment) {
      AppMessenger.error(
        'EEG cihazı bağlı değil (durum: ${eeg.connectionLabel}). '
        'Deney başlatılamaz.',
      );
      return;
    }

    final bool ok;
    setState(() => _submitting = true);

    if (_hasExisting) {
      ok = await provider.createExperimentForParticipant(
        widget.existingParticipant!,
      );
    } else {
      if (!_formKey.currentState!.validate()) {
        setState(() => _submitting = false);
        return;
      }
      if (_birthDate == null) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doğum tarihi seçin'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final draft = Participant(
        participantId: '',
        participantCode: '',
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        gender: _gender,
        age: _ageFromBirthDate(_birthDate!),
        birthDate: _birthDate,
        education: _education!,
        occupation: _occupation.text.trim(),
        dailySocialMediaUsage: _socialMedia!,
        dominantHand: _dominantHand,
        visionProblem: _visionProblem,
        sleepDuration: _sleep!,
        notes: _notes.text.trim(),
        createdAt: DateTime.now(),
      );
      ok = await provider.createParticipantAndExperiment(draft);
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      AppMessenger.error(provider.errorMessage ?? 'Kayıt başarısız');
      return;
    }

    final Widget sessionPage;
    switch (provider.experimentType) {
      case 'live_eeg':
        sessionPage = const ExperimentSessionScreen();
      case 'text':
        sessionPage = const ReadingExperimentScreen();
      default:
        sessionPage = const ExperimentFlowScreen();
    }

    await Navigator.of(context).push(
      AppPageRoute<void>(
        transition: AppTransition.sharedAxisX,
        builder: (_) => sessionPage,
      ),
    );
  }

  Widget _eegBanner(EegProvider eeg) {
    final ok = eeg.canStartExperiment;
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok
            ? (isDark ? const Color(0xFF1A3328) : const Color(0xFFE4F5EB))
            : (isDark ? const Color(0xFF332A14) : const Color(0xFFFBF0D4)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: ok ? AppColors.success : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'EEG bağlı — deney başlatılabilir'
                  : 'EEG: ${eeg.connectionLabel} — deney başlatılamaz',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ok ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _experimentTypeCard(ExperimentProvider exp) {
    return SectionCard(
      title: 'Deney Tipi',
      icon: Icons.science_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'full', label: Text('Tam Deney')),
              ButtonSegment(value: 'live_eeg', label: Text('Canlı EEG')),
              ButtonSegment(value: 'text', label: Text('Metin')),
            ],
            selected: {
              exp.experimentType == 'full_protocol' ||
                      exp.experimentType == 'video'
                  ? 'full'
                  : exp.experimentType,
            },
            onSelectionChanged: (s) => exp.setExperimentType(s.first),
          ),
          if (exp.experimentType == 'full' ||
              exp.experimentType == 'full_protocol' ||
              exp.experimentType == 'video') ...[
            const SizedBox(height: 12),
            Text(
              'Tam akış: EEG bağlantısı → bilgilendirme → '
              'Reels (10 dk) → metin (10 dk) → analiz → sonuçlar.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondary(context),
                height: 1.35,
              ),
            ),
            if (exp.texts.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: exp.selectedTextId,
                isExpanded: true,
                decoration: _decoration('Okuma metni'),
                items: exp.texts
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.textId,
                        child: Text(
                          t.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: exp.setSelectedText,
              ),
            ],
          ],
          if (exp.experimentType == 'text' && exp.texts.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: exp.selectedTextId,
              isExpanded: true,
              decoration: _decoration('Metin seçin'),
              items: exp.texts
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.textId,
                      child: Text(
                        t.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: exp.setSelectedText,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exp = context.watch<ExperimentProvider>();
    final eeg = context.watch<EegProvider>();
    final dateFmt = DateFormat('d MMMM yyyy', 'tr');
    final existing = widget.existingParticipant;

    final content = Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          widget.embeddedInShell ? 12 : 20,
          20,
          32,
        ),
        children: [
          if (!widget.embeddedInShell) ...[
            Text(
              _hasExisting ? 'Deney Başlat' : 'Yeni Katılımcı',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground(context),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            _hasExisting
                ? 'Katılımcı hazır. Deney tipini seçip başlatabilirsiniz.'
                : 'Deneyden önce katılımcı bilgilerini girin. Kayıt sonrası '
                    'otomatik experiment oluşturulur.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _eegBanner(eeg),
          const SizedBox(height: 18),
          if (_hasExisting)
            SectionCard(
              title: 'Katılımcı',
              subtitle: 'Az önce kaydedildi',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.softPrimary(context),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    existing!.firstName.isNotEmpty
                        ? existing.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(
                  existing.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${existing.participantCode} · ${existing.age} yaş',
                ),
              ),
            )
          else ...[
            SectionCard(
              title: 'Kişisel Bilgiler',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  _field(_firstName, 'Ad', required: true),
                  _field(_lastName, 'Soyad', required: true),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FormField<DateTime>(
                      validator: (_) =>
                          _birthDate == null ? 'Doğum tarihi seçin' : null,
                      builder: (state) {
                        return InkWell(
                          onTap: _pickBirthDate,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: _decoration(
                              'Doğum tarihi',
                              hint: 'Kaydırarak seçin',
                            ).copyWith(
                              errorText: state.errorText,
                              suffixIcon: Icon(
                                Icons.calendar_month_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            child: Text(
                              _birthDate == null
                                  ? 'Kaydırarak seçin'
                                  : '${dateFmt.format(_birthDate!)}'
                                      '  ·  ${_ageFromBirthDate(_birthDate!)} yaş',
                              style: TextStyle(
                                fontSize: 15,
                                color: _birthDate == null
                                    ? AppColors.hint(context)
                                    : AppColors.foreground(context),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                    onChanged: (v) => setState(() => _education = v),
                  ),
                  _field(_occupation, 'Meslek', required: true),
                ],
              ),
            ),
            SectionCard(
              title: 'EEG Bilgileri',
              subtitle: 'Ölçümü etkileyebilecek özellikler',
              icon: Icons.monitor_heart_outlined,
              child: Column(
                children: [
                  _dropdown(
                    label: 'Baskın El',
                    value: _dominantHand,
                    items: const ['Sağ', 'Sol', 'Her ikisi'],
                    onChanged: (v) => setState(() => _dominantHand = v!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Gözlük kullanıyor mu?',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.foreground(context),
                      ),
                    ),
                    value: _visionProblem,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) => setState(() => _visionProblem = v),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Alışkanlıklar',
              icon: Icons.schedule_outlined,
              child: Column(
                children: [
                  _nullableDropdown(
                    label: 'Günlük Sosyal Medya Kullanımı',
                    value: _socialMedia,
                    items: _socialMediaOptions,
                    onChanged: (v) => setState(() => _socialMedia = v),
                  ),
                  _nullableDropdown(
                    label: 'Günlük Uyku Süresi',
                    value: _sleep,
                    items: _sleepOptions,
                    onChanged: (v) => setState(() => _sleep = v),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Ek Notlar',
              icon: Icons.notes_outlined,
              child: _field(_notes, 'Notlar', maxLines: 3),
            ),
          ],
          _experimentTypeCard(exp),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _hasExisting
                        ? Icons.play_arrow_rounded
                        : Icons.person_add_alt_1,
                  ),
            label: Text(
              _submitting
                  ? 'Hazırlanıyor…'
                  : _hasExisting
                      ? 'Deneyi Başlat'
                      : 'Kaydet ve Deneye Başla',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bugün · ${dateFmt.format(DateTime.now())}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.hint(context),
            ),
          ),
        ],
      ),
    );

    if (widget.embeddedInShell) {
      return content;
    }

    return Scaffold(body: SafeArea(child: content));
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: _decoration(label, hint: hint),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null
            : null,
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
