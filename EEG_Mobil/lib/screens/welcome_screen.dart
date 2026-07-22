import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_nav_card.dart';

/// Ana sayfa — karşılama + modern navigasyon kartları.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onStartExperiment,
    required this.onParticipants,
    required this.onHistory,
    required this.onStatistics,
    required this.onSettings,
    this.onOpenEeg,
  });

  final VoidCallback onStartExperiment;
  final VoidCallback onParticipants;
  final VoidCallback onHistory;
  final VoidCallback onStatistics;
  final VoidCallback onSettings;
  final VoidCallback? onOpenEeg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = AppColors.isDark(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Günaydın'
        : hour < 18
            ? 'İyi günler'
            : 'İyi akşamlar';

    return SafeArea(
      child: ResponsiveBody(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius + 4),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF16333A), Color(0xFF1C282E)]
                      : const [Color(0xFFD6F0EC), Color(0xFFE8F4FB)],
                ),
                border: Border.all(color: AppColors.line(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.psychology_outlined,
                          color: scheme.primary,
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      if (onOpenEeg != null)
                        TextButton.icon(
                          onPressed: onOpenEeg,
                          icon: const Icon(Icons.bluetooth_searching_outlined,
                              size: 18),
                          label: const Text('EEG'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.secondary(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EEG Araştırma',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sosyal medya ve metin okuma deneylerini EEG ile ölçün. '
                    'Katılımcı seçin, bağlantıyı kurun ve oturumu başlatın.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondary(context),
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Hızlı erişim',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppNavCard(
              title: 'Yeni Deney',
              subtitle: 'Katılımcı seçip deney protokolünü başlatın',
              icon: Icons.play_circle_outline,
              accent: scheme.primary,
              onTap: onStartExperiment,
            ),
            const SizedBox(height: AppSpacing.md),
            AppNavCard(
              title: 'Katılımcılar',
              subtitle: 'Kayıtlı katılımcı listesini yönetin',
              icon: Icons.groups_outlined,
              accent: AppColors.secondaryTone,
              onTap: onParticipants,
            ),
            const SizedBox(height: AppSpacing.md),
            AppNavCard(
              title: 'Geçmiş Deneyler',
              subtitle: 'Tamamlanan ve iptal edilen oturumlar',
              icon: Icons.history_outlined,
              accent: AppColors.accent,
              onTap: onHistory,
            ),
            const SizedBox(height: AppSpacing.md),
            AppNavCard(
              title: 'İstatistikler',
              subtitle: 'Özet sayılar ve oturum metrikleri',
              icon: Icons.insights_outlined,
              accent: const Color(0xFF5C6BC0),
              onTap: onStatistics,
            ),
            const SizedBox(height: AppSpacing.md),
            AppNavCard(
              title: 'Ayarlar',
              subtitle: 'API, tema ve sistem tercihleri',
              icon: Icons.settings_outlined,
              accent: AppColors.textSecondary,
              onTap: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}
