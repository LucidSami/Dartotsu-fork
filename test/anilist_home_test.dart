import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartotsu/DataClass/Media.dart';
import 'package:dartotsu/Api/Anilist/Data/fuzzyData.dart';

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
}
