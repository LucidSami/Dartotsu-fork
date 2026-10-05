import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../Functions/Function.dart';
import '../../Preferences/IsarDataClasses/MalToken/MalToken.dart';
import '../../Preferences/PrefManager.dart';
import '../../Services/BaseServiceData.dart';
import '../../Widgets/CustomBottomDialog.dart';
import '../TypeFactory.dart';
import 'Login.dart' as MalLogin;
import 'MalMutations.dart';
import 'MalQueries.dart';
import 'MalQueries/MalStrings.dart';

var Mal = Get.put(MalController());

class MalController extends BaseServiceData {
  MalController() {
    query = MalQueries(executeQuery);
    mutations = MalMutations(executeMutation);
  }

  final List<String> animeStatus = [
    "PLAN TO WATCH",
    "WATCHING",
    "COMPLETED",
    "ON HOLD",
    "DROPPED",
  ];

  final List<String> mangaStatus = [
    "PLAN TO READ",
    "READING",
    "COMPLETED",
    "ON HOLD",
    "DROPPED",
  ];

  List<String> getStatusList(bool isAnime) => isAnime ? animeStatus : mangaStatus;

  final List<String> seasons = ["winter", "spring", "summer", "fall"];
  final int currentYear = DateTime.now().year;
  final int currentMonth = DateTime.now().month;

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
    }
    if (season < 0) {
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
    var malToken = loadData(PrefName.malToken);
    if (malToken == null) return false;
    token.value = malToken.accessToken;

    final cachedUsername = loadData(PrefName.malUsername);
    if (cachedUsername.isNotEmpty) {
      username.value = cachedUsername;
    }
    final cachedAvatar = loadData(PrefName.malAvatar);
    if (cachedAvatar.isNotEmpty) {
      avatar.value = cachedAvatar;
      bg.value = cachedAvatar;
    }
    final cachedId = loadData(PrefName.malUserId);
    if (cachedId > 0) {
      userid = cachedId;
    }
    final cachedEpisodes = loadData(PrefName.malEpisodesWatched);
    if (cachedEpisodes >= 0) {
      episodesWatched = cachedEpisodes;
    }
    final cachedChapters = loadData(PrefName.malChaptersRead);
    chapterRead = cachedChapters >= 0 ? cachedChapters : 0;
    if (cachedUsername.isNotEmpty && cachedId > 0) {
      isInitialized.value = true;
    }

    if (token.isNotEmpty && !isInitialized.value) {
      getToken().then((m) {
        query?.getUserData();
      });
    }
    return token.isNotEmpty;
  }

  final _loadingToken = false.obs;

  Future<void> getToken() async {
    var malToken = loadData(PrefName.malToken);
    if (malToken == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= (malToken.expiresIn - 300000)) {
      if (_loadingToken.value) {
        int waitCount = 0;
        while (_loadingToken.value == true && waitCount < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }
        if (waitCount >= 50) _loadingToken.value = false;
        final refreshedToken = loadData(PrefName.malToken);
        if (refreshedToken != null) {
          token.value = refreshedToken.accessToken;
        }
        return;
      }
      _loadingToken.value = true;
      try {
        malToken = await refreshToken();
      } catch (e) {
        debugPrint("Error refreshing MAL token: $e");
        return;
      } finally {
        _loadingToken.value = false;
      }
      if (malToken == null) return;
    }
    token.value = malToken.accessToken;
  }

  @override
  void login(BuildContext context) =>
      showCustomBottomDialog(context, MalLogin.login(context));

  @override
  void removeSavedToken() {
    removeData(PrefName.malToken);
    removeData(PrefName.malUsername);
    removeData(PrefName.malAvatar);
    removeData(PrefName.malUserId);
    removeData(PrefName.malEpisodesWatched);
    removeData(PrefName.malChaptersRead);
    token.value = '';
    username.value = '';
    adult = false;
    userid = null;
    avatar.value = '';
    bg.value = '';
    episodesWatched = 0;
    chapterRead = 0;
    unreadNotificationCount = 0;
    run.value = true;
    isInitialized.value = false;
    Refresh.refreshService(RefreshId.Mal);
  }

  @override
  Future<void> saveToken(String token) async {
    var res = ResponseToken.fromJson(json.decode(token));
    res.expiresIn =
        DateTime.now().millisecondsSinceEpoch + (res.expiresIn * 1000);
    saveData<ResponseToken?>(PrefName.malToken, res);
    this.token.value = res.accessToken;
    isInitialized.value = false;
    run.value = true;
    try {
      await (query as MalQueries?)?.getUserData(force: true);
    } catch (e) {
      debugPrint("Error fetching user data in saveToken: $e");
    }
    Refresh.refreshService(RefreshId.Mal);
  }

  Future<ResponseToken?> refreshToken() async {
    final malToken = loadData(PrefName.malToken);
    if (malToken == null || malToken.refreshToken.isEmpty) {
      throw Exception('Failed to load refresh token');
    }
    final response = await http.post(
      Uri.parse('https://myanimelist.net/v1/oauth2/token'),
      body: {
        'client_id': MalStrings.clientId,
        'grant_type': 'refresh_token',
        'refresh_token': malToken.refreshToken,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final res = ResponseToken.fromJson(json.decode(response.body));
      res.expiresIn =
          DateTime.now().millisecondsSinceEpoch + (res.expiresIn * 1000);
      saveData<ResponseToken?>(PrefName.malToken, res);
      token.value = res.accessToken;
      _loadingToken.value = false;
      return res;
    } else {
      debugPrint("MAL refreshToken failed: ${response.statusCode} - ${response.body}");
      _loadingToken.value = false;
      throw Exception('Failed to refresh token: ${response.statusCode}');
    }
  }

  final rateLimiter = RateLimiter();

  Future<T?> executeQuery<T>(
    String url, {
    Map<String, String>? headers,
    bool withNoHeaders = false,
    bool force = false,
    bool useToken = true,
    bool show = true,
  }) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await getToken();

        if (adult) {
          String op = Uri.dataFromString(url).queryParameters.isEmpty ? "?" : "&";
          url = "$url${op}nsfw=${adult ? '1' : '0'}";
        }

        final isAuthorizedEndpoint = url.contains("@me");
        if (isAuthorizedEndpoint && token.value.isEmpty) {
          // User is not logged into MAL; authorized endpoints cannot succeed
          return null;
        }

        final reqHeaders = <String, String>{};
        if (headers != null) reqHeaders.addAll(headers);

        if (!withNoHeaders) {
          reqHeaders["X-MAL-Client-ID"] = MalStrings.clientId;
          reqHeaders["Accept"] = "application/json";
          if (token.value.isNotEmpty) {
            reqHeaders["Authorization"] = "Bearer ${token.value}";
          }
        }

        final response = await rateLimiter.run(() => http.get(
              Uri.parse(url),
              headers: reqHeaders,
            ));

        debugPrint("Remaining Mal requests: ${rateLimiter.remainingRequests}");

        // If 429 Too Many Requests: set queue cooldown and retry
        if (response.statusCode == 429) {
          final retryHeader = response.headers['retry-after'] ?? response.headers['Retry-After'];
          final waitSec = int.tryParse(retryHeader ?? '') ?? (attempt * 2 + 1);
          debugPrint("MAL query returned 429. Setting cooldown for ${waitSec}s (attempt $attempt/3)...");
          rateLimiter.setCooldown(Duration(seconds: waitSec));
          _showThrottledMalToast("MAL rate limit reached. Waiting ${waitSec}s...");
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: waitSec));
            continue;
          } else {
            return null;
          }
        }

        // If token expired / unauthorized (401), attempt to refresh token once and retry
        if (response.statusCode == 401 && token.value.isNotEmpty) {
          debugPrint("MAL query returned 401 for $url. Attempting token refresh...");
          try {
            final refreshed = await refreshToken();
            if (refreshed != null) {
              reqHeaders["Authorization"] = "Bearer ${refreshed.accessToken}";
              final retryRes = await rateLimiter.run(() => http.get(
                    Uri.parse(url),
                    headers: reqHeaders,
                  ));
              if (retryRes.statusCode >= 200 && retryRes.statusCode < 300) {
                final jsonResponse = json.decode(retryRes.body);
                if (jsonResponse == null) return null;
                return TypeFactory.get<T>(jsonResponse);
              }
            }
          } catch (e) {
            debugPrint("Failed to refresh MAL token on 401: $e");
          }
        }

        if (response.statusCode >= 400) {
          debugPrint("MAL query returned status ${response.statusCode}: ${response.body}");
          return null;
        }

        final jsonResponse = json.decode(response.body);
        if (jsonResponse == null) return null;

        return TypeFactory.get<T>(jsonResponse);
      } catch (e) {
        debugPrint("MAL executeQuery error for $url: $e");
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Future<http.Response?> executeMutation(
    String url, {
    String method = 'PUT',
    Map<String, String>? body,
  }) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await getToken();
        if (token.value.isEmpty) {
          debugPrint("Cannot execute MAL mutation: User is not logged into MAL");
          return null;
        }

        final reqHeaders = <String, String>{
          "X-MAL-Client-ID": MalStrings.clientId,
          "Authorization": "Bearer ${token.value}",
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
        };

        final uri = Uri.parse(url);

        final response = await rateLimiter.run(() async {
          if (method.toUpperCase() == 'DELETE') {
            return await http.delete(uri, headers: reqHeaders);
          } else if (method.toUpperCase() == 'PATCH') {
            return await http.patch(uri, headers: reqHeaders, body: body);
          } else {
            return await http.put(uri, headers: reqHeaders, body: body);
          }
        });

        if (response.statusCode == 429) {
          final retryHeader = response.headers['retry-after'] ?? response.headers['Retry-After'];
          final waitSec = int.tryParse(retryHeader ?? '') ?? (attempt * 2 + 1);
          debugPrint("MAL mutation returned 429. Setting cooldown for ${waitSec}s (attempt $attempt/3)...");
          rateLimiter.setCooldown(Duration(seconds: waitSec));
          _showThrottledMalToast("MAL rate limit reached. Waiting ${waitSec}s...");
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: waitSec));
            continue;
          }
          return response;
        }

        if (response.statusCode == 401 && token.value.isNotEmpty) {
          debugPrint("MAL mutation returned 401 for $url. Attempting token refresh...");
          try {
            final refreshed = await refreshToken();
            if (refreshed != null) {
              reqHeaders["Authorization"] = "Bearer ${refreshed.accessToken}";
              final retryRes = await rateLimiter.run(() async {
                if (method.toUpperCase() == 'DELETE') {
                  return await http.delete(uri, headers: reqHeaders);
                } else {
                  return await http.put(uri, headers: reqHeaders, body: body);
                }
              });
              return retryRes;
            }
          } catch (e) {
            debugPrint("Failed to refresh MAL token on 401: $e");
          }
        }

        return response;
      } catch (e) {
        debugPrint("MAL executeMutation error ($method $url): $e");
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  static DateTime _lastMalToastTime = DateTime.fromMillisecondsSinceEpoch(0);

  static void _showThrottledMalToast(String message) {
    final now = DateTime.now();
    if (now.difference(_lastMalToastTime).inSeconds >= 5) {
      _lastMalToastTime = now;
      snackString(message);
    }
  }
}

class RateLimiter {
  static const int maxRequestsPerMinute = 50;
  static const int minIntervalMs = 420;

  DateTime _lastRequestEndTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _cooldownUntil;
  int _requestCount = 0;
  DateTime _resetTime = DateTime.now().add(const Duration(minutes: 1));

  // FIFO serial execution mutex lock
  Future<void> _lock = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _lock = _lock.then((_) async {
      try {
        final result = await _executeWithThrottling(action);
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      }
    }).catchError((_) {
      // Guarantee lock chain never breaks
    });

    return completer.future;
  }

  Future<T> _executeWithThrottling<T>(Future<T> Function() action) async {
    // 1. Wait for 429 cooldown if active
    if (_cooldownUntil != null) {
      final now = DateTime.now();
      if (_cooldownUntil!.isAfter(now)) {
        final waitDuration = _cooldownUntil!.difference(now) + const Duration(milliseconds: 200);
        debugPrint("RateLimiter: Cooldown active, waiting ${waitDuration.inMilliseconds}ms");
        await Future.delayed(waitDuration);
      }
      _cooldownUntil = null;
    }

    // 2. Per-minute limit check
    final now = DateTime.now();
    if (now.isAfter(_resetTime)) {
      _requestCount = 0;
      _resetTime = now.add(const Duration(minutes: 1));
    }
    if (_requestCount >= maxRequestsPerMinute) {
      final waitDuration = _resetTime.difference(now) + const Duration(milliseconds: 100);
      debugPrint("RateLimiter: Per-minute limit reached, waiting ${waitDuration.inMilliseconds}ms");
      await Future.delayed(waitDuration);
      _requestCount = 0;
      _resetTime = DateTime.now().add(const Duration(minutes: 1));
    }

    // 3. Minimum gap between end of previous request and start of current request
    final elapsedSinceLastEnd = DateTime.now().difference(_lastRequestEndTime).inMilliseconds;
    if (elapsedSinceLastEnd < minIntervalMs) {
      await Future.delayed(Duration(milliseconds: minIntervalMs - elapsedSinceLastEnd));
    }

    _requestCount++;
    try {
      return await action().timeout(const Duration(seconds: 15));
    } finally {
      _lastRequestEndTime = DateTime.now();
    }
  }

  void setCooldown(Duration duration) {
    final until = DateTime.now().add(duration);
    if (_cooldownUntil == null || until.isAfter(_cooldownUntil!)) {
      _cooldownUntil = until;
      debugPrint("RateLimiter: Cooldown set until $_cooldownUntil");
    }
  }

  /// Backward-compatible wait helper
  Future<void> waitForSlot() async {
    await run(() async {});
  }

  int get remainingRequests => (maxRequestsPerMinute - _requestCount).clamp(0, maxRequestsPerMinute);
}
