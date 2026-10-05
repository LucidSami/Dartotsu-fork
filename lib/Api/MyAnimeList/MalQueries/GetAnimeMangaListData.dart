part of '../MalQueries.dart';

extension on MalQueries {
  static const field =
      "fields=mean,num_list_users,status,nsfw,mean,my_list_status,num_episodes,num_chapters,genres,media_type";

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
          if (decoded.isNotEmpty) return decoded;
        } catch (_) {}
      }
    } else {
      ApiCacheManager.instance.invalidate('mal_anime_page');
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

      final Map<String, String> queryMappings = {
        'topAiring':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=airing&limit=50&$field',
        'trendingMovies':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=movie&limit=50&$field',
        'topRatedSeries':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=tv&limit=50&$field',
        'mostFavouriteSeries':
            '${MalStrings.endPoint}anime/ranking?offset=0&ranking_type=favorite&limit=50&$field',
      };

      final tasks = <String, Future<MediaResponse?>>{
        'popularAnime': executeQuery<MediaResponse>(popularUrl),
        'trendingAnime': executeQuery<MediaResponse>(trendingUrl),
      };

      queryMappings.forEach((key, url) {
        tasks[key] = executeQuery<MediaResponse>(url);
      });

      final taskResults = await Future.wait(tasks.values);
      final keys = tasks.keys.toList();

      for (var i = 0; i < keys.length; i++) {
        final mediaRes = taskResults[i];
        if (mediaRes != null) {
          list[keys[i]] = await processMediaResponse(mediaRes);
        } else {
          list[keys[i]] = [];
        }
      }
      if (list.isNotEmpty) {
        try {
          ApiCacheManager.instance.set(
            'mal_anime_page',
            MediaMapWrapper(mediaMap: list).toJson(),
            ttl: const Duration(minutes: 15),
          );
        } catch (_) {}
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
          if (decoded.isNotEmpty) return decoded;
        } catch (_) {}
      }
    } else {
      ApiCacheManager.instance.invalidate('mal_manga_page');
    }

    final list = <String, List<Media>>{};
    try {
      final popularUrl =
          '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=bypopularity&limit=50&$field';
      final trendingUrl =
          '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manga&limit=12&$field';

      final Map<String, String> queryMappings = {
        'trendingManhwa':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manhwa&limit=50&$field',
        'trendingNovels':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=novels&limit=50&$field',
        'topRatedManga':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=manga&limit=50&$field',
        'mostFavouriteManga':
            '${MalStrings.endPoint}manga/ranking?offset=0&ranking_type=favorite&limit=50&$field',
      };

      final tasks = <String, Future<MediaResponse?>>{
        'popularManga': executeQuery<MediaResponse>(popularUrl),
        'trendingManga': executeQuery<MediaResponse>(trendingUrl),
      };

      queryMappings.forEach((key, url) {
        tasks[key] = executeQuery<MediaResponse>(url);
      });

      final taskResults = await Future.wait(tasks.values);
      final keys = tasks.keys.toList();

      for (var i = 0; i < keys.length; i++) {
        final mediaRes = taskResults[i];
        if (mediaRes != null) {
          list[keys[i]] = await processMediaResponse(mediaRes);
        } else {
          list[keys[i]] = [];
        }
      }
      if (list.isNotEmpty) {
        try {
          ApiCacheManager.instance.set(
            'mal_manga_page',
            MediaMapWrapper(mediaMap: list).toJson(),
            ttl: const Duration(minutes: 15),
          );
        } catch (_) {}
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
    return await processMediaResponse(
        await executeQuery<MediaResponse>(year != null ? anime : manga));
  }

  Future<List<Media>> _loadNextPage(String type, int page) async {
    final offset = (page - 1) * 50;
    return await processMediaResponse(await executeQuery<MediaResponse>(
        '${MalStrings.endPoint}$type/ranking?offset=$offset&ranking_type=bypopularity&limit=50&$field'));
  }

  Future<List<Media>> _loadRankingPage(
    String type,
    String rankingType,
    int page, {
    int limit = 50,
  }) async {
    final offset = (page - 1) * limit;
    return await processMediaResponse(await executeQuery<MediaResponse>(
        '${MalStrings.endPoint}$type/ranking?offset=$offset&ranking_type=$rankingType&limit=$limit&$field'));
  }
}
