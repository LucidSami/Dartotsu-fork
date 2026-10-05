import 'package:flutter/foundation.dart';
import '../Api/Anilist/Anilist.dart';
import '../Api/MyAnimeList/Mal.dart';
import '../DataClass/Media.dart';
import '../Functions/Function.dart';
import '../Functions/string_extensions.dart';
import '../Preferences/PrefManager.dart';
import 'ApiCacheManager.dart';

class TrackSyncManager {
  static final TrackSyncManager instance = TrackSyncManager._internal();
  TrackSyncManager._internal();

  final Map<int, int> _malToAnilistIdMap = {};
  final Map<int, int> _anilistToMalIdMap = {};
  final Map<int, int> _recentProgressMap = {};

  int? getRecentProgress(int mediaId) => _recentProgressMap[mediaId];

  void recordProgress(int mediaId, int progress) {
    _recentProgressMap[mediaId] = progress;
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

    if (media.userProgress != null) {
      _recentProgressMap[media.id] = media.userProgress!;
      if (media.idMAL != null) _recentProgressMap[media.idMAL!] = media.userProgress!;
    }

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
