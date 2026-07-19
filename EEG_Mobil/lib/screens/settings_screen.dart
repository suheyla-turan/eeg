import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_messenger.dart';
import '../core/responsive.dart';
import '../data/mock_eeg.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/section_card.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _hostCtrl = TextEditingController(text: s.apiHostOverride ?? '');
    _portCtrl = TextEditingController(text: '${s.wsPort}');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNetwork() async {
    final settings = context.read<SettingsProvider>();
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port < 1 || port > 65535) {
      AppMessenger.error('Geçerli bir port girin (1–65535)');
      return;
    }
    await settings.setApiHostOverride(host.isEmpty ? null : host);
    await settings.setWsPort(port);
    AppMessenger.success('Ağ ayarları kaydedildi');
  }

  Color _connectionColor(ConnectionStatus status) => switch (status) {
        ConnectionStatus.connected => AppColors.success,
        ConnectionStatus.connecting => AppColors.warning,
        ConnectionStatus.deviceFound ||
        ConnectionStatus.deviceNotWorn =>
          AppColors.warning,
        _ => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.embeddedInShell
          ? null
          : AppBar(title: const Text('Ayarlar')),
      body: ResponsiveBody(
        child: ListView(
          children: [
            SectionCard(
              title: 'Python API',
              subtitle: 'REST ve WebSocket adresi',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Aktif adres',
                    value: settings.apiDisplayUrl,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Çözülen host',
                    value: settings.apiDisplayHost,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Host override (boş = otomatik)',
                      hintText: 'örn. 192.168.1.20',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _portCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'WebSocket / API portu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _saveNetwork,
                      child: const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Demo / Test modu',
              subtitle: 'Cihaz ve Python API olmadan deneme',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Demo modu'),
                subtitle: Text(
                  settings.demoMode
                      ? 'Sahte EEG akışı açık — tüm ekranları test edebilirsiniz'
                      : 'Kapalıyken gerçek Emotiv / Python API gerekir',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                value: settings.demoMode,
                onChanged: (v) async {
                  await settings.setDemoMode(v);
                  AppMessenger.success(
                    v ? 'Demo modu açıldı' : 'Demo modu kapatıldı',
                  );
                },
              ),
            ),
            SectionCard(
              title: 'EEG Bağlantısı',
              subtitle: settings.eegConnectionLabel,
              right: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: settings.demoMode
                      ? AppColors.primary
                      : _connectionColor(settings.live.connection),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Durum',
                    value: settings.eegConnectionLabel,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Toplama',
                    value: settings.live.collecting ? 'Açık' : 'Kapalı',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Pil',
                    value: settings.live.batteryPercent > 0
                        ? '%${settings.live.batteryPercent}'
                        : '—',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: settings.demoMode
                        ? null
                        : () async {
                            await settings.reconnectEeg();
                            AppMessenger.info('EEG yeniden bağlanıyor…');
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      settings.demoMode ? 'Demo aktif' : 'Yeniden Bağlan',
                    ),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Firebase',
              child: _InfoRow(
                label: 'Durum',
                value: settings.firebaseStatusLabel,
              ),
            ),
            SectionCard(
              title: 'Görünüm',
              subtitle: 'Tema tercihi',
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistem'),
                    icon: Icon(Icons.brightness_auto, size: 18),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Açık'),
                    icon: Icon(Icons.light_mode, size: 18),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Koyu'),
                    icon: Icon(Icons.dark_mode, size: 18),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (v) {
                  settings.setThemeMode(v.first);
                },
              ),
            ),
            SectionCard(
              title: 'Sistem Logları',
              subtitle: 'Python · EEG · Firebase · Deney · Hatalar',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.terminal, color: scheme.primary),
                title: const Text('Logları görüntüle'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LogsScreen(),
                    ),
                  );
                },
              ),
            ),
            SectionCard(
              title: 'Versiyon',
              child: _InfoRow(
                label: 'Uygulama',
                value: settings.versionLabel,
              ),
            ),
            SectionCard(
              title: 'Hakkında',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EEG Araştırma',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tek cihaz araştırma modu. Firebase Auth kullanılmaz. '
                    'Mimari: Repository Pattern + Provider. '
                    'EEG verileri Python API üzerinden WebSocket ile alınır; '
                    'deney kayıtları Firestore ve Storage\'a yazılır.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const _InfoRow(label: 'Giriş', value: 'Kapalı (Auth yok)'),
                  const SizedBox(height: 6),
                  const _InfoRow(
                    label: 'Null Safety',
                    value: 'Aktif',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}
