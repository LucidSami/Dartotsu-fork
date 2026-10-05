part of '../MalQueries.dart';

extension on MalQueries {
  static const field =
      "fields=mean,num_list_users,status,nsfw,my_list_status,num_episodes,num_chapters,genres,media_type,start_date,end_date";

  Future<List<Media>> processMediaResponse(MediaResponse? data) async {
    if (data?.data == null || data!.data!.isEmpty) return [];
    try {
      return data.data!
          .where((m) => m.node != null)
          .map((m) => Media.fromMal(m.node!))
          .toList();
    } catch (e) {
      debugPrint("Error in processMediaResponse: $e");
      return [];
    }
  }

  Future<Map<String, List<Media>>> _getAnimeList({bool force = false}) async {
    final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_anime_page');
    Map<String, List<Media>>? cachedMap;
    if (cached != null) {
      try {
        cachedMap = MediaMapWrapper.fromJson(cached).mediaMap;
        if (!force && cachedMap.values.any((items) => items.isNotEmpty)) return cachedMap;
      } catch (_) {}
    }

    final list = <String, List<Media>>{};
    try {
      final currentSeasonMap = Mal.currentSeasons[1];
      final season = currentSeasonMap.keys.first;
      final year = currentSeasonMap.values.first;

      final popularUrl =
          '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=bypopularity&limit=50&$field';
      final trendingUrl =
          '${MalStrings.endPoint}anime/season/$year/$season?limit=15&offset=1&sort=anime_num_list_users&$field';

      final animeLayout = Map<dynamic, dynamic>.from(loadData(PrefName.malAnimeLayout));
      final Map<String, String> optionalQueries = {
        'topAiring':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=airing&limit=50&$field',
        'trendingMovies':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=movie&limit=50&$field',
        'topRatedSeries':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=tv&limit=50&$field',
        'mostFavouriteSeries':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=favorite&limit=50&$field',
      };

      final Map<String, String> layoutTitles = {
        'topAiring': 'Top Airing',
        'trendingMovies': 'Trending Movies',
        'topRatedSeries': 'Top Rated Series',
        'mostFavouriteSeries': 'Most Favourite Series',
      };

      final Map<String, String> queries = {
        'popularAnime': popularUrl,
        'trendingAnime': trendingUrl,
      };

      for (var entry in optionalQueries.entries) {
        final title = layoutTitles[entry.key];
        if (title != null && (animeLayout[title] ?? true) == true) {
          queries[entry.key] = entry.value;
        }
      }

      await Future.wait(
        queries.entries.map((entry) async {
          try {
            final mediaRes = await executeQuery<MediaResponse>(
              entry.value,
              priority: MalPriority.normal,
            );
            if (mediaRes != null) {
              list[entry.key] = await processMediaResponse(mediaRes);
            } else if (cachedMap != null && cachedMap[entry.key]?.isNotEmpty == true) {
              list[entry.key] = cachedMap[entry.key]!;
            } else {
              list[entry.key] = [];
            }
          } catch (e) {
            debugPrint("Error fetching ${entry.key}: $e");
            if (cachedMap != null && cachedMap[entry.key]?.isNotEmpty == true) {
              list[entry.key] = cachedMap[entry.key]!;
            } else {
              list[entry.key] = [];
            }
          }
        }),
      );

      final hasValidData = list.values.any((items) => items.isNotEmpty);
      if (hasValidData) {
        try {
          ApiCacheManager.instance.set(
            'mal_anime_page',
            MediaMapWrapper(mediaMap: list).toJson(),
            ttl: const Duration(minutes: 15),
          );
        } catch (_) {}
      } else if (cachedMap != null && cachedMap.values.any((items) => items.isNotEmpty)) {
        return cachedMap;
      }
    } catch (e) {
      Logger.log('Error in _getAnimeList: $e');
      if (cachedMap != null && cachedMap.values.any((items) => items.isNotEmpty)) {
        return cachedMap;
      }
    }
    return list;
  }

  Future<Map<String, List<Media>>> _getMangaList({bool force = false}) async {
    final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_manga_page');
    Map<String, List<Media>>? cachedMap;
    if (cached != null) {
      try {
        cachedMap = MediaMapWrapper.fromJson(cached).mediaMap;
        if (!force && cachedMap.values.any((items) => items.isNotEmpty)) return cachedMap;
      } catch (_) {}
    }

    final list = <String, List<Media>>{};
    try {
      final popularUrl =
          '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=bypopularity&limit=50&$field';
      final trendingUrl =
          '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manga&limit=12&$field';

      final mangaLayout = Map<dynamic, dynamic>.from(loadData(PrefName.malMangaLayout));
      final Map<String, String> optionalQueries = {
        'trendingManhwa':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manhwa&limit=50&$field',
        'trendingNovels':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=novels&limit=50&$field',
        'topRatedManga':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manga&limit=50&$field',
        'mostFavouriteManga':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=favorite&limit=50&$field',
      };

      final Map<String, String> layoutTitles = {
        'trendingManhwa': 'Trending Manhwa',
        'trendingNovels': 'Trending Novels',
        'topRatedManga': 'Top Rated Manga',
        'mostFavouriteManga': 'Most Favourite Manga',
      };

      final Map<String, String> queries = {
        'popularManga': popularUrl,
      };

      for (var entry in optionalQueries.entries) {
        final title = layoutTitles[entry.key];
        if (title != null && (mangaLayout[title] ?? true) == true) {
          queries[entry.key] = entry.value;
        }
      }

      // If topRatedManga is not requested, query trendingManga separately; otherwise derive it from topRatedManga
      final shouldDeriveTrending = queries.containsKey('topRatedManga');
      if (!shouldDeriveTrending) {
        queries['trendingManga'] = trendingUrl;
      }

      await Future.wait(
        queries.entries.map((entry) async {
          try {
            final mediaRes = await executeQuery<MediaResponse>(
              entry.value,
              priority: MalPriority.normal,
            );
            if (mediaRes != null) {
              list[entry.key] = await processMediaResponse(mediaRes);
            } else if (cachedMap != null && cachedMap[entry.key]?.isNotEmpty == true) {
              list[entry.key] = cachedMap[entry.key]!;
            } else {
              list[entry.key] = [];
            }
          } catch (e) {
            debugPrint("Error fetching ${entry.key}: $e");
            if (cachedMap != null && cachedMap[entry.key]?.isNotEmpty == true) {
              list[entry.key] = cachedMap[entry.key]!;
            } else {
              list[entry.key] = [];
            }
          }
        }),
      );

      // Reuse topRatedManga for trendingManga to save a duplicate network query
      if (shouldDeriveTrending) {
        list['trendingManga'] = (list['topRatedManga'] ?? []).take(12).toList();
      }

      final hasValidData = list.values.any((items) => items.isNotEmpty);
      if (hasValidData) {
        try {
          ApiCacheManager.instance.set(
            'mal_manga_page',
            MediaMapWrapper(mediaMap: list).toJson(),
            ttl: const Duration(minutes: 15),
          );
        } catch (_) {}
      } else if (cachedMap != null && cachedMap.values.any((items) => items.isNotEmpty)) {
        return cachedMap;
      }
    } catch (e) {
      Logger.log('Error in _getMangaList: $e');
      if (cachedMap != null && cachedMap.values.any((items) => items.isNotEmpty)) {
        return cachedMap;
      }
    }
    return list;
  }

  Future<List<Media>> _getTrending({String? year, String? season}) async {
    // season is also used to gets manga type
    var anime =
        '${MalStrings.endPoint}anime/season/$year/$season?limit=15&offset=1&sort=anime_num_list_users&$field';
    var manga =
        '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=$season&limit=15&$field';
    final res = await executeQuery<MediaResponse>(year != null ? anime : manga);
    return await processMediaResponse(res);
  }

  Future<List<Media>?> _loadNextPage(String type, int page) async {
    final offset = (page - 1) * 50;
    final res = await executeQuery<MediaResponse>(
        '${MalStrings.endPoint}$type/ranking?offset=$offset&ranking_type=bypopularity&limit=50&$field');
    if (res == null) return null;
    return await processMediaResponse(res);
  }

  Future<List<Media>?> _loadRankingPage(
    String type,
    String rankingType,
    int page, {
    int limit = 50,
  }) async {
    final offset = (page - 1) * limit;
    final res = await executeQuery<MediaResponse>(
        '${MalStrings.endPoint}$type/ranking?offset=$offset&ranking_type=$rankingType&limit=$limit&$field');
    if (res == null) return null;
    return await processMediaResponse(res);
  }
}
