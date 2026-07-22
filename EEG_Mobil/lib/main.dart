import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_dependencies.dart';
import 'core/app_logger.dart';
import 'core/app_messenger.dart';
import 'firebase_options.dart';
import 'providers/eeg_provider.dart';
import 'providers/experiment_provider.dart';
import 'providers/history_provider.dart';
import 'providers/participant_provider.dart';
import 'providers/recovery_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/text_content_provider.dart';
import 'providers/video_content_provider.dart';
import 'screens/app_shell.dart';
import 'services/eeg_api_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/recovery_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Storage kuralları genelde auth ister; Auth kullanmıyoruz ama
    // anonim oturum Storage yazma için token sağlar.
    await _ensureAnonymousAuth();
    firebaseReady = true;
    AppLogger.instance.firebase('Firebase başlatıldı');
  } catch (e, st) {
    AppLogger.instance.error(
      'Firebase başlatılamadı',
      error: e,
      stackTrace: st,
    );
  }

  final settings = await SettingsService.create();
  // EegProvider.connect() SettingsProvider'dan önce de çalışabilsin diye
  // API host'unu burada yükle (son başarılı adres dahil).
  EegApiConfig.port = settings.wsPort;
  EegApiConfig.hostOverride = settings.apiHostOverride;
  EegApiConfig.lastSuccessfulHost = settings.lastSuccessfulApiHost;

  final deps = AppDependencies.create();

  runApp(
    EegMobilApp(
      dependencies: deps,
      settingsService: settings,
      firebaseReady: firebaseReady,
    ),
  );
}

class EegMobilApp extends StatefulWidget {
  const EegMobilApp({
    super.key,
    required this.dependencies,
    required this.settingsService,
    required this.firebaseReady,
  });

  final AppDependencies dependencies;
  final SettingsService settingsService;
  final bool firebaseReady;

  @override
  State<EegMobilApp> createState() => _EegMobilAppState();
}

class _EegMobilAppState extends State<EegMobilApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arka plana / kapanmaya giderken checkpoint session dispose ile yazılır.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final session = widget.dependencies.experimentSessionService;
      if (session.isRunning) {
        // dispose timer zaten periyodik kaydeder; ekstra flush için
        AppLogger.instance.experiment('Uygulama arka plana alındı — checkpoint aktif');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;

    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: deps),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            settingsService: widget.settingsService,
            eegService: deps.eegService,
            firebaseReady: widget.firebaseReady,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => EegProvider(eegService: deps.eegService),
        ),
        ChangeNotifierProvider(
          create: (_) => ParticipantProvider(
            repository: deps.participantRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ExperimentProvider(
            sessionService: deps.experimentSessionService,
            videoRepository: deps.videoRepository,
            textRepository: deps.textRepository,
            watchEventRepository: deps.videoWatchEventRepository,
            textQuizResponseRepository: deps.textQuizResponseRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RecoveryProvider(
            experimentRepository: deps.experimentRepository,
            participantRepository: deps.participantRepository,
            sessionService: deps.experimentSessionService,
          )..checkOnStartup(),
        ),
        ChangeNotifierProvider(
          create: (_) => VideoContentProvider(
            repository: deps.videoRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TextContentProvider(
            repository: deps.textRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(
            participantRepository: deps.participantRepository,
            experimentRepository: deps.experimentRepository,
            resultReanalyzer: deps.resultReanalyzer,
          ),
        ),
      ],
      // Yalnızca tema değişince MaterialApp rebuild — EEG tick'i kök ağacı yenilemesin.
      child: Selector<SettingsProvider, ThemeMode>(
        selector: (_, s) => s.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'EEG Araştırma',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: AppMessenger.key,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: const _AppHome(),
          );
        },
      ),
    );
  }
}

Future<void> _ensureAnonymousAuth() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) {
    AppLogger.instance.firebase('Auth oturumu mevcut: ${auth.currentUser!.uid}');
    return;
  }
  try {
    final cred = await auth.signInAnonymously();
    AppLogger.instance.firebase(
      'Anonim Auth oturumu açıldı: ${cred.user?.uid}',
    );
  } catch (e, st) {
    // Auth olmadan Firestore çalışır; Storage kuralları auth isterse
    // yükleme 403 verir. Console'da Anonymous Sign-in açılmalı.
    AppLogger.instance.error(
      'Anonim Auth başarısız — Firebase Console > Authentication > '
      'Sign-in method > Anonymous etkin olmalı',
      error: e,
      stackTrace: st,
    );
  }
}

class _AppHome extends StatefulWidget {
  const _AppHome();

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowRecovery();
    });
  }

  Future<void> _maybeShowRecovery() async {
    final recovery = context.read<RecoveryProvider>();
    // Recovery check bitene kadar kısa bekle
    var waits = 0;
    while (recovery.checking && waits < 40) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waits++;
    }
    if (!mounted) return;
    await showRecoveryDialogIfNeeded(context);
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}
