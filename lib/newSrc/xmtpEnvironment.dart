enum XMTPEnvironment {
  dev('dev.xmtp.network', 5556),
  production('grpc.production.xmtp.network', 443),
  local('10.0.2.2', 5556);

  final String rawValue;
  final int defaultPort;
  final String? customValue;

  const XMTPEnvironment(this.rawValue, this.defaultPort, {this.customValue});

  static XMTPEnvironment? fromValue(String value) {
    try {
      return XMTPEnvironment.values
          .firstWhere((e) => e.rawValue == value || e.customValue == value);
    } catch (e) {
      return null;
    }
  }

  String getValue() {
    return customValue ?? rawValue;
  }

  String getUrl() {
    switch (this) {
      case XMTPEnvironment.dev:
        return 'https://${getValue()}:$port';
      case XMTPEnvironment.production:
        return 'https://${getValue()}:$port';
      case XMTPEnvironment.local:
        return 'http://${getValue()}:$port';
    }
  }

  int get port => defaultPort;
}
