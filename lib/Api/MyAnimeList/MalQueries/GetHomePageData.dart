part of '../MalQueries.dart';

extension on MalQueries {
  static const field =
      "fields=mean,num_list_users,status,nsfw,my_list_status,num_episodes,num_chapters,genres,media_type,start_date,end_date";

  Future<Map<String, List<Media>>> _initHomePage({bool force = false}) async {
    try {
      if (!force) {
        final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_home_page');
        if (cached != null) {
          try {
            final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
            if (decoded.entries.any((e) => e.key != 'hidden' && e.value.isNotEmpty)) {
              return decoded;
            }
          } catch (_) {}
        }
      }

      final animeUrl =
          '${MalStrings.endPoint}users/@me/animelist?$field&limit=1000&sort=list_updated_at&nsfw=1';
      final mangaUrl =
          '${MalStrings.endPoint}users/@me/mangalist?$field&limit=1000&sort=list_updated_at&nsfw=1';

      MediaResponse? animeRes;
      MediaResponse? mangaRes;
      try {
        animeRes = await executeQuery<MediaResponse>(animeUrl, force: force);
      } catch (e) {
        Logger.log('Error fetching MAL animelist: $e');
      }
      try {
        mangaRes = await executeQuery<MediaResponse>(mangaUrl, force: force);
      } catch (e) {
        Logger.log('Error fetching MAL mangalist: $e');
      }

      List<Media> animeProcessed = [];
      List<Media> mangaProcessed = [];
      if (animeRes != null) {
        animeRes.data?.forEach((m) => m.node?.mediaType = 'anime');
        try {
          animeProcessed = await processMediaResponse(animeRes);
        } catch (e) {
          Logger.log('Error processing MAL anime response: $e');
        }
      }
      if (mangaRes != null) {
        mangaRes.data?.forEach((m) => m.node?.mediaType = 'manga');
        try {
          mangaProcessed = await processMediaResponse(mangaRes);
        } catch (e) {
          Logger.log('Error processing MAL manga response: $e');
        }
      }

      var animeList = groupBy(animeProcessed, (Media m) => m.userStatus ?? 'other');
      var mangaList = groupBy(mangaProcessed, (Media m) => m.userStatus ?? 'other');

      final removeList = loadData(PrefName.malRemoveList);
      List<Media> removedMedia = [];

      Map<String, List<Media>> returnMap = {};

      if (animeList['watching'] != null) {
        var watchingList = animeList['watching']!;
        for (var m in watchingList) {
          m.cameFromContinue = true;
        }
        List<int> continueList = List<int>.from(
          loadCustomData<List<int>>("continueAnimeList") ?? [],
        );
        if (continueList.isNotEmpty) {
          Map<int, Media> watchingMap = {for (var m in watchingList) m.id: m};
          List<Media> sortedWatching = [];
          for (var id in continueList.reversed) {
            if (watchingMap.containsKey(id)) {
              sortedWatching.add(watchingMap[id]!);
            }
          }
          sortedWatching.addAll(
            watchingMap.values.where((m) => !sortedWatching.contains(m)),
          );
          returnMap['Watching'] = sortedWatching;
        } else {
          returnMap['Watching'] = watchingList;
        }
      }
      if (animeList['on_hold'] != null) {
        returnMap['OnHold'] = animeList['on_hold']!;
      }
      if (animeList['dropped'] != null) {
        returnMap['Dropped'] = animeList['dropped']!;
      }
      if (animeList['plan_to_watch'] != null) {
        returnMap['PlanToWatch'] = animeList['plan_to_watch']!;
      }

      if (mangaList['reading'] != null) {
        var readingList = mangaList['reading']!;
        for (var m in readingList) {
          m.cameFromContinue = true;
        }
        List<int> continueList = List<int>.from(
          loadCustomData<List<int>>("continueMangaList") ?? [],
        );
        if (continueList.isNotEmpty) {
          Map<int, Media> readingMap = {for (var m in readingList) m.id: m};
          List<Media> sortedReading = [];
          for (var id in continueList.reversed) {
            if (readingMap.containsKey(id)) {
              sortedReading.add(readingMap[id]!);
            }
          }
          sortedReading.addAll(
            readingMap.values.where((m) => !sortedReading.contains(m)),
          );
          returnMap['Reading'] = sortedReading;
        } else {
          returnMap['Reading'] = readingList;
        }
      }
      if (mangaList['on_hold'] != null) {
        returnMap['OnHoldReading'] = mangaList['on_hold']!;
      }
      if (mangaList['dropped'] != null) {
        returnMap['DroppedReading'] = mangaList['dropped']!;
      }
      if (mangaList['plan_to_read'] != null) {
        returnMap['PlanToRead'] = mangaList['plan_to_read']!;
      }

      List<Media> mediaToRemove = [];

      for (var m in returnMap.values) {
        for (var media in m) {
          if (removeList.contains(media.id)) {
            mediaToRemove.add(media);
          }
        }
      }
      for (var media in mediaToRemove) {
        removedMedia.add(media);
        for (var element in returnMap.values) {
          element.remove(media);
        }
      }
      returnMap['hidden'] = removedMedia;

      for (var list in returnMap.values) {
        for (var media in list) {
          media.cameFromHome = true;
          final recent = TrackSyncManager.instance.getRecentProgress(media.id) ??
              (media.idMAL != null ? TrackSyncManager.instance.getRecentProgress(media.idMAL!) : null);
          if (recent != null && (media.userProgress == null || recent > media.userProgress!)) {
            media.userProgress = recent;
          }
        }
      }
      final hasValidHomeData = returnMap.entries.any((e) => e.key != 'hidden' && e.value.isNotEmpty);
      if (hasValidHomeData) {
        try {
          ApiCacheManager.instance.set(
            'mal_home_page',
            MediaMapWrapper(mediaMap: returnMap).toJson(),
            ttl: const Duration(minutes: 30),
          );
        } catch (_) {}
      } else {
        // Fallback to cache if network returned no valid entries
        final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_home_page');
        if (cached != null) {
          try {
            final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
            if (decoded.entries.any((e) => e.key != 'hidden' && e.value.isNotEmpty)) {
              return decoded;
            }
          } catch (_) {}
        }
      }
      return returnMap;
    } catch (e) {
      Logger.log('Error in initHomePage $e');
      final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('mal_home_page');
      if (cached != null) {
        try {
          final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
          if (decoded.entries.any((e) => e.key != 'hidden' && e.value.isNotEmpty)) {
            return decoded;
          }
        } catch (_) {}
      }
      return {};
    }
  }

  Future<Map<String, List<Media>>> _getMediaLists({required bool anime}) async {
    try {
      final endpoint = anime
          ? 'https://api.myanimelist.net/v2/users/@me/animelist?$field&limit=1000&sort=list_updated_at&nsfw=1'
          : 'https://api.myanimelist.net/v2/users/@me/mangalist?$field&limit=1000&sort=list_updated_at&nsfw=1';

      final res = await executeQuery<MediaResponse>(endpoint);
      res?.data?.forEach((m) => m.node?.mediaType = anime ? 'anime' : 'manga');
      final allMedia = await processMediaResponse(res);

      final grouped =
          groupBy(allMedia, (Media m) => m.userStatus?.toLowerCase() ?? 'other');

      final Map<String, List<Media>> result = {};
      if (anime) {
        result['Watching'] = grouped['watching'] ?? [];
        result['Completed'] = grouped['completed'] ?? [];
        result['On Hold'] = grouped['on_hold'] ?? [];
        result['Dropped'] = grouped['dropped'] ?? [];
        result['Planning'] = grouped['plan_to_watch'] ?? [];
      } else {
        result['Reading'] = grouped['reading'] ?? [];
        result['Completed'] = grouped['completed'] ?? [];
        result['On Hold'] = grouped['on_hold'] ?? [];
        result['Dropped'] = grouped['dropped'] ?? [];
        result['Planning'] = grouped['plan_to_read'] ?? [];
      }
      result['All'] = allMedia;
      return result;
    } catch (e) {
      Logger.log('Error in _getMediaLists: $e');
      if (anime) {
        return {
          'Watching': [],
          'Completed': [],
          'On Hold': [],
          'Dropped': [],
          'Planning': [],
          'All': [],
        };
      } else {
        return {
          'Reading': [],
          'Completed': [],
          'On Hold': [],
          'Dropped': [],
          'Planning': [],
          'All': [],
        };
      }
    }
  }
}
