class AppConfig {
  static const String defaultHost = '10.0.2.2';
  static const int port = 8000;

  static String buildBaseUrl(String host) => 'http://$host:$port';
  static String buildWsUrl(String host) => 'ws://$host:$port/ws';
}
