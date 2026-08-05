import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Thin wrapper around a single Hive box used as a generic
/// key -> JSON-string cache. Any screen can save its last-fetched API
/// response here and read it back instantly on next app open, before
/// the network call for a fresh copy even starts.
class LocalCache {
  static Box get _box => Hive.box('app_cache');

  /// Saves any JSON-encodable value (list or map) under [key].
  static Future<void> save(String key, dynamic value) async {
    await _box.put(key, jsonEncode(value));
  }

  /// Reads back a previously saved value, or null if nothing is
  /// cached yet under [key] (e.g. very first app open).
  static dynamic read(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw as String);
    } catch (_) {
      return null;
    }
  }
}
