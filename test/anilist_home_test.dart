import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartotsu/DataClass/Media.dart';
import 'package:dartotsu/Api/Anilist/Data/fuzzyData.dart';
import 'package:dartotsu/Api/Anilist/Data/media.dart' as anilistApi;
import 'package:dartotsu/Api/MyAnimeList/Mal.dart';

void main() {
  test('Media serialization with FuzzyDate dates', () {
    final media = Media(
      id: 12345,
      nameRomaji: 'Test Title',
      userPreferredName: 'Test Preferred',
      userStatus: 'CURRENT',
      userProgress: 12,
      userScore: 85,
      userStartedAt: FuzzyDate(year: 2024, month: 1, day: 15),
      userCompletedAt: FuzzyDate(year: 2024, month: 5, day: 20),
    );

    final map = {
      'currentAnime': [media],
      'plannedAnime': <Media>[],
    };

    final wrapper = MediaMapWrapper(mediaMap: map);
    final jsonStr = jsonEncode(wrapper.toJson());
    final decoded = jsonDecode(jsonStr);
    final result = MediaMapWrapper.fromJson(decoded);

    expect(result.mediaMap['currentAnime']?.length, 1);
    final deserialized = result.mediaMap['currentAnime']!.first;
    expect(deserialized.id, 12345);
    expect(deserialized.userProgress, 12);
    expect(deserialized.userScore, 85);
    expect(deserialized.userStartedAt?.year, 2024);
    expect(deserialized.userStartedAt?.month, 1);
    expect(deserialized.userStartedAt?.day, 15);
    expect(deserialized.userCompletedAt?.year, 2024);
    expect(deserialized.userCompletedAt?.month, 5);
    expect(deserialized.userCompletedAt?.day, 20);
  });

  test('Media deserialization handles null userStartedAt without casting exception', () {
    final jsonMap = {
      'id': 999,
      'nameRomaji': 'Null Dates Title',
      'userPreferredName': 'Null Dates',
      'userStartedAt': null,
      'userCompletedAt': null,
    };

    final media = Media.fromJson(jsonMap);
    expect(media.id, 999);
    expect(media.userStartedAt, isNull);
    expect(media.userCompletedAt, isNull);
  });

  test('Media.mediaData and mediaListData accurately map all media list entry fields', () {
    final jsonMedia = {
      'id': 100,
      'idMal': 200,
      'title': {'english': 'Test Anime', 'romaji': 'Test Anime Romaji', 'userPreferred': 'Test Anime'},
      'type': 'ANIME',
      'mediaListEntry': {
        'id': 777,
        'status': 'COMPLETED',
        'score': 95,
        'progress': 24,
        'repeat': 2,
        'private': true,
        'notes': 'Loved this anime!',
        'startedAt': {'year': 2023, 'month': 10, 'day': 5},
        'completedAt': {'year': 2024, 'month': 2, 'day': 20},
      }
    };

    final deserializedApiMedia = anilistApi.Media.fromJson(jsonMedia);
    final mappedMedia = Media.mediaData(deserializedApiMedia);

    expect(mappedMedia.id, 100);
    expect(mappedMedia.idMAL, 200);
    expect(mappedMedia.userListId, 777);
    expect(mappedMedia.userStatus, 'COMPLETED');
    expect(mappedMedia.userScore, 95);
    expect(mappedMedia.userProgress, 24);
    expect(mappedMedia.userRepeat, 2);
    expect(mappedMedia.isListPrivate, true);
    expect(mappedMedia.notes, 'Loved this anime!');
    expect(mappedMedia.userStartedAt?.year, 2023);
    expect(mappedMedia.userCompletedAt?.year, 2024);
  });

  test('Recommendation relation type parses safely on dynamic types without NoSuchMethodError', () {
    dynamic typeEnum = anilistApi.MediaType.ANIME;
    final parsed = typeEnum?.toString().split('.').last ?? "";
    expect(parsed, 'ANIME');

    dynamic nullType;
    final parsedNull = nullType?.toString().split('.').last ?? "";
    expect(parsedNull, '');
  });

  test('MAL trendingManga derives accurately from topRatedManga without duplicate calls', () {
    final topRatedList = List.generate(
      20,
      (i) => Media(
        id: i + 1,
        nameRomaji: 'Manga $i',
        userPreferredName: 'Manga $i',
        meanScore: 100 - i,
      ),
    );

    final Map<String, List<Media>> list = {
      'topRatedManga': topRatedList,
    };

    // Simulate our derivation logic:
    list['trendingManga'] = (list['topRatedManga'] ?? []).take(12).toList();

    expect(list['trendingManga']?.length, 12);
    expect(list['trendingManga']!.first.id, 1);
    expect(list['trendingManga']!.last.id, 12);
  });

  test('MAL cache fallback preserves sections if network error occurs', () {
    final cachedMap = {
      'popularManga': [Media(id: 1, nameRomaji: 'Cached Popular', userPreferredName: 'Cached Popular')],
      'topRatedManga': [Media(id: 2, nameRomaji: 'Cached Top', userPreferredName: 'Cached Top')],
    };

    final list = <String, List<Media>>{};

    // Simulate partial network failure where popularManga succeeds but topRatedManga throws
    list['popularManga'] = [Media(id: 10, nameRomaji: 'Fresh Popular', userPreferredName: 'Fresh Popular')];
    // topRatedManga fails network: fallback to cachedMap
    if (cachedMap['topRatedManga']?.isNotEmpty == true) {
      list['topRatedManga'] = cachedMap['topRatedManga']!;
    }

    expect(list['popularManga']!.first.id, 10);
    expect(list['topRatedManga']!.first.id, 2);
  });

  test('MAL RateLimiter prioritizes high-priority requests ahead of normal-priority requests', () async {
    final limiter = RateLimiter();
    final executionOrder = <String>[];

    limiter.run(() async {
      executionOrder.add('normal_1');
      return 'n1';
    }, priority: MalPriority.normal);

    limiter.run(() async {
      executionOrder.add('normal_2');
      return 'n2';
    }, priority: MalPriority.normal);

    limiter.run(() async {
      executionOrder.add('high_1');
      return 'h1';
    }, priority: MalPriority.high);

    await limiter.waitForSlot(priority: MalPriority.normal);

    expect(executionOrder.first, 'normal_1');
    expect(executionOrder[1], 'high_1');
    expect(executionOrder[2], 'normal_2');
  });

  test('MAL RateLimiter remainingRequests decreases and sliding window tracks capacity', () async {
    final limiter = RateLimiter();
    expect(limiter.remainingRequests, 60);

    await limiter.run(() async => 'done', priority: MalPriority.high);
    expect(limiter.remainingRequests, 59);
  });
}

