import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

import '../data/mock_eeg.dart';

/// mDNS / Bonjour:
///   Python `eegserver._eeg-api._tcp.local.` yayınlar
///   Flutter keşfeder → IP değişse bile bağlanır
///
/// Emülatör yedekleri: 127.0.0.1 (adb reverse) / 10.0.2.2
class EegApiConfig {
  static const String mdnsHost = 'eegserver.local';
  static const String serviceType = '_eeg-api._tcp.local';
  static const int port = 8000;

  /// Son başarılı bağlantı adresi (IP veya hostname)
  static String host = mdnsHost;

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

    for (final host in await _candidateHosts()) {
      try {
        final result = await request(host);
        _rememberHost(host);
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

  Future<List<String>> _candidateHosts() async {
    final hosts = <String>[];

    if (_resolvedHost != null &&
        _resolvedAt != null &&
        DateTime.now().difference(_resolvedAt!) < const Duration(minutes: 2)) {
      hosts.add(_resolvedHost!);
    }

    final discovered = await discoverMdnsHost();
    if (discovered != null && !hosts.contains(discovered)) {
      hosts.add(discovered);
    }

    for (final h in [
      EegApiConfig.mdnsHost,
      if (Platform.isAndroid) ...['127.0.0.1', '10.0.2.2'],
      if (!Platform.isAndroid) '127.0.0.1',
    ]) {
      if (!hosts.contains(h)) hosts.add(h);
    }

    return hosts;
  }

  void _rememberHost(String host) {
    _resolvedHost = host;
    _resolvedAt = DateTime.now();
    EegApiConfig.host = host;
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
      if (kDebugMode) {
        debugPrint('mDNS: ${EegApiConfig.mdnsHost} → $address:${srv.port}');
      }
      return address;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('mDNS keşif başarısız: $e');
      }
      return null;
    } finally {
      client.stop();
    }
  }

  void dispose() {
    _client.close();
  }
}

void logApiHost() {
  if (kDebugMode) {
    debugPrint('EEG API: ${EegApiConfig.displayUrl} (çözülen: ${EegApiConfig.baseUrl})');
  }
}
