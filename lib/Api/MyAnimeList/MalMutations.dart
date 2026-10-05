import 'package:dartotsu/DataClass/Media.dart';
import 'package:dartotsu/Functions/Function.dart';
import 'package:dartotsu/Functions/string_extensions.dart';
import 'package:dartotsu/Services/Api/Mutations.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../../Preferences/PrefManager.dart';
import '../../Services/ApiCacheManager.dart';
import 'Mal.dart';

class MalMutations extends Mutations {
  final Future<http.Response?> Function(
    String url, {
    String method,
    Map<String, String>? body,
  }) executeMutation;

  MalMutations(this.executeMutation);

  @override
  Future<void> setProgress(Media media, String episodeNumber) async {
    if (Mal.token.value.isEmpty) {
      debugPrint("MAL setProgress skipped: User is not logged into MAL");
      return;
    }

    final malId = media.idMAL ?? (media.mal ? media.id : null);
    if (malId == null || malId <= 0) {
      debugPrint("MAL setProgress error: Invalid MAL ID for media ${media.name}");
      return;
    }

    final progress = episodeNumber.toDouble().toInt();
    final isAnime = media.anime != null || (media.format != 'manga' && media.format != 'novel');

    final bool isCompleted;
    final String status;
    final String url;
    final Map<String, String> body;

    if (isAnime) {
      isCompleted = media.anime?.totalEpisodes != null &&
          media.anime!.totalEpisodes! > 0 &&
          progress >= media.anime!.totalEpisodes!;
      status = isCompleted ? "completed" : "watching";
      url = "https://api.myanimelist.net/v2/anime/$malId/my_list_status";
      body = {
        "status": status,
        "num_watched_episodes": progress.toString(),
      };
    } else {
      isCompleted = media.manga?.totalChapters != null &&
          media.manga!.totalChapters! > 0 &&
          progress >= media.manga!.totalChapters!;
      status = isCompleted ? "completed" : "reading";
      url = "https://api.myanimelist.net/v2/manga/$malId/my_list_status";
      body = {
        "status": status,
        "num_chapters_read": progress.toString(),
      };
    }

    try {
      final response = await executeMutation(url, method: 'PUT', body: body);
      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        media.userProgress = progress;
        media.userStatus = status;

        if (isAnime) {
          if (Mal.episodesWatched != null) {
            Mal.episodesWatched = Mal.episodesWatched! + 1;
            saveData(PrefName.malEpisodesWatched, Mal.episodesWatched!);
          }
        } else {
          if (Mal.chapterRead != null) {
            Mal.chapterRead = Mal.chapterRead! + 1;
            saveData(PrefName.malChaptersRead, Mal.chapterRead!);
          }
        }

        ApiCacheManager.instance.invalidate('mal_home_page');
        if (isAnime) {
          ApiCacheManager.instance.invalidate('mal_anime_page');
        } else {
          ApiCacheManager.instance.invalidate('mal_manga_page');
        }

        final homeRx = Refresh.activity[RefreshId.Mal.homePage];
        if (homeRx != null) {
          homeRx.value = true;
          homeRx.refresh();
        }
        final mediaRx = Refresh.activity[media.id];
        if (mediaRx != null) {
          mediaRx.value = true;
          mediaRx.refresh();
        }
        snackString("Setting progress to $progress");
      } else {
        debugPrint("MAL setProgress failed with status ${response?.statusCode}: ${response?.body}");
      }
    } catch (e) {
      debugPrint("MAL setProgress exception: $e");
    }
  }

  @override
  Future<void> editList(Media media, {List<String>? customList}) async {
    if (Mal.token.value.isEmpty) {
      debugPrint("MAL editList skipped: User is not logged into MAL");
      snackString("Please login to MyAnimeList first");
      return;
    }

    final malId = media.idMAL ?? (media.mal ? media.id : null);
    if (malId == null || malId <= 0) return;

    final isAnime = media.anime != null || (media.format != 'manga' && media.format != 'novel');
    final url = isAnime
        ? "https://api.myanimelist.net/v2/anime/$malId/my_list_status"
        : "https://api.myanimelist.net/v2/manga/$malId/my_list_status";

    final body = <String, String>{};
    final normalizedStatus = _normalizeMalStatus(
      media.userStatus ?? (isAnime ? "plan_to_watch" : "plan_to_read"),
      isAnime,
    );
    body["status"] = normalizedStatus;

    if (media.userScore != null && media.userScore! > 0) {
      // MAL uses 0-10 integer rating; userScore in Dartotsu is 0-100
      body["score"] = ((media.userScore! / 10).round()).clamp(0, 10).toString();
    } else if (media.userScore == 0) {
      body["score"] = "0";
    }

    if (media.userProgress != null) {
      if (isAnime) {
        body["num_watched_episodes"] = media.userProgress.toString();
      } else {
        body["num_chapters_read"] = media.userProgress.toString();
      }
    }
    if (media.notes != null) {
      body["comments"] = media.notes!;
    }
    if (media.userStartedAt != null && media.userStartedAt!.year != null) {
      final y = media.userStartedAt!.year;
      final m = (media.userStartedAt!.month ?? 1).toString().padLeft(2, '0');
      final d = (media.userStartedAt!.day ?? 1).toString().padLeft(2, '0');
      body["start_date"] = "$y-$m-$d";
    }
    if (media.userCompletedAt != null && media.userCompletedAt!.year != null) {
      final y = media.userCompletedAt!.year;
      final m = (media.userCompletedAt!.month ?? 1).toString().padLeft(2, '0');
      final d = (media.userCompletedAt!.day ?? 1).toString().padLeft(2, '0');
      body["finish_date"] = "$y-$m-$d";
    }
    final isRewatch = media.userRepeat > 0 ||
        media.userStatus?.toUpperCase() == 'REPEATING' ||
        media.userStatus?.toUpperCase() == 'REWATCHING' ||
        media.userStatus?.toUpperCase() == 'REREADING';
    if (isAnime) {
      if (isRewatch) body["is_rewatching"] = "true";
      if (media.userRepeat > 0) body["num_times_rewatched"] = media.userRepeat.toString();
    } else {
      if (isRewatch) body["is_rereading"] = "true";
      if (media.userRepeat > 0) body["num_times_reread"] = media.userRepeat.toString();
    }

    try {
      final response = await executeMutation(url, method: 'PUT', body: body);
      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        media.userStatus = body["status"];
        ApiCacheManager.instance.invalidate('mal_home_page');
        if (isAnime) {
          ApiCacheManager.instance.invalidate('mal_anime_page');
        } else {
          ApiCacheManager.instance.invalidate('mal_manga_page');
        }
        Refresh.activity[RefreshId.Mal.homePage]?.value = true;
        Refresh.activity[isAnime ? RefreshId.Mal.animePage : RefreshId.Mal.mangaPage]?.value = true;
        Refresh.activity[media.id]?.value = true;
        if (media.idMAL != null) {
          Refresh.activity[media.idMAL!]?.value = true;
        }
        snackString("Saved to your list");
      } else {
        snackString("Failed to save to MAL: ${response?.statusCode ?? 'network error'}");
      }
    } catch (e) {
      debugPrint("MAL editList exception: $e");
      snackString("Failed to save to MAL: $e");
    }
  }

  @override
  Future<void> deleteFromList(Media media) async {
    if (Mal.token.value.isEmpty) {
      snackString("Please login to MyAnimeList first");
      return;
    }

    final malId = media.idMAL ?? (media.mal ? media.id : null);
    if (malId == null || malId <= 0) return;

    final isAnime = media.anime != null || (media.format != 'manga' && media.format != 'novel');
    final url = isAnime
        ? "https://api.myanimelist.net/v2/anime/$malId/my_list_status"
        : "https://api.myanimelist.net/v2/manga/$malId/my_list_status";

    try {
      final response = await executeMutation(url, method: 'DELETE');
      if (response != null && (response.statusCode >= 200 && response.statusCode < 300 || response.statusCode == 404)) {
        media.userStatus = null;
        media.userProgress = null;
        media.userScore = 0;
        media.notes = null;
        media.userStartedAt = null;
        media.userCompletedAt = null;
        media.userRepeat = 0;

        ApiCacheManager.instance.invalidate('mal_home_page');
        if (isAnime) {
          ApiCacheManager.instance.invalidate('mal_anime_page');
        } else {
          ApiCacheManager.instance.invalidate('mal_manga_page');
        }

        Refresh.activity[RefreshId.Mal.homePage]?.value = true;
        Refresh.activity[isAnime ? RefreshId.Mal.animePage : RefreshId.Mal.mangaPage]?.value = true;
        Refresh.activity[media.id]?.value = true;
        if (media.idMAL != null) {
          Refresh.activity[media.idMAL!]?.value = true;
        }
        snackString("Removed ${media.mainName()} from your list");
      } else {
        snackString("Failed to remove from MAL: ${response?.statusCode ?? 'network error'}");
      }
    } catch (e) {
      debugPrint("MAL deleteFromList exception: $e");
      snackString("Failed to remove from MAL: $e");
    }
  }

  String _normalizeMalStatus(String status, bool isAnime) {
    final lower = status.toLowerCase().replaceAll(' ', '_');
    if (lower == 'current' || lower == 'watching' || lower == 'reading') {
      return isAnime ? 'watching' : 'reading';
    }
    if (lower == 'completed') return 'completed';
    if (lower == 'paused' || lower == 'on_hold' || lower == 'onhold') return 'on_hold';
    if (lower == 'dropped') return 'dropped';
    if (lower == 'planning' || lower == 'plan_to_watch' || lower == 'plan_to_read') {
      return isAnime ? 'plan_to_watch' : 'plan_to_read';
    }
    return isAnime ? 'watching' : 'reading';
  }
}
