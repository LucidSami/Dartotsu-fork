part of '../AnilistQueries.dart';

extension GetStudioDetails on AnilistQueries {
  Future<studio?> _getStudioDetails(int studioId, {String? studioName}) async {
    const query = """
query (\$id: Int, \$page: Int) {
  Studio(id: \$id) {
    id
    name
    isAnimationStudio
    siteUrl
    favourites
    media(page: \$page, perPage: 25, sort: START_DATE_DESC) {
      pageInfo {
        hasNextPage
      }
      nodes {
        id
        idMal
        title {
          romaji
          english
          userPreferred
        }
        coverImage {
          extraLarge
          large
          medium
        }
        bannerImage
        startDate {
          year
          month
          day
        }
        endDate {
          year
          month
          day
        }
        format
        status
        episodes
        chapters
        meanScore
        isAdult
        genres
      }
    }
  }
}
""";

    final yearMedia = <String, List<Media>>{};
    final seenIds = <int>{};
    String resolvedName = studioName ?? '';
    bool isAnim = true;
    String? siteUrl;
    int? favs;

    try {
      bool hasNext = true;
      int page = 1;

      while (hasNext && page <= 5) {
        final res = await executeQuery<Map<String, dynamic>>(
          query,
          variables: '{"id": $studioId, "page": $page}',
        );

        if (res == null || res['data'] == null || res['data']['Studio'] == null) {
          break;
        }

        final studioData = res['data']['Studio'] as Map<String, dynamic>;
        resolvedName = studioData['name'] as String? ?? resolvedName;
        isAnim = studioData['isAnimationStudio'] as bool? ?? true;
        siteUrl = studioData['siteUrl'] as String?;
        favs = studioData['favourites'] as int?;

        final mediaData = studioData['media'] as Map<String, dynamic>?;
        final nodes = mediaData?['nodes'] as List<dynamic>? ?? [];
        hasNext = mediaData?['pageInfo']?['hasNextPage'] as bool? ?? false;

        for (final item in nodes) {
          final node = item as Map<String, dynamic>;
          final id = node['id'] as int;
          if (seenIds.contains(id)) continue;
          seenIds.add(id);

          final titleObj = node['title'] as Map<String, dynamic>?;
          final title = titleObj?['userPreferred'] ??
              titleObj?['english'] ??
              titleObj?['romaji'] ??
              '';
          final coverObj = node['coverImage'] as Map<String, dynamic>?;
          final cover = coverObj?['large'] ?? coverObj?['medium'] ?? '';
          final banner = node['bannerImage'] as String? ?? cover;

          final startDateObj = node['startDate'] as Map<String, dynamic>?;
          final year = startDateObj?['year']?.toString() ?? 'TBA';
          final status = node['status'] as String? ?? '';
          final groupTitle = status == 'CANCELLED' ? 'CANCELLED' : year;

          final media = Media(
            id: id,
            idMAL: node['idMal'] as int?,
            idAnilist: id,
            name: title as String,
            nameRomaji: (titleObj?['romaji'] ?? title) as String,
            userPreferredName: title,
            cover: cover as String,
            banner: banner,
            status: status,
            format: node['format'] as String?,
            isAdult: node['isAdult'] as bool? ?? false,
            meanScore: node['meanScore'] as int?,
            startDate: startDateObj != null
                ? FuzzyDate(
                    year: startDateObj['year'] as int?,
                    month: startDateObj['month'] as int?,
                    day: startDateObj['day'] as int?,
                  )
                : null,
            genres: (node['genres'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            anime: Anime(totalEpisodes: node['episodes'] as int?),
          );

          if (!yearMedia.containsKey(groupTitle)) {
            yearMedia[groupTitle] = [];
          }
          yearMedia[groupTitle]!.add(media);
        }

        page++;
      }

      if (yearMedia.containsKey('CANCELLED')) {
        final cancelled = yearMedia.remove('CANCELLED')!;
        yearMedia['CANCELLED'] = cancelled;
      }

      return studio(
        id: studioId,
        name: resolvedName,
        isAnimationStudio: isAnim,
        siteUrl: siteUrl,
        favourites: favs,
        media: yearMedia,
      );
    } catch (e) {
      debugPrint("Error in _getStudioDetails: $e");
      return null;
    }
  }
}
