import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../Preferences/PrefManager.dart';

class CacheEntry {
  final dynamic data;
  final int expiryTime;

  CacheEntry({required this.data, required this.expiryTime});

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiryTime;
}

class ApiCacheManager {
  static final ApiCacheManager instance = ApiCacheManager._internal();
  factory ApiCacheManager() => instance;
  ApiCacheManager._internal();

  final Map<String, CacheEntry> _memoryCache = {};

  /// Retrieves cached data if still valid, checking memory first then persistent disk.
  T? get<T>(String key) {
    // 1. Check memory cache
    final memEntry = _memoryCache[key];
    if (memEntry != null) {
      if (!memEntry.isExpired) {
        return memEntry.data as T?;
      } else {
        _memoryCache.remove(key);
      }
    }

    // 2. Check disk cache
    try {
      final jsonStr = loadCustomData<String>('api_cache_$key');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        final expiry = decoded['expiry'] as int? ?? 0;
        if (DateTime.now().millisecondsSinceEpoch <= expiry) {
          final data = decoded['data'];
          _memoryCache[key] = CacheEntry(data: data, expiryTime: expiry);
          return data as T?;
        } else {
          removeCustomData('api_cache_$key');
        }
      }
    } catch (e) {
      debugPrint("ApiCacheManager load error for $key: $e");
    }

    return null;
  }

  /// Stores data in both memory and persistent disk with the given TTL.
  void set(String key, dynamic data, {Duration ttl = const Duration(minutes: 15)}) {
    if (data == null) return;
    final expiry = DateTime.now().add(ttl).millisecondsSinceEpoch;
    _memoryCache[key] = CacheEntry(data: data, expiryTime: expiry);

    try {
      final jsonStr = jsonEncode({
        'expiry': expiry,
        'data': data,
      });
      saveCustomData('api_cache_$key', jsonStr);
    } catch (e) {
      debugPrint("ApiCacheManager save error for $key: $e");
    }
  }

  /// Removes cached data by key.
  void invalidate(String key) {
    _memoryCache.remove(key);
    try {
      removeCustomData('api_cache_$key');
    } catch (_) {}
  }

  /// Clears all memory cache.
  void clear() {
    _memoryCache.clear();
  }
}
