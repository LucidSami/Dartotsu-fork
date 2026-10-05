import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../Api/Anilist/Anilist.dart';
import '../Api/Anilist/Screen/AnilistHomeScreen.dart';
import '../Api/MyAnimeList/Mal.dart';
import '../Api/MyAnimeList/Screen/MalHomeScreen.dart';
import '../DataClass/Media.dart';
import '../Functions/Function.dart';
import '../Functions/string_extensions.dart';
import '../Preferences/PrefManager.dart';
import '../Screens/MediaList/MediaListViewModel.dart';
import 'ApiCacheManager.dart';

class TrackSyncManager {
  static final TrackSyncManager instance = TrackSyncManager._internal();
  TrackSyncManager._internal();

  final Map<int, int> _malToAnilistIdMap = {};
  final Map<int, int> _anilistToMalIdMap = {};
  final Map<int, int> _recentProgressMap = {};
  final Map<int, Media> _userMediaCache = {};

  int? getRecentProgress(int mediaId) => _recentProgressMap[mediaId];

  Media? getUserMedia(int mediaId) => _userMediaCache[mediaId];

  void recordUserMedia(Media media) {
    if (media.userStatus != null) {
      _userMediaCache[media.id] = media;
      if (media.idMAL != null) _userMediaCache[media.idMAL!] = media;
      if (media.idAnilist != null) _userMediaCache[media.idAnilist!] = media;
    }
  }

  void recordProgress(int mediaId, int progress) {
    _recentProgressMap[mediaId] = progress;
    final cached = _userMediaCache[mediaId];
    if (cached != null) {
      cached.userProgress = progress;
    }
  }

  bool _matchesMedia(Media a, Media b) {
    if (a.id == b.id) return true;
    if (b.idMAL != null && a.idMAL != null && a.idMAL == b.idMAL) return true;
    if (b.idMAL != null && a.id == b.idMAL) return true;
    if (b.idAnilist != null && a.id == b.idAnilist) return true;
    if (a.idMAL != null && a.idMAL == b.id) return true;
    final mappedAnilistId =
        _malToAnilistIdMap[b.id] ?? (b.idMAL != null ? _malToAnilistIdMap[b.idMAL!] : null);
    if (mappedAnilistId != null && a.id == mappedAnilistId) return true;
    final mappedMalId =
        _anilistToMalIdMap[b.id] ?? (b.idAnilist != null ? _anilistToMalIdMap[b.idAnilist!] : null);
    if (mappedMalId != null && (a.id == mappedMalId || a.idMAL == mappedMalId)) return true;
    return false;
  }

  void _invalidateMediaCaches(Media media) {
    ApiCacheManager.instance.invalidate('anilist_home_page');
    ApiCacheManager.instance.invalidate('mal_home_page');
    ApiCacheManager.instance.invalidate('anilist_anime_page');
    ApiCacheManager.instance.invalidate('anilist_manga_page');
    ApiCacheManager.instance.invalidate('mal_anime_page');
    ApiCacheManager.instance.invalidate('mal_manga_page');
    ApiCacheManager.instance.invalidate('mal_animelist');
    ApiCacheManager.instance.invalidate('mal_mangalist');
    ApiCacheManager.instance.invalidate('anilist_details_${media.id}');
    ApiCacheManager.instance.invalidate('mal_details_${media.id}');
    if (media.idMAL != null) {
      ApiCacheManager.instance.invalidate('anilist_details_${media.idMAL}');
      ApiCacheManager.instance.invalidate('mal_details_${media.idMAL}');
    }
    if (media.idAnilist != null) {
      ApiCacheManager.instance.invalidate('anilist_details_${media.idAnilist}');
      ApiCacheManager.instance.invalidate('mal_details_${media.idAnilist}');
    }
    final anilistId = _malToAnilistIdMap[media.id];
    if (anilistId != null) {
      ApiCacheManager.instance.invalidate('anilist_details_$anilistId');
    }
    final malId = _anilistToMalIdMap[media.id];
    if (malId != null) {
      ApiCacheManager.instance.invalidate('mal_details_$malId');
    }
  }

  void _updateLiveCardProgress(
    Media media,
    int progress, {
    String? status,
    int? score,
  }) {
    // 1. Invalidate all associated caches instantly so stale data is never read
    _invalidateMediaCaches(media);

    final isAnime = media.anime != null ||
        (media.format != 'manga' && media.format != 'novel' && media.format != 'one_shot');

    // 2. Optimistically update AnilistHomeScreen in memory
    try {
      if (Get.isRegistered<AnilistHomeScreen>(tag: "AnilistHomeScreen")) {
        final anilistHome = Get.find<AnilistHomeScreen>(tag: "AnilistHomeScreen");

        void updateAnilistList(Rx<List<Media>?> rxList, {bool isContinueList = false}) {
          final list = rxList.value;
          if (list == null) return;
          final updatedList = List<Media>.from(list);
          int foundIndex = -1;
          for (int i = 0; i < updatedList.length; i++) {
            if (_matchesMedia(updatedList[i], media)) {
              foundIndex = i;
              updatedList[i]
                ..userProgress = progress
                ..userStatus = status ?? updatedList[i].userStatus
                ..userScore = score ?? updatedList[i].userScore;
              break;
            }
          }

          if (isContinueList) {
            if (foundIndex > 0) {
              final item = updatedList.removeAt(foundIndex);
              updatedList.insert(0, item);
            } else if (foundIndex == -1 && (status == 'CURRENT' || status == null)) {
              final newCard = Media(
                id: media.id,
                idMAL: media.idMAL,
                idAnilist: media.idAnilist,
                mal: false,
                name: media.name,
                nameRomaji: media.nameRomaji,
                userPreferredName: media.userPreferredName,
                cover: media.cover,
                banner: media.banner,
                anime: media.anime,
                manga: media.manga,
                format: media.format,
                status: media.status,
                userProgress: progress,
                userStatus: status ?? 'CURRENT',
                cameFromContinue: true,
                cameFromHome: true,
              );
              updatedList.insert(0, newCard);
            }
          }

          rxList.value = updatedList;
          rxList.refresh();
        }

        if (isAnime) {
          updateAnilistList(anilistHome.animeContinue, isContinueList: true);
          updateAnilistList(anilistHome.animeFav);
          updateAnilistList(anilistHome.animePlanned);
        } else {
          updateAnilistList(anilistHome.mangaContinue, isContinueList: true);
          updateAnilistList(anilistHome.mangaFav);
          updateAnilistList(anilistHome.mangaPlanned);
        }
      }
    } catch (e) {
      debugPrint("Optimistic update error for AniList home: $e");
    }

    // 3. Optimistically update MalHomeScreen in memory
    try {
      if (Get.isRegistered<MalHomeScreen>(tag: "MalHomeScreen")) {
        final malHome = Get.find<MalHomeScreen>(tag: "MalHomeScreen");

        void updateMalList(Rx<List<Media>?> rxList, {bool isContinueList = false}) {
          final list = rxList.value;
          if (list == null) return;
          final updatedList = List<Media>.from(list);
          int foundIndex = -1;
          for (int i = 0; i < updatedList.length; i++) {
            if (_matchesMedia(updatedList[i], media)) {
              foundIndex = i;
              updatedList[i]
                ..userProgress = progress
                ..userStatus = status ?? updatedList[i].userStatus
                ..userScore = score ?? updatedList[i].userScore;
              break;
            }
          }

          if (isContinueList) {
            if (foundIndex > 0) {
              final item = updatedList.removeAt(foundIndex);
              updatedList.insert(0, item);
            } else if (foundIndex == -1 &&
                (status == 'watching' ||
                    status == 'reading' ||
                    status == 'CURRENT' ||
                    status == null)) {
              final newCard = Media(
                id: media.idMAL ?? media.id,
                idMAL: media.idMAL ?? media.id,
                mal: true,
                name: media.name,
                nameRomaji: media.nameRomaji,
                userPreferredName: media.userPreferredName,
                cover: media.cover,
                banner: media.banner,
                anime: media.anime,
                manga: media.manga,
                format: media.format,
                status: media.status,
                userProgress: progress,
                userStatus: status ?? (isAnime ? 'watching' : 'reading'),
                cameFromContinue: true,
                cameFromHome: true,
              );
              updatedList.insert(0, newCard);
            }
          }

          rxList.value = updatedList;
          rxList.refresh();
        }

        if (isAnime) {
          updateMalList(malHome.animeContinue, isContinueList: true);
          updateMalList(malHome.animePlanned);
          updateMalList(malHome.animeOnHold);
          updateMalList(malHome.animeDropped);
        } else {
          updateMalList(malHome.mangaContinue, isContinueList: true);
          updateMalList(malHome.mangaPlanned);
          updateMalList(malHome.mangaOnHold);
          updateMalList(malHome.mangaDropped);
        }
      }
    } catch (e) {
      debugPrint("Optimistic update error for MAL home: $e");
    }

    // 4. Optimistically update MediaListViewModel if active
    try {
      if (Get.isRegistered<MediaListViewModel>()) {
        final vm = Get.find<MediaListViewModel>();
        if (vm.mediaList.value != null) {
          final currentMap = vm.mediaList.value!;
          bool changed = false;
          for (final key in currentMap.keys) {
            final list = currentMap[key];
            if (list != null) {
              for (final m in list) {
                if (_matchesMedia(m, media)) {
                  m.userProgress = progress;
                  if (status != null) m.userStatus = status;
                  if (score != null) m.userScore = score;
                  changed = true;
                }
              }
            }
          }
          if (changed) {
            vm.mediaList.refresh();
          }
        }
      }
    } catch (e) {
      debugPrint("Optimistic update error for MediaListViewModel: $e");
    }

    // 5. Trigger reactive refresh signals for detail & player screens
    Refresh.activity[media.id]?.value = true;
    Refresh.activity[media.id]?.refresh();
    if (media.idMAL != null) {
      Refresh.activity[media.idMAL!]?.value = true;
      Refresh.activity[media.idMAL!]?.refresh();
    }
    if (media.idAnilist != null) {
      Refresh.activity[media.idAnilist!]?.value = true;
      Refresh.activity[media.idAnilist!]?.refresh();
    }
  }

  void _removeLiveCard(Media media) {
    _invalidateMediaCaches(media);

    try {
      if (Get.isRegistered<AnilistHomeScreen>(tag: "AnilistHomeScreen")) {
        final anilistHome = Get.find<AnilistHomeScreen>(tag: "AnilistHomeScreen");
        void removeFromList(Rx<List<Media>?> rxList) {
          final list = rxList.value;
          if (list == null) return;
          final updated = List<Media>.from(list)..removeWhere((m) => _matchesMedia(m, media));
          rxList.value = updated;
          rxList.refresh();
        }
        removeFromList(anilistHome.animeContinue);
        removeFromList(anilistHome.animeFav);
        removeFromList(anilistHome.animePlanned);
        removeFromList(anilistHome.mangaContinue);
        removeFromList(anilistHome.mangaFav);
        removeFromList(anilistHome.mangaPlanned);
      }
    } catch (_) {}

    try {
      if (Get.isRegistered<MalHomeScreen>(tag: "MalHomeScreen")) {
        final malHome = Get.find<MalHomeScreen>(tag: "MalHomeScreen");
        void removeFromList(Rx<List<Media>?> rxList) {
          final list = rxList.value;
          if (list == null) return;
          final updated = List<Media>.from(list)..removeWhere((m) => _matchesMedia(m, media));
          rxList.value = updated;
          rxList.refresh();
        }
        removeFromList(malHome.animeContinue);
        removeFromList(malHome.animePlanned);
        removeFromList(malHome.animeOnHold);
        removeFromList(malHome.animeDropped);
        removeFromList(malHome.mangaContinue);
        removeFromList(malHome.mangaPlanned);
        removeFromList(malHome.mangaOnHold);
        removeFromList(malHome.mangaDropped);
      }
    } catch (_) {}

    try {
      if (Get.isRegistered<MediaListViewModel>()) {
        final vm = Get.find<MediaListViewModel>();
        if (vm.mediaList.value != null) {
          for (final key in vm.mediaList.value!.keys) {
            vm.mediaList.value![key]?.removeWhere((m) => _matchesMedia(m, media));
          }
          vm.mediaList.refresh();
        }
      }
    } catch (_) {}

    Refresh.activity[media.id]?.value = true;
    Refresh.activity[media.id]?.refresh();
    if (media.idMAL != null) {
      Refresh.activity[media.idMAL!]?.value = true;
      Refresh.activity[media.idMAL!]?.refresh();
    }
    if (media.idAnilist != null) {
      Refresh.activity[media.idAnilist!]?.value = true;
      Refresh.activity[media.idAnilist!]?.refresh();
    }
  }

  /// Syncs episode / chapter progress according to the 3 scenarios:
  /// 1. MAL logged in, AniList isn't -> only MAL tracks, AniList ignored silently without errors
  /// 2. AniList logged in, MAL isn't -> AniList tracks, MAL ignored silently without errors
  /// 3. Both logged in -> Track BOTH AniList and MAL simultaneously
  Future<void> syncProgress({
    required Media media,
    required String episodeOrChapterNumber,
  }) async {
    final saveProgress =
        loadCustomData<bool>("${media.id}-saveProgress") ??
        loadCustomData<bool>("${media.id}-AniList-saveProgress") ??
        loadCustomData<bool>("${media.id}-MyAnimeList-saveProgress") ??
        true;

    if (!saveProgress) {
      debugPrint("TrackSyncManager: Progress saving disabled for ${media.name}");
      return;
    }

    final bool anilistLoggedIn =
        Anilist.token.value.isNotEmpty && Anilist.userid != null;
    final bool malLoggedIn = Mal.token.value.isNotEmpty;

    debugPrint(
      "TrackSyncManager: AniList logged in: $anilistLoggedIn | MAL logged in: $malLoggedIn | Title: ${media.name}",
    );

    final progress = episodeOrChapterNumber.toDouble().toInt();
    media.userProgress = progress;
    _recentProgressMap[media.id] = progress;
    if (media.idMAL != null) _recentProgressMap[media.idMAL!] = progress;

    // Instantly update live cards in memory and invalidate cache (0ms)
    _updateLiveCardProgress(
      media,
      progress,
      status: media.userStatus ?? 'CURRENT',
    );

    if (!anilistLoggedIn && !malLoggedIn) {
      debugPrint(
        "TrackSyncManager: Neither provider is logged in. Remote progress sync ignored silently.",
      );
      return;
    }

    final futures = <Future<void>>[];

    // Scenario 2 & 3: AniList logged in
    if (anilistLoggedIn) {
      futures.add(_syncAnilist(media, episodeOrChapterNumber));
    }

    // Scenario 1 & 3: MAL logged in
    if (malLoggedIn) {
      futures.add(_syncMal(media, episodeOrChapterNumber));
    }

    try {
      await Future.wait(futures);
    } catch (e) {
      debugPrint("TrackSyncManager sync error: $e");
    } finally {
      ApiCacheManager.instance.invalidate('anilist_home_page');
      ApiCacheManager.instance.invalidate('mal_home_page');
      final malHomeRx = Refresh.activity[RefreshId.Mal.homePage];
      if (malHomeRx != null) {
        malHomeRx.value = true;
        malHomeRx.refresh();
      }
      final anilistHomeRx = Refresh.activity[RefreshId.Anilist.homePage];
      if (anilistHomeRx != null) {
        anilistHomeRx.value = true;
        anilistHomeRx.refresh();
      }
    }
  }

  Future<void> _syncAnilist(Media media, String episodeOrChapterNumber) async {
    try {
      if (Anilist.mutations == null) return;

      if (!media.mal) {
        // Active media is native to AniList (media.id is AniList ID)
        await Anilist.mutations!.setProgress(media, episodeOrChapterNumber);
      } else {
        // Active media is from MAL (media.id is MAL ID).
        final malId = media.id;
        int? anilistId = _malToAnilistIdMap[malId];
        Media? anilistMedia;

        if (anilistId != null) {
          anilistMedia = Media(
            id: anilistId,
            idMAL: malId,
            mal: false,
            name: media.name,
            nameRomaji: media.nameRomaji,
            userPreferredName: media.userPreferredName,
            anime: media.anime,
            manga: media.manga,
            format: media.format,
            status: media.status,
            userProgress: media.userProgress,
            userStatus: media.userStatus,
          );
        } else {
          anilistMedia = await Anilist.query?.getMedia(malId, mal: true);
          if (anilistMedia != null) {
            _malToAnilistIdMap[malId] = anilistMedia.id;
          }
        }

        if (anilistMedia != null) {
          await Anilist.mutations!.setProgress(
            anilistMedia,
            episodeOrChapterNumber,
          );
        } else {
          debugPrint(
            "TrackSyncManager: AniList entry not found for MAL ID $malId (ignored silently)",
          );
        }
      }
    } catch (e) {
      debugPrint("TrackSyncManager: AniList sync ignored silently on error: $e");
    }
  }

  Future<void> _syncMal(Media media, String episodeOrChapterNumber) async {
    try {
      if (Mal.mutations == null) return;

      if (media.mal) {
        // Active media is native to MAL (media.id is MAL ID)
        await Mal.mutations!.setProgress(media, episodeOrChapterNumber);
      } else {
        // Active media is from AniList.
        var malId = media.idMAL ?? _anilistToMalIdMap[media.id];
        if (malId == null || malId <= 0) {
          debugPrint(
            "TrackSyncManager: No MAL ID on AniList media ${media.name} (ignored silently)",
          );
          return;
        }

        _anilistToMalIdMap[media.id] = malId;

        final malMedia = Media(
          id: malId,
          idMAL: malId,
          mal: true,
          name: media.name,
          nameRomaji: media.nameRomaji,
          userPreferredName: media.userPreferredName,
          anime: media.anime,
          manga: media.manga,
          format: media.format,
          status: media.status,
          userProgress: media.userProgress,
          userStatus: media.userStatus,
        );
        await Mal.mutations!.setProgress(malMedia, episodeOrChapterNumber);
      }
    } catch (e) {
      debugPrint("TrackSyncManager: MAL sync ignored silently on error: $e");
    }
  }

  Future<void> syncEditList({
    required Media media,
    bool fromMal = false,
    List<String>? customList,
  }) async {
    final bool anilistLoggedIn =
        Anilist.token.value.isNotEmpty && Anilist.userid != null;
    final bool malLoggedIn = Mal.token.value.isNotEmpty;

    recordUserMedia(media);

    if (media.userProgress != null) {
      _recentProgressMap[media.id] = media.userProgress!;
      if (media.idMAL != null) _recentProgressMap[media.idMAL!] = media.userProgress!;
    }

    // Instantly update live cards in memory and invalidate cache (0ms)
    _updateLiveCardProgress(
      media,
      media.userProgress ?? 0,
      status: media.userStatus,
      score: media.userScore,
    );

    if (fromMal) {
      await Mal.mutations?.editList(media);

      if (anilistLoggedIn) {
        try {
          final malId = media.idMAL ?? (media.mal ? media.id : null);
          if (malId != null) {
            int? anilistId = _malToAnilistIdMap[malId];
            Media? anilistMedia;
            if (anilistId != null) {
              anilistMedia = Media(
                id: anilistId,
                idMAL: malId,
                mal: false,
                name: media.name,
                nameRomaji: media.nameRomaji,
                userPreferredName: media.userPreferredName,
                anime: media.anime,
                manga: media.manga,
                format: media.format,
                status: media.status,
              );
            } else {
              anilistMedia = await Anilist.query?.getMedia(malId, mal: true);
              if (anilistMedia != null) {
                _malToAnilistIdMap[malId] = anilistMedia.id;
              }
            }

            if (anilistMedia != null) {
              anilistMedia
                ..userStatus = _mapMalStatusToAnilist(media.userStatus)
                ..userProgress = media.userProgress
                ..userScore = media.userScore
                ..notes = media.notes
                ..userStartedAt = media.userStartedAt
                ..userCompletedAt = media.userCompletedAt
                ..userRepeat = media.userRepeat;
              await Anilist.mutations?.editList(anilistMedia);
              ApiCacheManager.instance.invalidate('anilist_home_page');
              Refresh.activity[RefreshId.Anilist.homePage]?.value = true;
              Refresh.activity[anilistMedia.id]?.value = true;
            }
          }
        } catch (e) {
          debugPrint("TrackSyncManager: Sync edit to AniList error: $e");
        }
      }
    } else {
      await Anilist.mutations?.editList(media, customList: customList);

      if (malLoggedIn) {
        try {
          var malId = media.idMAL ?? _anilistToMalIdMap[media.id];
          if (malId == null || malId <= 0) {
            final fetched = await Anilist.query?.getMedia(media.id);
            if (fetched?.idMAL != null) {
              malId = fetched!.idMAL;
            }
          }
          if (malId != null && malId > 0) {
            _anilistToMalIdMap[media.id] = malId;
            final isAnime = media.anime != null ||
                (media.format != 'manga' && media.format != 'novel');
            final malMedia = Media(
              id: malId,
              idMAL: malId,
              mal: true,
              name: media.name,
              nameRomaji: media.nameRomaji,
              userPreferredName: media.userPreferredName,
              anime: media.anime,
              manga: media.manga,
              format: media.format,
              status: media.status,
            )
              ..userStatus = _mapAnilistStatusToMal(media.userStatus, isAnime)
              ..userProgress = media.userProgress
              ..userScore = media.userScore
              ..notes = media.notes
              ..userStartedAt = media.userStartedAt
              ..userCompletedAt = media.userCompletedAt
              ..userRepeat = media.userRepeat;
            await Mal.mutations?.editList(malMedia);
            ApiCacheManager.instance.invalidate('mal_home_page');
            Refresh.activity[RefreshId.Mal.homePage]?.value = true;
            Refresh.activity[malId]?.value = true;
          }
        } catch (e) {
          debugPrint("TrackSyncManager: Sync edit to MAL error: $e");
        }
      }
    }

    Refresh.activity[media.id]?.value = true;
    if (media.idMAL != null) Refresh.activity[media.idMAL!]?.value = true;
  }

  Future<void> syncDeleteFromList({
    required Media media,
    bool fromMal = false,
  }) async {
    final bool anilistLoggedIn =
        Anilist.token.value.isNotEmpty && Anilist.userid != null;
    final bool malLoggedIn = Mal.token.value.isNotEmpty;

    // Instantly remove live card from memory and invalidate cache (0ms)
    _removeLiveCard(media);

    if (fromMal) {
      await Mal.mutations?.deleteFromList(media);
      if (anilistLoggedIn) {
        try {
          final malId = media.idMAL ?? (media.mal ? media.id : null);
          if (malId != null) {
            int? anilistId = _malToAnilistIdMap[malId];
            if (anilistId == null) {
              final anilistMedia = await Anilist.query?.getMedia(malId, mal: true);
              anilistId = anilistMedia?.id;
            }
            if (anilistId != null) {
              await Anilist.mutations?.deleteFromList(Media(
                id: anilistId,
                mal: false,
                nameRomaji: media.nameRomaji,
                userPreferredName: media.userPreferredName,
              ));
              ApiCacheManager.instance.invalidate('anilist_home_page');
              Refresh.activity[RefreshId.Anilist.homePage]?.value = true;
              Refresh.activity[anilistId]?.value = true;
            }
          }
        } catch (e) {
          debugPrint("TrackSyncManager: Sync delete to AniList error: $e");
        }
      }
    } else {
      await Anilist.mutations?.deleteFromList(media);
      if (malLoggedIn) {
        try {
          var malId = media.idMAL ?? _anilistToMalIdMap[media.id];
          if (malId != null && malId > 0) {
            await Mal.mutations?.deleteFromList(Media(
              id: malId,
              idMAL: malId,
              mal: true,
              nameRomaji: media.nameRomaji,
              userPreferredName: media.userPreferredName,
            ));
            ApiCacheManager.instance.invalidate('mal_home_page');
            Refresh.activity[RefreshId.Mal.homePage]?.value = true;
            Refresh.activity[malId]?.value = true;
          }
        } catch (e) {
          debugPrint("TrackSyncManager: Sync delete to MAL error: $e");
        }
      }
    }

    _userMediaCache.remove(media.id);
    if (media.idMAL != null) _userMediaCache.remove(media.idMAL!);
    if (media.idAnilist != null) _userMediaCache.remove(media.idAnilist!);

    Refresh.activity[media.id]?.value = true;
    if (media.idMAL != null) Refresh.activity[media.idMAL!]?.value = true;
  }

  static String _mapMalStatusToAnilist(String? malStatus) {
    if (malStatus == null || malStatus.isEmpty) return "PLANNING";
    final s = malStatus.toLowerCase().replaceAll(' ', '_');
    if (s == 'watching' || s == 'reading' || s == 'current') return 'CURRENT';
    if (s == 'completed') return 'COMPLETED';
    if (s == 'on_hold' || s == 'paused' || s == 'onhold') return 'PAUSED';
    if (s == 'dropped') return 'DROPPED';
    if (s == 'plan_to_watch' || s == 'plan_to_read' || s == 'planning') return 'PLANNING';
    if (s == 'rewatching' || s == 'rereading' || s == 'repeating') return 'REPEATING';
    return 'CURRENT';
  }

  static String _mapAnilistStatusToMal(String? anilistStatus, bool isAnime) {
    if (anilistStatus == null || anilistStatus.isEmpty) {
      return isAnime ? 'plan_to_watch' : 'plan_to_read';
    }
    final s = anilistStatus.toUpperCase();
    if (s == 'CURRENT' || s == 'WATCHING' || s == 'READING') {
      return isAnime ? 'watching' : 'reading';
    }
    if (s == 'PLANNING' || s == 'PLAN TO WATCH' || s == 'PLAN TO READ') {
      return isAnime ? 'plan_to_watch' : 'plan_to_read';
    }
    if (s == 'COMPLETED') return 'completed';
    if (s == 'PAUSED' || s == 'ON HOLD') return 'on_hold';
    if (s == 'DROPPED') return 'dropped';
    if (s == 'REPEATING' || s == 'REWATCHING' || s == 'REREADING') {
      return isAnime ? 'watching' : 'reading';
    }
    return isAnime ? 'watching' : 'reading';
  }
}
