/// نسب الربح مطابقة لـ settings.PROFIT_CHOICES في Django
class ProfitRates {
  static const Map<String, double> rates = {
    'vip1': 0.00,
    'vip2': 0.02,
    'vip3': 0.03,
    'vip4': 0.04,
    'vip5': 0.05,
  };

  static double forLevel(String? level) {
    if (level == null || level.isEmpty) return 0.0;
    return rates[level.toLowerCase()] ?? 0.0;
  }

  /// نفس منطق الموقع/Django:
  /// - مخصصة: coins_price × quantity
  /// - عادية: package.price
  /// ثم × (1 + profit) ثم تحويل العملة إن لزم
  static double calculateFinalPrice({
    required bool isCustom,
    required double? coinsPrice,
    required double quantity,
    required double? packagePrice,
    String? level,
    String? currency,
    double exchangeRate = 15000.0,
  }) {
    double basePrice;
    if (isCustom) {
      basePrice = (coinsPrice ?? 0.0) * quantity;
    } else {
      basePrice = packagePrice ?? 0.0;
    }

    double finalPrice = basePrice * (1 + forLevel(level));

    if (currency == 'SYP') {
      finalPrice *= exchangeRate;
    }

    return finalPrice;
  }
}
