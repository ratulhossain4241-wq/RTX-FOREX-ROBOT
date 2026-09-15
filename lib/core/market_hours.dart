/// 🔴 এটা একটা আনুমানিক হিসাব (UTC সময়ের ওপর ভিত্তি করে), কোনো ব্রোকারের
/// আসল ফিড না। শুধু "Market Closed" ব্যানার দেখানো/লুকানোর জন্য যথেষ্ট,
/// একদম সেকেন্ড-নির্ভুল হিসেবে ব্যবহার করা ঠিক না।
bool isForexMarketOpen([DateTime? date]) {
  final d = (date ?? DateTime.now()).toUtc();
  final day = d.weekday % 7; // Dart: Mon=1..Sun=7 → convert to Sun=0..Sat=6
  final hour = d.hour;

  if (day == 6) return false; // পুরো শনিবার বন্ধ
  if (day == 0 && hour < 21) return false; // রবিবার ২১:০০ UTC-র আগে বন্ধ
  if (day == 5 && hour >= 21) return false; // শুক্রবার ২১:০০ UTC থেকে বন্ধ
  return true;
}

/// "Market Closed" ব্যানারে "খুলবে ___" এর বাংলা লেবেল।
String nextOpenDayLabel([DateTime? date]) {
  final d = (date ?? DateTime.now()).toUtc();
  final day = d.weekday % 7;

  if (day == 5 || day == 6) return 'সোমবার';
  if (day == 0) return 'আজ রাতে (সোমবার সকাল, বাংলাদেশ সময়)';
  return 'শীঘ্রই';
}
