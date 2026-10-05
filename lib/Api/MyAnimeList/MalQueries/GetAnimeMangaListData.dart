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
    if (!force) {
      final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_anime_page');
      if (cached != null) {
        try {
          final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
          if (decoded.values.any((items) => items.isNotEmpty)) return decoded;
        } catch (_) {}
      }
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

      final Map<String, String> queries = {
        'popularAnime': popularUrl,
        'trendingAnime': trendingUrl,
        'topAiring':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=airing&limit=50&$field',
        'trendingMovies':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=movie&limit=50&$field',
        'topRatedSeries':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=tv&limit=50&$field',
        'mostFavouriteSeries':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=favorite&limit=50&$field',
      };

      for (var entry in queries.entries) {
        try {
          final mediaRes = await executeQuery<MediaResponse>(entry.value);
          if (mediaRes != null) {
            list[entry.key] = await processMediaResponse(mediaRes);
          } else {
            list[entry.key] = [];
          }
        } catch (e) {
          debugPrint("Error fetching ${entry.key}: $e");
          list[entry.key] = [];
        }
      }

      final hasValidData = list.values.any((items) => items.isNotEmpty);
      if (hasValidData) {
        try {
          ApiCacheManager.instance.set(
            'mal_anime_page',
            MediaMapWrapper(mediaMap: list).toJson(),
            ttl: const Duration(minutes: 15),
          );
        } catch (_) {}
      } else {
        // Fallback to cache if all queries failed or throttled
        final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_anime_page');
        if (cached != null) {
          try {
            final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
            if (decoded.values.any((items) => items.isNotEmpty)) return decoded;
          } catch (_) {}
        }
      }
    } catch (e) {
      Logger.log('Error in _getAnimeList: $e');
    }
    return list;
  }

  Future<Map<String, List<Media>>> _getMangaList({bool force = false}) async {
    if (!force) {
      final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_manga_page');
      if (cached != null) {
        try {
          final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
          if (decoded.values.any((items) => items.isNotEmpty)) return decoded;
        } catch (_) {}
      }
    }

    final list = <String, List<Media>>{};
    try {
      final popularUrl =
          '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=bypopularity&limit=50&$field';
      final trendingUrl =
          '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manga&limit=12&$field';

      final Map<String, String> queries = {
        'popularManga': popularUrl,
        'trendingManga': trendingUrl,
        'trendingManhwa':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manhwa&limit=50&$field',
        'trendingNovels':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=novels&limit=50&$field',
        'topRatedManga':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manga&limit=50&$field',
        'mostFavouriteManga':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=favorite&limit=50&$field',
      };

      for (var entry in queries.entries) {
        try {
          final mediaRes = await executeQuery<MediaResponse>(entry.value);
          if (mediaRes != null) {
            list[entry.key] = await processMediaResponse(mediaRes);
          } else {
            list[entry.key] = [];
          }
        } catch (e) {
          debugPrint("Error fetching ${entry.key}: $e");
          list[entry.key] = [];
        }
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
      } else {
        // Fallback to cache if all queries failed or throttled
        final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_manga_page');
        if (cached != null) {
          try {
            final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
            if (decoded.values.any((items) => items.isNotEmpty)) return decoded;
          } catch (_) {}
        }
      }
    } catch (e) {
      Logger.log('Error in _getMangaList: $e');
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
