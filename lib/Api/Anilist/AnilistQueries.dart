import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dartotsu/Api/Anilist/Anilist.dart';
import 'package:dartotsu/Api/Anilist/Data/fuzzyData.dart';
import 'package:dartotsu/Functions/Function.dart';
import 'package:flutter/foundation.dart';

import '../../DataClass/Anime.dart';
import '../../DataClass/Author.dart';
import '../../DataClass/Character.dart';
import '../../DataClass/Media.dart';
import '../../DataClass/SearchResults.dart';
import '../../DataClass/Studio.dart';
import '../../DataClass/User.dart';
import '../../Preferences/PrefManager.dart';
import '../../Services/Api/Queries.dart';
import '../../Services/ApiCacheManager.dart';
import '../../Services/TrackSyncManager.dart';
import 'Data/data.dart';
import 'Data/media.dart' as api;
import 'Data/others.dart';
import 'Data/page.dart';
import 'Data/recommendations.dart';
import 'Data/staff.dart';
import 'Data/user.dart';

part 'AnilistQueries/GetAnimeMangaListData.dart';

part 'AnilistQueries/GetBannerImages.dart';

part 'AnilistQueries/GetCalendarData.dart';

part 'AnilistQueries/GetGenresAndTags.dart';

part 'AnilistQueries/GetHomePageData.dart';

part 'AnilistQueries/GetMediaData.dart';

part 'AnilistQueries/GetMediaDetails.dart';

part 'AnilistQueries/GetUserData.dart';

part 'AnilistQueries/GetUserMediaList.dart';

part 'AnilistQueries/Search.dart';

part 'AnilistQueries/GetStudioDetails.dart';

part 'AnilistQueries/GetReviews.dart';

class AnilistQueries extends Queries {
  // main function in the [Anilist.dart]
  final Future<T?> Function<T>(
    String query, {
    String variables,
    bool force,
    bool useToken,
    bool show,
  }) executeQuery;

  AnilistQueries(this.executeQuery);

  @override
  Future<bool> getUserData() => _getUserData();

  @override
  Future<Media?> getMedia(int id, {bool mal = false}) => _getMedia(id, mal: mal);

  @override
  Future<Media?> mediaDetails(Media media, {bool force = false}) =>
      _mediaDetails(media, force: force);

  @override
  Future<Map<String, List<Media>>> initHomePage({bool force = false}) =>
      _initHomePage(force: force);

  @override
  Future<bool> getGenresAndTags() => _getGenresAndTags();

  @override
  Future<Map<String, List<Media>>> getMediaLists({
    required bool anime,
    required int userId,
    String? sortOrder,
    bool force = false,
  }) =>
      _getMediaLists(
        anime: anime,
        userId: userId,
        sortOrder: sortOrder,
        force: force,
      );

  @override
  Future<List<String?>> getBannerImages() => _getBannerImages();

  @override
  Future<Map<String, List<Media>>> getAnimeList({bool force = false}) =>
      _getAnimeList(force: force);

  @override
  Future<Map<String, List<Media>>> getMangaList({bool force = false}) =>
      _getMangaList(force: force);

  @override
  Future<List<Media>> getCalendarData() => _getCalendarData();

  @override
  Future<SearchResults?> search(SearchResults? searchResults) =>
      _search(searchResults);

  Future<studio?> getStudioDetails(int studioId, {String? studioName}) =>
      _getStudioDetails(studioId, studioName: studioName);

  Future<({List<Review> reviews, bool hasNextPage})> getReviews(
    int mediaId, {
    int page = 1,
    int perPage = 20,
    String sort = "SCORE_DESC",
  }) =>
      _getReviews(mediaId, page: page, perPage: perPage, sort: sort);

  Future<List<Media>> getRecentUpdates(int page) => _getRecentUpdates(page);

  Future<List<Media>?> getFavouritesPage({required bool anime, required int page, int? id}) =>
      _getFavouritesPage(anime: anime, page: page, id: id);

  Future<List<Media>?> getUserMediaListPaged({
    required bool anime,
    required String status,
    required int page,
    int perPage = 50,
  }) =>
      _getUserMediaListPaged(
        anime: anime,
        status: status,
        page: page,
        perPage: perPage,
      );
}
