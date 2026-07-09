import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/mock_eeg.dart';

/// Android emülatör:
///   - `adb reverse tcp:8000 tcp:8000` ile 127.0.0.1 kullanılır (önerilen)
///   - veya 10.0.2.2 (emülatörün host alias'ı)
/// Gerçek telefon → PC'nin yerel IP'sini yaz (ör. 192.168.1.20)
class EegApiConfig {
  /// Emülatörde adb reverse sonrası localhost; gerekirse '10.0.2.2' yap.
  static String host = '127.0.0.1';
  static int port = 8000;

  static String get baseUrl => 'http://$host:$port';

  /// Alternatif host'lar (bağlantı kopunca sırayla dener)
  static List<String> get fallbackHosts {
    if (!Platform.isAndroid) return const ['127.0.0.1'];
    return const ['127.0.0.1', '10.0.2.2'];
  }
}

class EegApiService {
  EegApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LiveEegState> fetchLive() async {
    Object? lastError;

    for (final host in EegApiConfig.fallbackHosts) {
      final uri = Uri.parse('http://$host:${EegApiConfig.port}/live');
      try {
        final response =
            await _client.get(uri).timeout(const Duration(seconds: 2));
        if (response.statusCode != 200) {
          throw HttpException('API ${response.statusCode}', uri: uri);
        }
        EegApiConfig.host = host;
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return LiveEegState.fromJson(json);
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ??
        HttpException('API unreachable', uri: Uri.parse(EegApiConfig.baseUrl));
  }

  void dispose() {
    _client.close();
  }
}

void logApiHost() {
  if (kDebugMode) {
    debugPrint('EEG API: ${EegApiConfig.baseUrl}');
  }
}
