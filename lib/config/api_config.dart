class ApiConfig {
  /// عناوين بديلة — الأول بدون www لأنه أكثر استقراراً على DNS المحاكي
  static const List<String> candidateSiteUrls = [
    'https://crystal4card.com',
    'https://www.crystal4card.com',
  ];

  static const String _knownHostWww = 'https://www.crystal4card.com';
  static const String _knownHostApex = 'https://crystal4card.com';

  static String _activeSiteUrl = candidateSiteUrls.first;

  static String get siteUrl => _activeSiteUrl;
  static String get baseUrl => '$_activeSiteUrl/api/';

  static void setActiveSiteUrl(String url) {
    if (candidateSiteUrls.contains(url)) {
      _activeSiteUrl = url;
    }
  }

  static String? nextSiteUrl() {
    for (final url in candidateSiteUrls) {
      if (url != _activeSiteUrl) return url;
    }
    return null;
  }

  /// يحوّل روابط الصور إلى النطاق النشط (يتجنب www إن فشل DNS)
  static String? resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    String resolved;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      resolved = url;
    } else if (url.startsWith('/')) {
      resolved = '$_activeSiteUrl$url';
    } else {
      resolved = '$_activeSiteUrl/$url';
    }

    return _normalizeKnownHosts(resolved);
  }

  static String _normalizeKnownHosts(String url) {
    return url
        .replaceAll(_knownHostWww, _activeSiteUrl)
        .replaceAll(_knownHostApex, _activeSiteUrl);
  }

  // Endpoints
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String categories = '/categories/';
  static const String products = '/products/';
  static const String packages = '/packages/';
  static const String orders = '/orders/';
  static const String profile = '/profile/';
  static const String notifications = '/notifications/';
  static const String paymentMethods = '/payment-methods/';
  static const String agents = '/agents/';

  static String get sendMoney => '${profile}send_money/';

  static Map<String, String> getHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }
}
