import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  factory VideoCacheManager() => _instance;
  VideoCacheManager._internal();

  // 2 GB limit matching Saikou LeastRecentlyUsedCacheEvictor(2147483648L)
  static const int maxCacheSizeBytes = 2147483648; 
  static const int targetTrimSizeBytes = 1610612736; // 1.5 GB target after trim

  String? _cacheDirPath;

  Future<String> getCacheDirPath() async {
    if (_cacheDirPath != null) return _cacheDirPath!;
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/videocache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _cacheDirPath = cacheDir.path;
    // Perform LRU eviction check asynchronously
    _evictOldestIfNeeded(cacheDir);
    return _cacheDirPath!;
  }

  Future<int> getCacheSizeBytes() async {
    try {
      final path = await getCacheDirPath();
      final dir = Directory(path);
      if (!await dir.exists()) return 0;
      int totalSize = 0;
      await for (final file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Error computing video cache size: $e');
      return 0;
    }
  }

  Future<String> getFormattedCacheSize() async {
    final bytes = await getCacheSizeBytes();
    if (bytes <= 0) return '0.0 MB / 2.0 GB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB / 2.0 GB';
    } else {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(2)} GB / 2.0 GB';
    }
  }

  Future<void> clearCache() async {
    try {
      final path = await getCacheDirPath();
      final dir = Directory(path);
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error clearing video cache: $e');
    }
  }

  Future<void> _evictOldestIfNeeded(Directory dir) async {
    try {
      final entities = <File>[];
      int totalSize = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
          entities.add(entity);
        }
      }

      if (totalSize > maxCacheSizeBytes) {
        // Sort files by last modified time ascending (oldest first) - LRU
        entities.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

        for (final file in entities) {
          if (totalSize <= targetTrimSizeBytes) break;
          final len = await file.length();
          try {
            await file.delete();
            totalSize -= len;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('LRU cache eviction error: $e');
    }
  }
}
