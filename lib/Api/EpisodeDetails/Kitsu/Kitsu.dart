import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dartotsu/DataClass/Media.dart';
import 'package:dartotsu/Services/ApiCacheManager.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';

class Kitsu {
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Dartotsu; Linux x86_64)',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static const Map<String, String> _restHeaders = {
    'User-Agent': 'Mozilla/5.0 (Dartotsu; Linux x86_64)',
    'Accept': 'application/vnd.api+json',
  };

  static Future<Map<String, DEpisode>?> getKitsuEpisodesDetails(
      Media mediaData) async {
    final int? id = mediaData.idAnilist ??
        (!mediaData.mal ? mediaData.id : null) ??
        mediaData.idMAL;
    final cacheKey = 'kitsu_episodes_${id ?? mediaData.id}';

    try {
      final cached =
          ApiCacheManager.instance.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((key, value) => MapEntry(
              key,
              DEpisode.fromJson(Map<String, dynamic>.from(value)),
            ));
      }
    } catch (e) {
      debugPrint("Kitsu cache read error: $e");
    }

    // 1. Try GraphQL Method
    try {
      final episodes = await _fetchFromGraphQL(mediaData);
      if (episodes != null && episodes.isNotEmpty) {
        _cacheResult(cacheKey, episodes);
        return episodes;
      }
    } catch (e) {
      debugPrint("Kitsu GraphQL failed: $e");
    }

    // 2. Fallback to REST API Method
    try {
      final episodes = await _fetchFromRest(mediaData);
      if (episodes != null && episodes.isNotEmpty) {
        _cacheResult(cacheKey, episodes);
        return episodes;
      }
    } catch (e) {
      debugPrint("Kitsu REST failed: $e");
    }

    return null;
  }

  static void _cacheResult(String key, Map<String, DEpisode> episodes) {
    try {
      final jsonMap = episodes.map((k, v) => MapEntry(k, v.toJson()));
      ApiCacheManager.instance.set(key, jsonMap, ttl: const Duration(days: 7));
    } catch (e) {
      debugPrint("Kitsu cache write error: $e");
    }
  }

  static Future<Map<String, DEpisode>?> _fetchFromGraphQL(
      Media mediaData) async {
    final externalId = mediaData.idAnilist ??
        (!mediaData.mal ? mediaData.id : null) ??
        mediaData.idMAL;
    if (externalId == null) return null;

    final externalSite = (mediaData.idAnilist != null || !mediaData.mal)
        ? 'ANILIST_ANIME'
        : 'MYANIMELIST_ANIME';

    final query = '''
      query {
        lookupMapping(externalId: $externalId, externalSite: $externalSite) {
          __typename
          ... on Anime {
            id
            episodes(first: 2000) {
              nodes {
                number
                description
                thumbnail {
                  original {
                    url
                  }
                }
              }
            }
          }
        }
      }
    ''';

    final response = await http
        .post(
          Uri.parse('https://kitsu.io/api/graphql'),
          headers: _headers,
          body: jsonEncode({'query': query}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    final mapping = json['data']?['lookupMapping'];
    if (mapping == null) return null;

    mediaData.idKitsu = mapping['id']?.toString();

    final List<dynamic>? nodes = mapping['episodes']?['nodes'];
    if (nodes == null || nodes.isEmpty) return null;

    final Map<String, DEpisode> results = {};
    for (final node in nodes) {
      if (node == null || node is! Map<String, dynamic>) continue;
      final num = node['number']?.toString();
      if (num == null || num.isEmpty) continue;

      String? desc;
      final descRaw = node['description'];
      if (descRaw is Map<String, dynamic>) {
        desc = descRaw['en']?.toString() ?? descRaw['en-us']?.toString();
      } else if (descRaw is String) {
        desc = descRaw;
      }

      final thumb = node['thumbnail']?['original']?['url']?.toString();

      results[num] = DEpisode(
        episodeNumber: num,
        description: desc,
        thumbnail: thumb,
      );
    }

    return results.isNotEmpty ? results : null;
  }

  static Future<Map<String, DEpisode>?> _fetchFromRest(Media mediaData) async {
    final searchTitle = mediaData.userPreferredName.isNotEmpty
        ? mediaData.userPreferredName
        : (mediaData.name ?? mediaData.nameRomaji);

    if (searchTitle.isEmpty) return null;

    final searchUrl =
        'https://kitsu.io/api/edge/anime?filter[text]=${Uri.encodeComponent(searchTitle)}&page[limit]=1';

    final searchRes = await http
        .get(Uri.parse(searchUrl), headers: _restHeaders)
        .timeout(const Duration(seconds: 10));

    if (searchRes.statusCode != 200) return null;

    final searchJson = jsonDecode(searchRes.body);
    final List<dynamic>? data = searchJson['data'];
    if (data == null || data.isEmpty) return null;

    final animeId = data.first['id']?.toString();
    if (animeId == null) return null;

    mediaData.idKitsu = animeId;

    final Map<String, DEpisode> allEpisodes = {};
    int offset = 0;
    const int limit = 20;

    while (true) {
      final epUrl =
          'https://kitsu.io/api/edge/anime/$animeId/episodes?page[limit]=$limit&page[offset]=$offset&sort=number';
      final epRes = await http
          .get(Uri.parse(epUrl), headers: _restHeaders)
          .timeout(const Duration(seconds: 10));

      if (epRes.statusCode != 200) break;

      final epJson = jsonDecode(epRes.body);
      final List<dynamic>? epList = epJson['data'];
      if (epList == null || epList.isEmpty) break;

      for (final ep in epList) {
        final attr = ep['attributes'];
        if (attr == null || attr is! Map<String, dynamic>) continue;

        var numStr = attr['number']?.toString();
        if (numStr == null || numStr.isEmpty) continue;
        if (numStr.endsWith('.0')) {
          numStr = numStr.substring(0, numStr.length - 2);
        }

        final title = attr['canonicalTitle']?.toString();
        final rawDesc =
            attr['synopsis']?.toString() ?? attr['description']?.toString();
        final desc = rawDesc?.replaceAll(RegExp(r'\(Source:.*\)'), '').trim();

        // Get highest resolution thumbnail available
        final thumbMap = attr['thumbnail'];
        String? thumb;
        if (thumbMap is Map<String, dynamic>) {
          thumb = thumbMap['original']?.toString() ??
              thumbMap['large']?.toString() ??
              thumbMap['medium']?.toString() ??
              thumbMap['small']?.toString() ??
              thumbMap['tiny']?.toString();
        } else if (thumbMap is String) {
          thumb = thumbMap;
        }

        final airDate = attr['airdate']?.toString();

        allEpisodes[numStr] = DEpisode(
          episodeNumber: numStr,
          name: title,
          title: title,
          description: desc,
          thumbnail: thumb,
          dateUpload: airDate,
        );
      }

      final hasNext = epJson['links']?['next'] != null;
      if (!hasNext || epList.length < limit) break;
      offset += limit;
      if (offset >= 200) break; // Guard against runaways
    }

    return allEpisodes.isNotEmpty ? allEpisodes : null;
  }
}
