/// পেয়ারের ধরন অনুযায়ী pip সাইজ ঠিক করে (JPY আর কিছু হাই-ভ্যালু quote
/// currency-র জন্য 0.01, বাকি সবার জন্য 0.0001)।
double getPipSize(String pairTdSymbol) {
  final upper = pairTdSymbol.toUpperCase();
  if (upper.contains('JPY')) return 0.01;
  if (upper.contains('HUF') || upper.contains('INR') || upper.contains('THB') || upper.contains('CNH')) {
    return 0.01;
  }
  return 0.0001;
}

double priceDeltaToPips(double priceDelta, String pairTdSymbol) {
  final pip = getPipSize(pairTdSymbol);
  return priceDelta.abs() / pip;
}

double pipsToPriceDelta(double pips, String pairTdSymbol) {
  final pip = getPipSize(pairTdSymbol);
  return pips * pip;
}

/// JPY/INR/THB পেয়ার ৩ ডেসিমেলে, বাকি সব ৫ ডেসিমেলে দেখায় — UI-এর
/// জন্য প্রাইস ফরম্যাট করার একমাত্র জায়গা, যাতে সব স্ক্রিনে একই রকম দেখায়।
String formatPrice(double? price, String pairTdSymbol) {
  if (price == null || !price.isFinite) return '—';
  final upper = pairTdSymbol.toUpperCase();
  if (upper.contains('JPY')) return price.toStringAsFixed(3);
  if (upper.contains('HUF') || upper.contains('INR') || upper.contains('THB')) {
    return price.toStringAsFixed(3);
  }
  return price.toStringAsFixed(5);
}

double? pipValuePerStandardLot(
  String pairTdSymbol,
  double? currentPrice, {
  double? quoteToUsdRate,
}) {
  final pip = getPipSize(pairTdSymbol);
  final parts = pairTdSymbol.split('/');
  if (parts.length != 2) return null;
  final base = parts[0], quote = parts[1];
  const standardLotUnits = 100000;

  if (quote == 'USD') return pip * standardLotUnits;
  if (base == 'USD') {
    if (currentPrice == null || currentPrice == 0) return null;
    return (pip * standardLotUnits) / currentPrice;
  }
  if (quoteToUsdRate != null) return pip * standardLotUnits * quoteToUsdRate;
  return null;
}

double? suggestedLotSize(double? riskAmountUsd, double? slDistancePips, double? pipValueUsd) {
  if (riskAmountUsd == null || slDistancePips == null || pipValueUsd == null) return null;
  if (slDistancePips == 0 || pipValueUsd == 0) return null;
  final lots = riskAmountUsd / (slDistancePips * pipValueUsd);
  final rounded = (lots * 100).round() / 100;
  return rounded < 0.01 ? 0.01 : rounded;
}

class PositionSizing {
  final double lotSize;
  final double riskAmountUsd;
  final double riskPercent;
  final double potentialLossUsd;
  final double tp1ProfitUsd;
  final double tp2ProfitUsd;
  final double tp3ProfitUsd;
  const PositionSizing({
    required this.lotSize,
    required this.riskAmountUsd,
    required this.riskPercent,
    required this.potentialLossUsd,
    required this.tp1ProfitUsd,
    required this.tp2ProfitUsd,
    required this.tp3ProfitUsd,
  });
}

/// একাউন্ট ব্যালেন্স + রিস্ক% থেকে ঠিক কত লট নিরাপদ সেটা হিসাব করে,
/// আর প্রতিটা TP হিট হলে সম্ভাব্য লাভ কত হবে তাও বলে দেয়।
PositionSizing? buildPositionSizing({
  required double? accountBalance,
  required double riskPercent,
  required String pairTdSymbol,
  required double currentPrice,
  required double slDistancePips,
  required double tp1Pips,
  required double tp2Pips,
  required double tp3Pips,
  double? quoteToUsdRate,
}) {
  if (accountBalance == null || accountBalance <= 0) return null;
  if (slDistancePips <= 0) return null;

  final pipValueUsd = pipValuePerStandardLot(pairTdSymbol, currentPrice, quoteToUsdRate: quoteToUsdRate);
  if (pipValueUsd == null || pipValueUsd <= 0) return null;

  final riskAmountUsd = ((accountBalance * riskPercent) * 100).round() / 100;
  final lotSize = suggestedLotSize(riskAmountUsd, slDistancePips, pipValueUsd);
  if (lotSize == null) return null;

  double profitFor(double pips, double portion) =>
      ((lotSize * pips.abs() * pipValueUsd * portion) * 100).round() / 100;

  return PositionSizing(
    lotSize: lotSize,
    riskAmountUsd: riskAmountUsd,
    riskPercent: riskPercent,
    potentialLossUsd: riskAmountUsd,
    tp1ProfitUsd: profitFor(tp1Pips, 0.5),
    tp2ProfitUsd: profitFor(tp2Pips, 0.3),
    tp3ProfitUsd: profitFor(tp3Pips, 0.2),
  );
}
