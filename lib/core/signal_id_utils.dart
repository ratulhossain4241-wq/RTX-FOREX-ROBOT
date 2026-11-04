import 'dart:convert';
import 'package:crypto/crypto.dart';

/// প্রতিটি সিগন্যালের জন্য ইউনিক আইডি তৈরি করে।
/// একই সিগন্যাল বারবার এক্সিকিউট না হয় সেটা নিশ্চিত করার জন্য ব্যবহার হয়।
class SignalIdUtils {
  /// মার্কেট + ডাইরেকশন + এন্ট্রি প্রাইস + সময় থেকে একটা শর্ট হ্যাশ আইডি বানায়।
  static String generate({
    required String market,
    required String direction,
    required double entry,
    DateTime? at,
  }) {
    final time = (at ?? DateTime.now()).toIso8601String().substring(0, 16); // মিনিট পর্যন্ত
    final raw = '$market|\( direction| \){entry.toStringAsFixed(5)}|$time';
    final bytes = utf8.encode(raw);
    final digest = sha1.convert(bytes);
    return digest.toString().substring(0, 12);
  }
}
