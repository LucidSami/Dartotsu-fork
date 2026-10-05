import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../DataClass/Media.dart';
import '../../Services/ApiCacheManager.dart';
import '../../logger.dart';

class WatchOrderItem {
  final String id;
  final String? anilistId;
  final String image;
  final String name;
  final String relationType;
  final bool isCurrent;
  final String airDate;
  final String mediaType;
  final String episodes;

  const WatchOrderItem({
    required this.id,
    this.anilistId,
    required this.image,
    required this.name,
    required this.relationType,
    this.isCurrent = false,
    this.airDate = '',
    this.mediaType = '',
    this.episodes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'anilistId': anilistId,
    'image': image,
    'name': name,
    'relationType': relationType,
    'isCurrent': isCurrent,
    'airDate': airDate,
    'mediaType': mediaType,
    'episodes': episodes,
  };

  factory WatchOrderItem.fromJson(Map<String, dynamic> json) => WatchOrderItem(
    id: json['id'] as String? ?? '',
    anilistId: json['anilistId'] as String?,
    image: json['image'] as String? ?? '',
    name: json['name'] as String? ?? '',
    relationType: json['relationType'] as String? ?? '',
    isCurrent: json['isCurrent'] as bool? ?? false,
    airDate: json['airDate'] as String? ?? '',
    mediaType: json['mediaType'] as String? ?? '',
    episodes: json['episodes'] as String? ?? '',
  );
}

class WatchOrderService {
  static final WatchOrderService _instance = WatchOrderService._();
  factory WatchOrderService() => _instance;
  WatchOrderService._();

  static const _headers = {
    'Referer': 'https://chiaki.site/?/tools/watch_order',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'X-Requested-With': 'XMLHttpRequest',
  };

  Future<List<WatchOrderItem>> getWatchOrder(Media media) async {
    final malId = media.idMAL ?? (media.mal ? media.id : null);
    final cacheKey = 'watch_order_${media.id}_${malId ?? 0}';

    final cached = ApiCacheManager.instance.get<List<dynamic>>(cacheKey);
    if (cached != null) {
      try {
        return cached
            .map((e) => WatchOrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    try {
      var targetId = malId?.toString();

      if (targetId == null || targetId == '0') {
        final searchName = media.userPreferredName.isNotEmpty
            ? media.userPreferredName
            : media.mainName();
        final searchUrl =
            'https://chiaki.site/?/tools/autocomplete_series&term=${Uri.encodeComponent(searchName)}';
        final res = await http.get(Uri.parse(searchUrl), headers: _headers);
        if (res.statusCode == 200) {
          final jsonArr = jsonDecode(res.body) as List<dynamic>?;
          if (jsonArr != null && jsonArr.isNotEmpty) {
            targetId = jsonArr[0]['id']?.toString();
          }
        }
      }

      if (targetId == null || targetId.isEmpty) {
        return [];
      }

      final orderUrl = 'https://chiaki.site/?/tools/watch_order/id/$targetId';
      final response = await http.get(Uri.parse(orderUrl), headers: _headers);
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final rows = document.querySelectorAll('tr[data-id]');
      if (rows.isEmpty) return [];

      // Parse relations relative to targetId from data-related JSON attribute
      final targetRow = rows.firstWhere(
        (r) => r.attributes['data-id'] == targetId,
        orElse: () => rows.first,
      );
      final targetRelatedJson = targetRow.attributes['data-related'] ?? '{}';
      final Map<String, String> relatedMap = {};
      try {
        final decoded = jsonDecode(targetRelatedJson) as Map<String, dynamic>?;
        decoded?.forEach((k, v) => relatedMap[k] = v.toString());
      } catch (_) {}

      final relationsMap = {
        for (var rel in media.relations ?? <Media>[]) rel.id.toString(): rel
      };

      final items = <WatchOrderItem>[];

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final titleEl = row.querySelector('span.wo_title') ?? row.querySelector('.wo_title');
        final title = titleEl?.text.trim() ?? '';
        if (title.isEmpty || title.toLowerCase() == 'unknown title') continue;

        final id = row.attributes['data-id'] ?? targetId;
        final anilistId = row.attributes['data-anilist-id'];

        // 1. Cover image from style background-image
        final avatarEl = row.querySelector('div.wo_avatar_big');
        final style = avatarEl?.attributes['style'] ?? '';
        final imgMatch = RegExp(r"""url\(['"]?([^'")]+)['"]?\)""").firstMatch(style);
        var imageUrl = imgMatch?.group(1) ?? '';
        if (imageUrl.isNotEmpty) {
          if (imageUrl.startsWith('//')) {
            imageUrl = 'https:$imageUrl';
          } else if (imageUrl.startsWith('/')) {
            imageUrl = 'https://chiaki.site$imageUrl';
          } else if (!imageUrl.startsWith('http')) {
            imageUrl = 'https://chiaki.site/$imageUrl';
          }
        }

        if (imageUrl.isEmpty) {
          if (anilistId != null && anilistId == media.id.toString()) {
            imageUrl = media.cover ?? '';
          } else if (anilistId != null && relationsMap.containsKey(anilistId)) {
            imageUrl = relationsMap[anilistId]?.cover ?? '';
          }
        }

        // 2. Metadata text: Air Date | Media Type | Episodes
        final metaEl = row.querySelector('span.uk-text-muted.uk-text-small') ??
            row.querySelector('.wo_meta');
        final metaText = metaEl?.text.trim() ?? '';
        final parts = metaText.split('|').map((p) => p.trim()).toList();
        final airDate = parts.isNotEmpty ? parts[0] : '';
        final format = parts.length > 1 ? parts[1] : '';
        final eps = parts.length > 2
            ? parts[2].split('★').first.split('(').first.trim()
            : '';

        // 3. Is current anime
        final cleanId = id.trim();
        final cleanAnilistId = anilistId?.trim() ?? '';
        final currentMalId = media.idMAL ?? malId;
        final isCurrent = (cleanAnilistId.isNotEmpty && cleanAnilistId == media.id.toString()) ||
            (cleanId.isNotEmpty && currentMalId != null && cleanId == currentMalId.toString()) ||
            (cleanId.isNotEmpty && cleanId == targetId && (currentMalId == null || currentMalId.toString() == targetId)) ||
            (title.isNotEmpty &&
                (title.toLowerCase() == media.userPreferredName.toLowerCase() ||
                    title.toLowerCase() == media.mainName().toLowerCase() ||
                    title.toLowerCase() == (media.name ?? '').toLowerCase()));

        // 4. Relation type
        String relationType;
        if (isCurrent) {
          relationType = 'Current';
        } else if (relatedMap.containsKey(id)) {
          relationType = relatedMap[id]!;
        } else if (anilistId != null && relationsMap.containsKey(anilistId)) {
          final relName = relationsMap[anilistId]?.relation ?? '';
          relationType = relName.replaceAll('_', ' ');
        } else if (i == 0) {
          relationType = 'Main Story';
        } else if (format.toLowerCase() == 'tv') {
          relationType = 'Sequel';
        } else if (format.toLowerCase() == 'ova' || format.toLowerCase() == 'special') {
          relationType = 'Side Story';
        } else if (format.toLowerCase() == 'movie') {
          relationType = 'Movie';
        } else {
          relationType = format.isNotEmpty ? format : 'Entry';
        }

        items.add(
          WatchOrderItem(
            id: id,
            anilistId: anilistId,
            image: imageUrl,
            name: title,
            relationType: relationType,
            isCurrent: isCurrent,
            airDate: airDate,
            mediaType: format,
            episodes: eps,
          ),
        );
      }

      if (items.isNotEmpty) {
        ApiCacheManager.instance.set(
          cacheKey,
          items.map((e) => e.toJson()).toList(),
          ttl: const Duration(days: 7),
        );
      }

      return items;
    } catch (e) {
      Logger.log("Failed to get watch order for ${media.id}: $e");
      return [];
    }
  }
}
