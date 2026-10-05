import 'dart:async';
import 'dart:convert';

import 'package:dartotsu/Services/BaseServiceData.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../Functions/Function.dart';
import '../../NetworkManager/NetworkManager.dart';
import '../../Preferences/PrefManager.dart';
import '../../Widgets/CustomBottomDialog.dart';
import '../TypeFactory.dart';
import 'AnilistMutations.dart';
import 'AnilistQueries.dart';
import 'Login.dart' as anilist_login;

var Anilist = Get.put(AnilistController());

class AnilistController extends BaseServiceData {
  List<String>? genres;
  Map<bool, List<String>>? tags;
  int rateLimitReset = 0;
  String? titleLanguage;
  String? staffNameLanguage;
  bool airingNotifications = false;
  bool restrictMessagesToFollowing = false;
  String? scoreFormat;
  String? rowOrder;
  int? activityMergeTime;
  String? timezone;
  List<String>? animeCustomLists;
  List<String>? mangaCustomLists;

  final List<String> sortBy = [
    "SCORE_DESC",
    "POPULARITY_DESC",
    "TRENDING_DESC",
    "START_DATE_DESC",
    "TITLE_ENGLISH",
    "TITLE_ENGLISH_DESC",
    "SCORE",
  ];
  var source = [
    "ORIGINAL",
    "MANGA",
    "LIGHT NOVEL",
    "VISUAL NOVEL",
    "VIDEO GAME",
    "OTHER",
    "NOVEL",
    "DOUJINSHI",
    "ANIME",
    "WEB NOVEL",
    "LIVE ACTION",
    "GAME",
    "COMIC",
    "MULTIMEDIA PROJECT",
    "PICTURE BOOK",
  ];

  var animeStatus = ["FINISHED", "RELEASING", "NOT YET RELEASED", "CANCELLED"];

  var status = [
    "PLANNING",
    "CURRENT",
    "COMPLETED",
    "REPEATING",
    "PAUSED",
    "DROPPED",
  ];
  var mangaStatus = [
    "FINISHED",
    "RELEASING",
    "NOT YET RELEASED",
    "HIATUS",
    "CANCELLED",
  ];

  var animeFormats = [
    "TV",
    "TV SHORT",
    "MOVIE",
    "SPECIAL",
    "OVA",
    "ONA",
    "MUSIC",
  ];

  var mangaFormats = ["MANGA", "NOVEL", "ONE SHOT"];

  final List<String> authorRoles = ["Original Creator", "Story & Art", "Story"];
  final List<String> seasons = ["WINTER", "SPRING", "SUMMER", "FALL"];
  final int currentYear = DateTime.now().year;
  final int currentMonth = DateTime.now().month;

  AnilistController() {
    query = AnilistQueries(executeQuery);
    mutations = AnilistMutations(executeQuery);
  }

  int get currentSeason {
    if (currentMonth <= 2) return 0;
    if (currentMonth <= 5) return 1;
    if (currentMonth <= 8) return 2;
    if (currentMonth <= 11) return 3;
    return 0;
  }

  Map<String, int> getSeason(bool next) {
    int season = currentSeason + (next ? 1 : -1);
    int year = currentYear;
    if (season > 3) {
      season = 0;
      year++;
    } else if (season < 0) {
      season = 3;
      year--;
    }
    return {seasons[season]: year};
  }

  List<Map<String, int>> get currentSeasons => [
    getSeason(false),
    {seasons[currentSeason]: currentYear},
    getSeason(true),
  ];

  @override
  bool getSavedToken() {
    token.value = loadData(PrefName.anilistToken);

    final cachedUsername = loadData(PrefName.anilistUsername);
    if (cachedUsername.isNotEmpty) {
      username.value = cachedUsername;
    }
    final cachedAvatar = loadData(PrefName.anilistAvatar);
    if (cachedAvatar.isNotEmpty) {
      avatar.value = cachedAvatar;
    }
    final cachedId = loadData(PrefName.anilistUserId);
    if (cachedId > 0) {
      userid = cachedId;
    }

    query?.getGenresAndTags();
    if (token.isNotEmpty) query?.getUserData();

    return token.isNotEmpty;
  }

  @override
  Future<void> saveToken(String token) async {
    saveData(PrefName.anilistToken, token);
    this.token.value = token;
    run.value = true;
    isInitialized.value = false;
    query?.getUserData();
    Refresh.refreshService(RefreshId.Anilist);
  }

  @override
  void login(BuildContext context) =>
      showCustomBottomDialog(context, anilist_login.login(context));

  @override
  void removeSavedToken() {
    token.value = '';
    username.value = '';
    adult = false;
    userid = null;
    avatar.value = '';
    bg.value = '';
    episodesWatched = null;
    chapterRead = null;
    unreadNotificationCount = 0;
    removeData(PrefName.anilistToken);
    removeData(PrefName.anilistUsername);
    removeData(PrefName.anilistAvatar);
    removeData(PrefName.anilistUserId);
    removeCustomData("banner_ANIME_url");
    removeCustomData("banner_MANGA_url");
    run.value = true;
    isInitialized.value = false;
    Refresh.refreshService(RefreshId.Anilist);
  }

  final AnilistRateLimiter rateLimiter = AnilistRateLimiter();
  static DateTime _lastToastTime = DateTime.fromMillisecondsSinceEpoch(0);

  static void _showThrottledToast(String message) {
    final now = DateTime.now();
    if (now.difference(_lastToastTime).inSeconds >= 5) {
      _lastToastTime = now;
      snackString(message);
    }
  }

  Future<T?> executeQuery<T>(
    String query, {
    String variables = "",
    bool force = false,
    bool useToken = true,
    bool show = true,
  }) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await rateLimiter.waitForSlot();

        final headers = {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          if (token.isNotEmpty && useToken)
            'Authorization': 'Bearer ${token.value}',
        };

        final response = await Get.find<NetworkManager>().compatibleClient.post(
          Uri.parse("https://graphql.anilist.co/"),
          headers: headers,
          body: jsonEncode({"query": query.trim(), "variables": variables}),
        );

        // Update dynamic rate limit spacing based on response headers
        final remainingHeader = response.headers['x-ratelimit-remaining'] ?? response.headers['X-RateLimit-Remaining'];
        final remaining = int.tryParse(remainingHeader ?? '');
        if (remaining != null) {
          rateLimiter.updateRemaining(remaining);
        }

        if (response.statusCode == 429) {
          final retryHeader = response.headers['retry-after'] ?? response.headers['Retry-After'];
          final resetHeader = response.headers['x-ratelimit-reset'] ?? response.headers['X-RateLimit-Reset'];
          final retrySec = int.tryParse(retryHeader ?? '') ?? (attempt * 5);
          final resetTimestamp = int.tryParse(resetHeader ?? '');
          final currentEpochSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          rateLimitReset = (resetTimestamp != null && resetTimestamp > currentEpochSec)
              ? resetTimestamp
              : (currentEpochSec + retrySec);

          final waitSec = (rateLimitReset - currentEpochSec).clamp(1, 65);
          debugPrint("AniList returned 429. Cooldown $waitSec seconds (attempt $attempt/3).");
          rateLimiter.setCooldown(DateTime.now().add(Duration(seconds: waitSec)));
          if (show) _showThrottledToast("AniList rate limit reached. Waiting ${waitSec}s...");

          if (attempt < 3) {
            continue;
          } else {
            return null;
          }
        }

        if (!response.body.startsWith("{")) {
          if (show) snackString("Anilist seems down, maybe use a VPN or wait.");
          return null;
        }

        final jsonResponse = json.decode(response.body);
        if (jsonResponse == null || jsonResponse.containsKey('errors')) return null;

        return TypeFactory.get<T>(jsonResponse);
      } catch (e) {
        if (attempt == 3) {
          if (show) snackString("Error fetching Anilist data: ${e.toString()}");
          debugPrint("Error fetching Anilist data: ${e.toString()}");
          return null;
        }
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return null;
  }
}

class AnilistRateLimiter {
  static const int maxRequestsPerMinute = 80; // AniList hard limit is 90/min
  int minIntervalMs = 250;
  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  final List<Completer<void>> _waitQueue = [];
  bool _isProcessing = false;
  int requestCount = 0;
  DateTime resetTime = DateTime.now().add(const Duration(minutes: 1));
  DateTime? _cooldownUntil;

  Future<void> waitForSlot() async {
    final completer = Completer<void>();
    _waitQueue.add(completer);
    _processQueue();
    return completer.future;
  }

  void setCooldown(DateTime until) {
    _cooldownUntil = until;
  }

  void updateRemaining(int remaining) {
    if (remaining < 5) {
      minIntervalMs = 1500;
    } else if (remaining < 15) {
      minIntervalMs = 600;
    } else {
      minIntervalMs = 250;
    }
  }

  void _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    while (_waitQueue.isNotEmpty) {
      // Respect 429 cooldown if set
      if (_cooldownUntil != null) {
        final now = DateTime.now();
        if (_cooldownUntil!.isAfter(now)) {
          final wait = _cooldownUntil!.difference(now) + const Duration(milliseconds: 200);
          await Future.delayed(wait);
        }
        _cooldownUntil = null;
      }

      final now = DateTime.now();
      if (now.isAfter(resetTime)) {
        requestCount = 0;
        resetTime = now.add(const Duration(minutes: 1));
      }

      if (requestCount >= maxRequestsPerMinute) {
        final waitDuration = resetTime.difference(now);
        if (waitDuration > Duration.zero) {
          await Future.delayed(waitDuration + const Duration(milliseconds: 100));
        }
        requestCount = 0;
        resetTime = DateTime.now().add(const Duration(minutes: 1));
      }

      final elapsed = DateTime.now().difference(_lastRequestTime).inMilliseconds;
      if (elapsed < minIntervalMs) {
        await Future.delayed(Duration(milliseconds: minIntervalMs - elapsed));
      }

      _lastRequestTime = DateTime.now();
      requestCount++;
      final next = _waitQueue.removeAt(0);
      if (!next.isCompleted) next.complete();
    }
    _isProcessing = false;
  }

  int get remainingRequests => (maxRequestsPerMinute - requestCount).clamp(0, maxRequestsPerMinute);
}
