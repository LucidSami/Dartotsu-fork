import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dartotsu/DataClass/Media.dart';
import 'package:dartotsu/Services/ApiCacheManager.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';

class Anify {
  static const String _baseUrl = 'https://api.ani.zip/mappings';
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Dartotsu; Linux x86_64)',
    'Accept': 'application/json',
  };

  static Future<Map<String, DEpisode>> fetchAndParseMetadata(
      Media mediaData) async {
    final int? anilistId =
        mediaData.idAnilist ?? (!mediaData.mal ? mediaData.id : null);
    final int? malId = mediaData.idMAL;

    if (anilistId == null && malId == null) return {};

    // Hardcode incorrect ids to skip
    if (anilistId == 105310 || mediaData.id == 105310) return {};

    final cacheKey = 'anizip_${anilistId ?? 'mal_$malId'}';

    // 1. Check cache first
    try {
      final cached =
          ApiCacheManager.instance.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return _parseEpisodesFromMap(cached, mediaData);
      }
    } catch (e) {
      debugPrint("AniZip cache read error: $e");
    }

    // 2. Build URL: try AniList ID first, then MAL ID
    String url;
    if (anilistId != null && anilistId > 0) {
      url = '$_baseUrl?anilist_id=$anilistId';
    } else if (malId != null && malId > 0) {
      url = '$_baseUrl?mal_id=$malId';
    } else {
      return {};
    }

    try {
      debugPrint("AniZip: fetching metadata from $url");
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final isReleasing = mediaData.status == 'RELEASING';
          ApiCacheManager.instance.set(
            cacheKey,
            decoded,
            ttl: Duration(days: isReleasing ? 1 : 7),
          );

          return _parseEpisodesFromMap(decoded, mediaData);
        }
      } else if (response.statusCode == 404 &&
          anilistId != null &&
          malId != null &&
          malId > 0) {
        // Fallback to MAL ID if AniList ID gave 404
        final fallbackUrl = '$_baseUrl?mal_id=$malId';
        debugPrint("AniZip: 404 for anilist_id, trying fallback: $fallbackUrl");
        final fallbackRes = await http
            .get(Uri.parse(fallbackUrl), headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (fallbackRes.statusCode == 200) {
          final decoded = jsonDecode(fallbackRes.body);
          if (decoded is Map<String, dynamic>) {
            ApiCacheManager.instance.set(
              cacheKey,
              decoded,
              ttl: Duration(days: mediaData.status == 'RELEASING' ? 1 : 7),
            );
            return _parseEpisodesFromMap(decoded, mediaData);
          }
        }
      }
    } catch (e) {
      debugPrint("AniZip: error fetching metadata for ${mediaData.id}: $e");
    }

    return {};
  }

  static Map<String, DEpisode> _parseEpisodesFromMap(
      Map<String, dynamic> data, Media mediaData) {
    // Map external IDs if available
    try {
      final mappings = data['mappings'];
      if (mappings is Map<String, dynamic>) {
        if (mappings['mal_id'] != null && mappings['mal_id'] is int) {
          mediaData.idMAL ??= mappings['mal_id'] as int;
        }
        if (mappings['kitsu_id'] != null) {
          mediaData.idKitsu ??= mappings['kitsu_id'].toString();
        }
      }
    } catch (_) {}

    final episodesRaw = data['episodes'];
    if (episodesRaw == null || episodesRaw is! Map<String, dynamic>) {
      return {};
    }

    final Map<String, DEpisode> result = {};

    episodesRaw.forEach((key, val) {
      if (val is! Map<String, dynamic>) return;

      final titles = val['title'];
      String? title;
      if (titles is Map<String, dynamic>) {
        title = titles['en']?.toString() ??
            titles['x-jat']?.toString() ??
            titles['ja']?.toString();
      } else if (titles is String) {
        title = titles;
      }

      final String? overview =
          val['overview']?.toString() ?? val['summary']?.toString();
      final String? image = val['image']?.toString();
      final String? rating = val['rating']?.toString();
      final String? airDate =
          val['airDate']?.toString() ?? val['airdate']?.toString();
      final String epStr = val['episode']?.toString() ?? key;

      result[key] = DEpisode(
        episodeNumber: epStr,
        name: title,
        title: title,
        description: overview,
        thumbnail: image,
        rating: rating,
        dateUpload: airDate,
      );
    });

    return result;
  }
}
