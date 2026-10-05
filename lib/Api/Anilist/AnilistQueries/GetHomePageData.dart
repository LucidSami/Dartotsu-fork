part of '../AnilistQueries.dart';

extension on AnilistQueries {
  Future<Map<String, List<Media>>> _initHomePage({bool force = false}) async {
    try {
      if (!force) {
        final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('anilist_home_page');
        if (cached != null) {
          try {
            final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
            if (decoded.isNotEmpty && decoded.values.any((list) => list.isNotEmpty)) {
              return decoded;
            }
          } catch (e) {
            debugPrint("Failed to decode cached home page: $e");
          }
        }
      } else {
        ApiCacheManager.instance.invalidate('anilist_home_page');
      }

      // Ensure Anilist.userid is resolved if logged in
      if (Anilist.token.value.isNotEmpty && (Anilist.userid == null || Anilist.userid! <= 0)) {
        final cachedId = loadData(PrefName.anilistUserId);
        if (cachedId > 0) {
          Anilist.userid = cachedId;
        } else {
          try {
            await getUserData();
          } catch (_) {}
        }
      }

      final rawRemoveList = loadData(PrefName.anilistRemoveList);
      final Set<int> removeList = (rawRemoveList as List?)
              ?.map((e) => e is int ? e : int.tryParse(e.toString()))
              .whereType<int>()
              .toSet() ??
          <int>{};
      final bool hidePrivate = loadData(PrefName.anilistHidePrivate);
      List<Media> removedMedia = [];
      final homeLayoutMap = loadData(PrefName.anilistHomeLayout);

      var response = await executeQuery<UserListResponse>(_queryHomeList());
      if (response == null || response.data == null) {
        debugPrint("AniList home query failed or returned null response. Checking fallback cache.");
        final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('anilist_home_page');
        if (cached != null) {
          try {
            final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
            if (decoded.isNotEmpty) {
              return decoded;
            }
          } catch (e) {
            debugPrint("Failed to decode fallback cached home page: $e");
          }
        }
        return {};
      }

      Map<String, List<Media>> returnMap = {};

      Future<void> processMedia(String type, List<api.MediaList>? currentMedia,
          List<api.MediaList>? repeatingMedia) async {
        try {
          Map<int, Media> subMap = {};
          List<Media> returnArray = [];
          var isContinue = type == "Anime" || type == "Manga";
          final rawContinueList = loadCustomData<List>("continue${type}List");
          final List<int> continueList = rawContinueList
                  ?.map((e) => e is int ? e : int.tryParse(e.toString()))
                  .whereType<int>()
                  .toList() ??
              <int>[];

          for (var entry in (currentMedia ?? []) + (repeatingMedia ?? [])) {
            if (entry.media == null) continue;
            var media = Media.mediaListData(entry);
            if (!removeList.contains(media.id) &&
                (!hidePrivate || !media.isListPrivate)) {
              if (isContinue) {
                media.cameFromContinue = true;
              }
              subMap[media.id] = media;
            } else {
              removedMedia.add(media);
            }
          }

          if (continueList.isNotEmpty) {
            returnArray.addAll(continueList.reversed
                .where((id) => subMap.containsKey(id))
                .map((id) => subMap[id]!));
            returnArray
                .addAll(subMap.values.where((m) => !returnArray.contains(m)));
          } else {
            returnArray.addAll(subMap.values);
          }

          for (final m in returnArray) {
            TrackSyncManager.instance.recordUserMedia(m);
          }
          returnMap["current$type"] = returnArray;
        } catch (e, s) {
          debugPrint("Error in processMedia($type): $e\n$s");
        }
      }

      Future<void> processFavorites(
          String type, List<api.MediaEdge>? favorites) async {
        try {
          List<Media> returnArray = [];
          for (var entry in favorites ?? []) {
            if (entry.node == null) continue;
            var media = Media.mediaEdgeData(entry);
            if (!removeList.contains(media.id) &&
                (!hidePrivate || !media.isListPrivate)) {
              returnArray.add(media);
            } else {
              removedMedia.add(media);
            }
          }

          final missingIds = <int>[];
          for (final m in returnArray) {
            final cached = TrackSyncManager.instance.getUserMedia(m.id);
            if (cached != null && cached.userStatus != null) {
              m.userStatus = cached.userStatus;
              m.userProgress = cached.userProgress;
              m.userScore = cached.userScore;
              m.isListPrivate = cached.isListPrivate;
              m.notes = cached.notes;
              m.userRepeat = cached.userRepeat;
              m.userStartedAt = cached.userStartedAt;
              m.userCompletedAt = cached.userCompletedAt;
            } else {
              missingIds.add(m.id);
            }
            TrackSyncManager.instance.recordUserMedia(m);
          }

          if (missingIds.isNotEmpty && Anilist.userid != null && Anilist.userid! > 0) {
            try {
              final mediaListRes = await executeQuery<MediaResponse>('''
                {
                  Page {
                    mediaList(userId: ${Anilist.userid}, mediaId_in: $missingIds) {
                      mediaId
                      status
                      progress
                      score(format: POINT_100)
                      private
                      notes
                      repeat
                      startedAt { year month day }
                      completedAt { year month day }
                    }
                  }
                }
              ''');
              final entries = mediaListRes?.data?.page?.mediaList;
              if (entries != null) {
                for (final entry in entries) {
                  final match = returnArray.firstWhereOrNull((m) => m.id == entry.mediaId);
                  if (match != null) {
                    match.userStatus = entry.status?.name;
                    match.userProgress = entry.progress;
                    match.userScore = entry.score?.toInt() ?? 0;
                    match.isListPrivate = entry.private ?? false;
                    match.notes = entry.notes;
                    match.userRepeat = entry.repeat ?? 0;
                    match.userStartedAt = entry.startedAt;
                    match.userCompletedAt = entry.completedAt;
                    TrackSyncManager.instance.recordUserMedia(match);
                  }
                }
              }
            } catch (e) {
              debugPrint("Error batch enriching home favourites $type: $e");
            }
          }

          returnMap["favorite$type"] = returnArray;
        } catch (e, s) {
          debugPrint("Error in processFavorites($type): $e\n$s");
        }
      }

      List<api.MediaList> getMediaList(List<api.MediaListGroup>? lists) {
        return (lists?.expand((x) => x.entries ?? []) ?? [])
            .cast<api.MediaList>()
            .toList()
            .reversed
            .toList();
      }

      Future<void> processRecommended(
        List<Recommendation>? r,
        List<api.MediaList>? a,
        List<api.MediaList>? b,
      ) async {
        try {
          Map<int, Media> subMap = {};
          for (var entry in r ?? []) {
            var mediaRecommendation = entry.mediaRecommendation;
            if (mediaRecommendation != null) {
              var media = Media.mediaData(mediaRecommendation);
              media.relation = mediaRecommendation.type?.toString().split('.').last ?? "";
              subMap[media.id] = media;
            }
          }

          for (var entry in (a ?? []) + (b ?? [])) {
            if (entry.media == null) continue;
            var media = Media.mediaListData(entry);
            if (['RELEASING', 'FINISHED'].contains(media.status)) {
              media.relation = entry.media?.type?.toString().split('.').last ?? "";
              subMap[media.id] = media;
            }
          }

          List<Media> list = subMap.values.toList()
            ..sort((a, b) => (b.meanScore ?? 0).compareTo(a.meanScore ?? 0));
          returnMap["recommendations"] = list;
        } catch (e, s) {
          debugPrint("Error in processRecommended: $e\n$s");
        }
      }

      Map<String, Future<void> Function()> processMappings = {
        'Continue Watching': () => processMedia(
              "Anime",
              getMediaList(response.data?.currentAnime?.lists),
              getMediaList(response.data?.repeatingAnime?.lists),
            ),
        'Favourite Anime': () => processFavorites(
              "Anime",
              response.data?.favoriteAnime?.favourites?.anime?.edges,
            ),
        'Planned Anime': () => processMedia(
              "AnimePlanned",
              getMediaList(response.data?.plannedAnime?.lists),
              null,
            ),
        'Continue Reading': () => processMedia(
              "Manga",
              getMediaList(response.data?.currentManga?.lists),
              getMediaList(response.data?.repeatingManga?.lists),
            ),
        'Favourite Manga': () => processFavorites(
              "Manga",
              response.data?.favoriteManga?.favourites?.manga?.edges,
            ),
        'Planned Manga': () => processMedia(
              "MangaPlanned",
              getMediaList(response.data?.plannedManga?.lists),
              null,
            ),
        'Recommended': () => processRecommended(
              response.data?.recommendationQuery?.recommendations,
              getMediaList(
                  response.data?.recommendationPlannedQueryAnime?.lists),
              getMediaList(
                  response.data?.recommendationPlannedQueryManga?.lists),
            ),
      };

      await Future.wait(
        homeLayoutMap.entries
            .where((entry) =>
                (entry.value == true) && processMappings.containsKey(entry.key))
            .map((entry) => Future.sync(() => processMappings[entry.key]!()).catchError((err, st) {
                  debugPrint("Error processing home section '${entry.key}': $err\n$st");
                })),
      );

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

      returnMap["hidden"] = removedMedia.toSet().toList();
      final hasAnyData = returnMap.values.any((list) => list.isNotEmpty);
      if (hasAnyData) {
        try {
          ApiCacheManager.instance.set(
            'anilist_home_page',
            MediaMapWrapper(mediaMap: returnMap).toJson(),
            ttl: const Duration(minutes: 30),
          );
        } catch (_) {}
      }
      return returnMap;
    } catch (e, stack) {
      debugPrint("Error in _initHomePage: $e\n$stack");
      try {
        final cached = ApiCacheManager.instance.get<Map<String, dynamic>>('anilist_home_page');
        if (cached != null) {
          final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
          if (decoded.isNotEmpty) return decoded;
        }
      } catch (_) {}
      return {};
    }
  }
}

String _queryHomeList() {
  final homeLayoutMap = loadData(PrefName.anilistHomeLayout);
  final Map<String, List<String>> queryMappings = {
    'Continue Watching': [
      "currentAnime: ${_continueMediaQuery("ANIME", "CURRENT")}",
      "repeatingAnime: ${_continueMediaQuery("ANIME", "REPEATING")}"
    ],
    'Favourite Anime': ["favoriteAnime: ${_favMediaQuery(true, 1)}"],
    'Planned Anime': [
      "plannedAnime: ${_continueMediaQuery("ANIME", "PLANNING")}"
    ],
    'Continue Reading': [
      "currentManga: ${_continueMediaQuery("MANGA", "CURRENT")}",
      "repeatingManga: ${_continueMediaQuery("MANGA", "REPEATING")}"
    ],
    'Favourite Manga': ["favoriteManga: ${_favMediaQuery(false, 1)}"],
    'Planned Manga': [
      "plannedManga: ${_continueMediaQuery("MANGA", "PLANNING")}"
    ],
    'Recommended': [
      "recommendationQuery: ${_recommendationQuery()}",
      "recommendationPlannedQueryAnime: ${_recommendationPlannedQuery("ANIME")}",
      "recommendationPlannedQueryManga: ${_recommendationPlannedQuery("MANGA")}"
    ],
  };

  String generateOrderedQueries = homeLayoutMap.entries
      .where((entry) => (entry.value == true) && queryMappings.containsKey(entry.key))
      .expand((entry) => queryMappings[entry.key]!)
      .toList()
      .join(",");
  return "{$generateOrderedQueries}";
}

String _recommendationQuery() => '''
  Page(page: 1, perPage: 30) { 
    pageInfo { 
      total 
      currentPage 
      hasNextPage 
    } 
    recommendations(sort: RATING_DESC, onList: true) { 
      rating 
      userRating 
      mediaRecommendation { 
        id 
        idMal 
        isAdult 
        mediaListEntry { 
          progress 
          private 
          score(format: POINT_100) 
          status 
        } 
        chapters 
        isFavourite 
        format 
        episodes 
        nextAiringEpisode { episode airingAt timeUntilAiring } 
        popularity 
        meanScore 
        isFavourite 
        format 
        title { english romaji userPreferred } 
        type 
        status(version: 2) 
        bannerImage 
        coverImage { large } 
      } 
    } 
  }
''';

String _recommendationPlannedQuery(String type) => '''
  MediaListCollection(userId: ${Anilist.userid}, type: $type, status: PLANNING${type == "ANIME" ? ", sort: MEDIA_POPULARITY_DESC" : ""}) { 
    lists { 
      entries { 
        media { 
          id 
          mediaListEntry { 
            progress 
            private 
            score(format: POINT_100) 
            status 
          } 
          idMal 
          type 
          isAdult 
          popularity 
          status(version: 2) 
          chapters 
          episodes 
          nextAiringEpisode { episode airingAt timeUntilAiring } 
          meanScore 
          isFavourite 
          format 
          bannerImage 
          coverImage { large } 
          title { english romaji userPreferred } 
        } 
      } 
    } 
  }
''';

String _continueMediaQuery(String type, String status) => '''
  MediaListCollection(userId: ${Anilist.userid}, type: $type, status: $status, sort: UPDATED_TIME) { 
    lists { 
      entries { 
        progress 
        private 
        score(format: POINT_100) 
        status 
        media { 
          id 
          idMal 
          type 
          isAdult 
          status 
          chapters 
          episodes 
          nextAiringEpisode { episode airingAt timeUntilAiring } 
          meanScore 
          isFavourite 
          format 
          bannerImage 
          coverImage { large } 
          title { english romaji userPreferred } 
        } 
      } 
    } 
  }
''';

String _favMediaQuery(bool anime, int page) => '''
  User(id: ${Anilist.userid}) { 
    id 
    favourites { 
      ${anime ? "anime" : "manga"}(page: $page) { 
        pageInfo { hasNextPage } 
        edges { 
          favouriteOrder 
          node { 
            id 
            idMal 
            isAdult 
            mediaListEntry { 
              progress 
              private 
              score(format: POINT_100) 
              status 
            } 
            chapters 
            isFavourite 
            format 
            episodes 
            nextAiringEpisode { episode airingAt timeUntilAiring } 
            meanScore 
            isFavourite 
            format 
            startDate { year month day } 
            title { english romaji userPreferred } 
            type 
            status(version: 2) 
            bannerImage 
            coverImage { large } 
          } 
        } 
      } 
    } 
  }
''';
