import 'package:collection/collection.dart';
import 'package:dartotsu/DataClass/Media.dart';
import 'package:dartotsu/DataClass/SearchResults.dart';
import 'package:flutter/foundation.dart';

import '../../Preferences/PrefManager.dart';
import '../../Services/Api/Queries.dart';
import '../../Services/ApiCacheManager.dart';
import '../../Services/TrackSyncManager.dart';
import '../../logger.dart';
import 'Data/data.dart';
import 'Data/media.dart' as malApi;
import 'Data/user.dart';
import 'Mal.dart';
import 'MalQueries/MalStrings.dart';

part 'MalQueries/GetAnimeMangaListData.dart';

part 'MalQueries/GetHomePageData.dart';

part 'MalQueries/GetUserData.dart';

part 'MalQueries/GetMediaDetails.dart';

part 'MalQueries/Search.dart';

class MalQueries extends Queries {
  Future<T?> Function<T>(
    String url, {
    Map<String, String>? headers,
    bool withNoHeaders,
    bool force,
    bool useToken,
    bool show,
  }) executeQuery;

  MalQueries(this.executeQuery);

  @override
  Future<Map<String, List<Media>>> getAnimeList({bool force = false}) =>
      _getAnimeList(force: force);

  @override
  Future<List<Media>> getCalendarData() {
    // TODO: implement getCalendarData
    throw UnimplementedError();
  }

  @override
  Future<bool>? getGenresAndTags() {
    // TODO: implement getGenresAndTags
    throw UnimplementedError();
  }

  @override
  Future<Map<String, List<Media>>> getMangaList({bool force = false}) =>
      _getMangaList(force: force);

  Future<List<Media>> getTrending({String? year, String? season}) =>
      _getTrending(year: year, season: season);

  Future<List<Media>?> loadNextPage(String type, int page) =>
      _loadNextPage(type, page);

  Future<List<Media>?> loadRankingPage(
    String type,
    String rankingType,
    int page, {
    int limit = 50,
  }) =>
      _loadRankingPage(type, rankingType, page, limit: limit);

  @override
  Future<Media?>? getMedia(int id, {bool mal = true}) {
    // TODO: implement getMedia
    throw UnimplementedError();
  }

  @override
  Future<Map<String, List<Media>>> getMediaLists(
      {required bool anime, required int userId, String? sortOrder}) {
    return _getMediaLists(anime: anime);
  }

  @override
  Future<bool>? getUserData({bool force = false}) =>
      _getUserData(force: force);

  @override
  Future<Map<String, List<Media>>>? initHomePage({bool force = false}) =>
      _initHomePage(force: force);

  @override
  Future<Media?>? mediaDetails(Media media) => _getMediaDetails(media);

  @override
  Future<SearchResults?> search(SearchResults? searchResults) =>
      _search(searchResults);
}
