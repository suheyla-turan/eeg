import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eeg_mobil/core/app_dependencies.dart';
import 'package:eeg_mobil/main.dart';
import 'package:eeg_mobil/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App opens welcome home', (WidgetTester tester) async {
    await initializeDateFormatting('tr');
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.create();
    final deps = AppDependencies.create();
    await tester.pumpWidget(
      EegMobilApp(
        dependencies: deps,
        settingsService: settings,
        firebaseReady: false,
      ),
    );
    await tester.pump();
    // RecoveryProvider kısa beklemeleri bitene kadar
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('EEG Araştırma'), findsWidgets);
    expect(find.textContaining('Proje amacı'), findsOneWidget);
    expect(find.byType(DrawerButton), findsOneWidget);
  });
}
