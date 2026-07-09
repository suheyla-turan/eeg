import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/eeg_session_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostController;

  @override
  void initState() {
    super.initState();
    final controller = context.read<EegSessionController>();
    _hostController = TextEditingController(text: controller.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _saveAndReconnect() async {
    final controller = context.read<EegSessionController>();
    controller.updateHost(_hostController.text);
    await controller.connect();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sunucu adresi güncellendi')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EegSessionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Backend Sunucu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Android emülatörde bilgisayarınız için 10.0.2.2 kullanın. '
            'Gerçek telefonda bilgisayarınızın yerel IP adresini girin.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Sunucu IP / Host',
              hintText: AppConfig.defaultHost,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bağlantı adresi: ${AppConfig.buildWsUrl(_hostController.text.trim().isEmpty ? AppConfig.defaultHost : _hostController.text.trim())}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saveAndReconnect,
            icon: const Icon(Icons.refresh),
            label: const Text('Kaydet ve Yeniden Bağlan'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.connect,
            icon: const Icon(Icons.wifi),
            label: const Text('Bağlantıyı Test Et'),
          ),
        ],
      ),
    );
  }
}
