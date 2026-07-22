import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

import '../core/app_logger.dart';
import '../data/mock_eeg.dart';

/// mDNS / Bonjour:
///   Python `eegserver._eeg-api._tcp.local.` yayınlar
///   Flutter keşfeder → IP değişse bile bağlanır
///
/// Emülatör yedekleri: 127.0.0.1 (adb reverse) / 10.0.2.2
class EegApiConfig {
  static const String mdnsHost = 'eegserver.local';
  static const String serviceType = '_eeg-api._tcp.local';

  /// Varsayılan port; Settings üzerinden değiştirilebilir.
  static int port = 8000;

  /// Son başarılı bağlantı adresi (IP veya hostname)
  static String host = mdnsHost;

  /// Settings'ten gelen manuel host (null = otomatik keşif).
  static String? hostOverride;

  /// Önceki oturumda başarılı olan host (SharedPreferences).
  static String? lastSuccessfulHost;

  /// Başarılı host kalıcı kaydı (SettingsProvider bağlar).
  static Future<void> Function(String host)? onHostResolved;

  /// UI'da gösterilen sabit isim
  static String get displayUrl => 'http://$mdnsHost:$port';

  static String get baseUrl => 'http://$host:$port';
}

class EegApiService {
  EegApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _resolvedHost;
  DateTime? _resolvedAt;

  Future<LiveEegState> fetchLive() async {
    return _withHosts((host) async {
      final uri = Uri.parse('http://$host:${EegApiConfig.port}/live');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        throw HttpException('API ${response.statusCode}', uri: uri);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return LiveEegState.fromJson(json);
    });
  }

  Future<void> startCollection() => _postCollection('start');

  Future<void> stopCollection() => _postCollection('stop');

  /// Gemini oturum yorumu: `POST /analyze/session`.
  ///
  /// [payload] Flutter [ExperimentResult] alanlarıyla uyumlu olmalı
  /// (`experimentId`, `reels`, `text`, epoch serileri, …).
  Future<SessionAnalysisResponse> analyzeSession(
    Map<String, dynamic> payload, {
    int timeoutSec = 90,
  }) async {
    return _withHosts((host) async {
      final uri =
          Uri.parse('http://$host:${EegApiConfig.port}/analyze/session');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: timeoutSec));
      if (response.statusCode != 200) {
        throw HttpException('API ${response.statusCode}', uri: uri);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SessionAnalysisResponse.fromJson(json);
    });
  }

  /// Test dump: PC'de reel/metin EEG dosyalarını sıfırlar.
  /// Önce dump sidecar (8001), yoksa ana API (8000).
  Future<void> resetTestDump() async {
    await _postTestDump('reset');
  }

  /// Test dump: tek örneği phase'e göre PC'ye yazar.
  Future<void> dumpTestSample(Map<String, dynamic> sample) async {
    await _postTestDump('dump', body: sample);
  }

  /// Test dump: oturum sonunda reels/text JSON üretir.
  Future<void> finalizeTestDump(Map<String, dynamic> payload) async {
    await _postTestDump('finalize', body: payload, timeoutSec: 15);
  }

  Future<void> _postTestDump(
    String action, {
    Map<String, dynamic>? body,
    int timeoutSec = 5,
  }) async {
    Object? lastError;
    // Sidecar 8002 (ana API restart gerekmez) → 8001 → sonra 8000
    final ports = <int>[8002, 8001, EegApiConfig.port];
    for (final port in ports) {
      for (final host in syncCandidateHosts()) {
        try {
          final uri = Uri.parse('http://$host:$port/test/$action');
          final response = body == null
              ? await _client
                  .post(uri)
                  .timeout(Duration(seconds: timeoutSec))
              : await _client
                  .post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(body),
                  )
                  .timeout(Duration(seconds: timeoutSec));
          if (response.statusCode == 200) {
            rememberSuccessfulHost(host);
            return;
          }
          lastError = HttpException('API ${response.statusCode}', uri: uri);
        } catch (e) {
          lastError = e;
        }
      }
    }
    throw lastError ??
        HttpException(
          'Test dump unreachable',
          uri: Uri.parse('http://${EegApiConfig.host}:8001/test/$action'),
        );
  }

  Future<void> _postCollection(String action) async {
    await _withHosts((host) async {
      final uri =
          Uri.parse('http://$host:${EegApiConfig.port}/collection/$action');
      final response =
          await _client.post(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw HttpException('API ${response.statusCode}', uri: uri);
      }
    });
  }

  Future<T> _withHosts<T>(Future<T> Function(String host) request) async {
    Object? lastError;

    for (final host in syncCandidateHosts()) {
      try {
        final result = await request(host);
        rememberSuccessfulHost(host);
        return result;
      } catch (e) {
        lastError = e;
      }
    }

    // Hızlı adaylar başarısızsa mDNS (Xiaomi'de sık timeout — en sonda).
    final discovered = await discoverMdnsHost();
    if (discovered != null && !syncCandidateHosts().contains(discovered)) {
      try {
        final result = await request(discovered);
        rememberSuccessfulHost(discovered);
        return result;
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ??
        HttpException(
          'API unreachable',
          uri: Uri.parse(EegApiConfig.displayUrl),
        );
  }

  /// mDNS beklemeden denenecek hostlar (HTTP ve WebSocket için ortak).
  ///
  /// Fiziksel Android'de mDNS sık kırılır; USB debug için `adb reverse`
  /// ile `127.0.0.1` çalışır. Emülatör için `10.0.2.2` en sonda denenir.
  List<String> syncCandidateHosts() {
    final hosts = <String>[];

    void add(String? host) {
      if (host == null || host.isEmpty) return;
      if (!hosts.contains(host)) hosts.add(host);
    }

    // Manuel override en önde (Ayarlar → Host)
    add(EegApiConfig.hostOverride);

    // Önceki oturumda çalışan adres (IP değişmediyse anında bağlanır)
    add(EegApiConfig.lastSuccessfulHost);

    if (_resolvedHost != null &&
        _resolvedAt != null &&
        DateTime.now().difference(_resolvedAt!) < const Duration(minutes: 2)) {
      add(_resolvedHost);
    }

    // USB adb reverse veya aynı makine: 127.0.0.1
    add('127.0.0.1');
    add(EegApiConfig.mdnsHost);

    // Yalnızca Android emülatör köprüsü — fiziksel cihazda genelde işe yaramaz
    if (Platform.isAndroid) {
      add('10.0.2.2');
    }

    return hosts;
  }

  /// mDNS dahil tam aday listesi (geriye dönük / log için).
  Future<List<String>> candidateHosts() async {
    final hosts = syncCandidateHosts();
    final discovered = await discoverMdnsHost();
    if (discovered != null && !hosts.contains(discovered)) {
      // Override / lastSuccessful'tan hemen sonra dene
      final insertAt = EegApiConfig.hostOverride != null ? 1 : 0;
      hosts.insert(insertAt.clamp(0, hosts.length), discovered);
    }
    return hosts;
  }

  void rememberSuccessfulHost(String host) {
    _resolvedHost = host;
    _resolvedAt = DateTime.now();
    EegApiConfig.host = host;
    if (EegApiConfig.lastSuccessfulHost == host) return;
    EegApiConfig.lastSuccessfulHost = host;
    final cb = EegApiConfig.onHostResolved;
    if (cb != null) {
      cb(host);
    }
  }

  /// `_eeg-api._tcp` servisini mDNS ile bulur; IP döner.
  Future<String?> discoverMdnsHost() async {
    // Android'de reusePort=true sık sorun çıkarır
    final client = MDnsClient(
      rawDatagramSocketFactory: (
        dynamic host,
        int port, {
        bool reuseAddress = false,
        bool reusePort = false,
        int ttl = 1,
      }) {
        return RawDatagramSocket.bind(
          host,
          port,
          reuseAddress: true,
          reusePort: false,
          ttl: ttl,
        );
      },
    );

    try {
      await client.start();

      final ptr = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(EegApiConfig.serviceType),
          )
          .timeout(const Duration(seconds: 3))
          .first;

      final srv = await client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )
          .timeout(const Duration(seconds: 2))
          .first;

      final ip = await client
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )
          .timeout(const Duration(seconds: 2))
          .first;

      final address = ip.address.address;
      AppLogger.instance.python(
        'mDNS: ${EegApiConfig.mdnsHost} → $address:${srv.port}',
      );
      return address;
    } catch (e) {
      AppLogger.instance.python(
        'mDNS keşif başarısız',
        level: LogLevel.warning,
        error: e,
      );
      return null;
    } finally {
      client.stop();
    }
  }

  void dispose() {
    _client.close();
  }
}

/// `POST /analyze/session` yanıtı.
class SessionAnalysisResponse {
  const SessionAnalysisResponse({
    required this.ok,
    required this.model,
    required this.markdown,
    this.promptChars = 0,
    this.error,
  });

  final bool ok;
  final String model;
  final String markdown;
  final int promptChars;
  final String? error;

  factory SessionAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return SessionAnalysisResponse(
      ok: json['ok'] as bool? ?? false,
      model: json['model'] as String? ?? '',
      markdown: json['markdown'] as String? ?? '',
      promptChars: (json['promptChars'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }
}

void logApiHost() {
  if (kDebugMode) {
    debugPrint(
      'EEG API: ${EegApiConfig.displayUrl} (çözülen: ${EegApiConfig.baseUrl})',
    );
  }
}
