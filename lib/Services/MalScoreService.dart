import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../Api/MyAnimeList/Mal.dart';
import '../DataClass/Media.dart';
import '../Preferences/PrefManager.dart';

class MalScoreService {
  static final MalScoreService _instance = MalScoreService._internal();
  factory MalScoreService() => _instance;
  MalScoreService._internal();

  static const String _clientId = '8f052af44fca8761bcb7edf79d7e75b7';
  static const double scoreNotFound = -1.0;

  // Shared pooled HTTP client with Keep-Alive connection reuse
  static final http.Client _client = http.Client();

  // MAL Score Cache & State
  final Map<int, double> _scoreCache = {};
  final Map<int, Completer<double?>> _pendingMalCompleters = {};
  final Map<int, ValueNotifier<double?>> _scoreNotifiers = {};
  final List<Future<void> Function()> _malTaskQueue = [];
  int _activeMalWorkers = 0;
  static const int _maxMalWorkers = 2;
  DateTime? _malCooldownUntil;

  // AniList Score Cache & State
  final Map<int, double> _anilistScoreCache = {};
  final Map<int, Completer<double?>> _pendingAnilistCompleters = {};
  final Map<int, ValueNotifier<double?>> _anilistScoreNotifiers = {};
  final Set<int> _anilistBatchSet = {};
  Timer? _anilistBatchTimer;
  bool _isFlushingAnilistBatch = false;

  ValueNotifier<double?> getScoreNotifier(int malId, {double? initialScore}) {
    if (!_scoreNotifiers.containsKey(malId)) {
      final diskScore = _scoreCache[malId] ?? loadCustomData<double>('mal_score_$malId');
      if (diskScore != null) _scoreCache[malId] = diskScore;
      _scoreNotifiers[malId] = ValueNotifier<double?>(initialScore ?? diskScore);
    }
    if (initialScore != null && initialScore > 0 && (_scoreCache[malId] == null || _scoreCache[malId]! <= 0)) {
      _scoreCache[malId] = initialScore;
      saveCustomData('mal_score_$malId', initialScore);
      _scoreNotifiers[malId]!.value = initialScore;
    }
    return _scoreNotifiers[malId]!;
  }

  ValueNotifier<double?> getAnilistScoreNotifier(int malId, {double? initialScore}) {
    if (!_anilistScoreNotifiers.containsKey(malId)) {
      final diskScore = _anilistScoreCache[malId] ?? loadCustomData<double>('anilist_score_$malId');
      if (diskScore != null) _anilistScoreCache[malId] = diskScore;
      _anilistScoreNotifiers[malId] = ValueNotifier<double?>(initialScore ?? diskScore);
    }
    if (initialScore != null && initialScore > 0 && (_anilistScoreCache[malId] == null || _anilistScoreCache[malId]! <= 0)) {
      _anilistScoreCache[malId] = initialScore;
      saveCustomData('anilist_score_$malId', initialScore);
      _anilistScoreNotifiers[malId]!.value = initialScore;
    }
    return _anilistScoreNotifiers[malId]!;
  }

  /// Prepopulates scores from local persistent disk cache only.
  /// Never makes network requests.
  void prefetch(List<Media>? list) {
    if (list == null || list.isEmpty) return;
    for (final media in list) {
      final malId = media.idMAL ?? (media.mal ? media.id : null);
      if (malId != null && malId > 0) {
        if (media.mal) {
          if (!_anilistScoreCache.containsKey(malId)) {
            final disk = loadCustomData<double>('anilist_score_$malId');
            if (disk != null) {
              _anilistScoreCache[malId] = disk;
              _anilistScoreNotifiers[malId]?.value = disk;
            }
          }
        } else {
          if (media.malScore == null && !_scoreCache.containsKey(malId)) {
            final disk = loadCustomData<double>('mal_score_$malId');
            if (disk != null) {
              _scoreCache[malId] = disk;
              _scoreNotifiers[malId]?.value = disk;
            }
          }
        }
      }
    }
  }

  /// Fetches MAL score for a given MAL ID with 2-worker concurrency, 350ms spacing,
  /// and persistent negative caching for unrated/missing items.
  Future<double?> fetchMalScore(int malId, {bool isAnime = true}) async {
    // 1. Check in-memory cache
    if (_scoreCache.containsKey(malId)) {
      final val = _scoreCache[malId]!;
      return (val > 0) ? val : null;
    }

    // 2. Check persistent disk cache
    final diskScore = loadCustomData<double>('mal_score_$malId');
    if (diskScore != null) {
      _scoreCache[malId] = diskScore;
      _scoreNotifiers[malId]?.value = diskScore;
      return (diskScore > 0) ? diskScore : null;
    }

    // 3. De-duplicate inflight request
    if (_pendingMalCompleters.containsKey(malId)) {
      return _pendingMalCompleters[malId]!.future;
    }

    final completer = Completer<double?>();
    _pendingMalCompleters[malId] = completer;

    _malTaskQueue.add(() => _fetchMalTask(malId, isAnime, completer));
    _startMalWorkers();

    return completer.future;
  }

  void _startMalWorkers() {
    while (_activeMalWorkers < _maxMalWorkers && _malTaskQueue.isNotEmpty) {
      _activeMalWorkers++;
      _runMalWorker();
    }
  }

  Future<void> _runMalWorker() async {
    while (_malTaskQueue.isNotEmpty) {
      if (_malCooldownUntil != null) {
        final now = DateTime.now();
        if (_malCooldownUntil!.isAfter(now)) {
          await Future.delayed(_malCooldownUntil!.difference(now) + const Duration(milliseconds: 200));
        }
        _malCooldownUntil = null;
      }

      final task = _malTaskQueue.removeAt(0);
      try {
        await task();
      } catch (e) {
        debugPrint("MAL score worker task error: $e");
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }
    _activeMalWorkers--;
  }

  Future<void> _fetchMalTask(int malId, bool isAnime, Completer<double?> completer) async {
    try {
      final score = await _fetchMalInternal(malId, isAnime: isAnime);
      if (score != null && score > 0) {
        _scoreCache[malId] = score;
        saveCustomData('mal_score_$malId', score);
        _scoreNotifiers[malId]?.value = score;
        if (!completer.isCompleted) completer.complete(score);
      } else {
        _scoreCache[malId] = scoreNotFound;
        saveCustomData('mal_score_$malId', scoreNotFound);
        _scoreNotifiers[malId]?.value = scoreNotFound;
        if (!completer.isCompleted) completer.complete(null);
      }
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    } finally {
      _pendingMalCompleters.remove(malId);
    }
  }

  Future<double?> _fetchMalInternal(int malId, {required bool isAnime}) async {
    final type = isAnime ? 'anime' : 'manga';
    final token = Mal.token.value;
    final headers = {
      'Accept': 'application/json',
      if (token.isNotEmpty)
        'Authorization': 'Bearer $token'
      else
        'X-MAL-CLIENT-ID': _clientId,
    };
    final url = Uri.parse('https://api.myanimelist.net/v2/$type/$malId?fields=mean');

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final res = await _client.get(url, headers: headers).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data != null && data['mean'] != null) {
            return (data['mean'] as num).toDouble();
          }
          return scoreNotFound;
        } else if (res.statusCode == 404) {
          return scoreNotFound;
        } else if (res.statusCode == 429) {
          final retryHeader = res.headers['retry-after'] ?? res.headers['Retry-After'];
          final waitSec = int.tryParse(retryHeader ?? '') ?? (attempt * 3);
          _malCooldownUntil = DateTime.now().add(Duration(seconds: waitSec));
          debugPrint("MAL score 429 encountered, cooling down for ${waitSec}s...");
          await Future.delayed(Duration(seconds: waitSec) + const Duration(milliseconds: 200));
          continue;
        } else {
          return null;
        }
      } catch (e) {
        if (attempt == 2) return null;
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return null;
  }

  /// Fetches AniList score for a given MAL ID using high-speed GraphQL batching.
  /// Collects up to 50 IDs and resolves them in a single network request.
  Future<double?> fetchAnilistScore(int malId) async {
    // 1. Check in-memory cache
    if (_anilistScoreCache.containsKey(malId)) {
      final val = _anilistScoreCache[malId]!;
      return (val > 0) ? val : null;
    }

    // 2. Check persistent disk cache
    final diskScore = loadCustomData<double>('anilist_score_$malId');
    if (diskScore != null) {
      _anilistScoreCache[malId] = diskScore;
      _anilistScoreNotifiers[malId]?.value = diskScore;
      return (diskScore > 0) ? diskScore : null;
    }

    // 3. De-duplicate inflight request
    if (_pendingAnilistCompleters.containsKey(malId)) {
      return _pendingAnilistCompleters[malId]!.future;
    }

    final completer = Completer<double?>();
    _pendingAnilistCompleters[malId] = completer;

    _anilistBatchSet.add(malId);
    _scheduleAnilistBatch();

    return completer.future;
  }

  void _scheduleAnilistBatch() {
    if (_anilistBatchSet.length >= 50) {
      _anilistBatchTimer?.cancel();
      _flushAnilistBatch();
    } else if (_anilistBatchTimer == null || !_anilistBatchTimer!.isActive) {
      _anilistBatchTimer = Timer(const Duration(milliseconds: 50), () {
        _flushAnilistBatch();
      });
    }
  }

  Future<void> _flushAnilistBatch() async {
    if (_isFlushingAnilistBatch || _anilistBatchSet.isEmpty) return;
    _isFlushingAnilistBatch = true;

    final batch = _anilistBatchSet.take(50).toList();
    for (final id in batch) {
      _anilistBatchSet.remove(id);
    }

    try {
      const query = '''
        query (\$ids: [Int]) {
          Page(page: 1, perPage: 50) {
            media(idMal_in: \$ids) {
              idMal
              meanScore
              averageScore
            }
          }
        }
      ''';
      final url = Uri.parse('https://graphql.anilist.co/');
      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };
      final body = jsonEncode({
        'query': query,
        'variables': {'ids': batch},
      });

      final res = await _client.post(url, headers: headers, body: body).timeout(const Duration(seconds: 8));

      final foundIds = <int>{};
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final mediaList = data?['data']?['Page']?['media'] as List<dynamic>?;
        if (mediaList != null) {
          for (final item in mediaList) {
            final idMal = item['idMal'] as int?;
            if (idMal != null) {
              foundIds.add(idMal);
              final raw = (item['meanScore'] ?? item['averageScore']) as num?;
              final score = (raw != null && raw > 0) ? (raw.toDouble() / 10.0) : scoreNotFound;
              _anilistScoreCache[idMal] = score;
              saveCustomData('anilist_score_$idMal', score);
              _anilistScoreNotifiers[idMal]?.value = score;
              final completer = _pendingAnilistCompleters.remove(idMal);
              if (completer != null && !completer.isCompleted) {
                completer.complete((score > 0) ? score : null);
              }
            }
          }
        }
      } else if (res.statusCode == 429) {
        debugPrint("AniList batch 429 hit, retrying batch after 3s cooldown...");
        _anilistBatchSet.addAll(batch);
        await Future.delayed(const Duration(seconds: 3));
        _isFlushingAnilistBatch = false;
        _scheduleAnilistBatch();
        return;
      }

      // Any ID not in the GraphQL response has no score on AniList
      for (final id in batch) {
        if (!foundIds.contains(id)) {
          _anilistScoreCache[id] = scoreNotFound;
          saveCustomData('anilist_score_$id', scoreNotFound);
          _anilistScoreNotifiers[id]?.value = scoreNotFound;
          final completer = _pendingAnilistCompleters.remove(id);
          if (completer != null && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }
    } catch (e) {
      debugPrint("AniList batch query exception: $e");
      for (final id in batch) {
        final completer = _pendingAnilistCompleters.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    } finally {
      _isFlushingAnilistBatch = false;
      if (_anilistBatchSet.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 200), () => _scheduleAnilistBatch());
      }
    }
  }

  void clearCache() {
    _scoreCache.clear();
    _scoreNotifiers.clear();
    _anilistScoreCache.clear();
    _anilistScoreNotifiers.clear();
  }
}
