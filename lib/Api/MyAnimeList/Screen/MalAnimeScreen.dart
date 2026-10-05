import 'package:dartotsu/Api/MyAnimeList/MalQueries.dart';
import 'package:dartotsu/Theme/LanguageSwitcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../Adaptor/Media/Widgets/MediaSection.dart';
import '../../../DataClass/Media.dart';
import '../../../DataClass/MediaSection.dart';
import '../../../Functions/Function.dart';
import '../../../Preferences/PrefManager.dart';
import '../../../Screens/MediaList/MediaListDetailScreen.dart';
import '../../../Services/Screens/BaseAnimeScreen.dart';
import '../Mal.dart';

class MalAnimeScreen extends BaseAnimeScreen {
  final MalController Mal;

  MalAnimeScreen(this.Mal);

  var animePopular = Rxn<List<Media>>();
  var updated = Rxn<List<Media>>();
  var popularMovies = Rxn<List<Media>>();
  var topRatedSeries = Rxn<List<Media>>();
  var mostFavSeries = Rxn<List<Media>>();

  Future<void> getUserId() async {
    if (Mal.token.isEmpty) {
      Mal.getSavedToken();
    }
    if (Mal.token.isNotEmpty && (Mal.userid == null || Mal.userid! <= 0)) {
      await (Mal.query as MalQueries?)?.getUserData();
    }
  }

  @override
  Future<void> loadAll({bool force = false}) async {
    if (animePopular.value == null || animePopular.value!.isEmpty) {
      resetPageData();
    } else {
      page = 1;
      loadMore.value = true;
      canLoadMore.value = true;
    }
    await getUserId();
    try {
      final list = await Mal.query!.getAnimeList(force: force);
      if (list["topAiring"]?.isNotEmpty ?? false) updated.value = list["topAiring"];
      if (list["trendingMovies"]?.isNotEmpty ?? false) popularMovies.value = list["trendingMovies"];
      if (list["topRatedSeries"]?.isNotEmpty ?? false) topRatedSeries.value = list["topRatedSeries"];
      if (list["mostFavouriteSeries"]?.isNotEmpty ?? false) mostFavSeries.value = list["mostFavouriteSeries"];
      if (list["popularAnime"]?.isNotEmpty ?? false) animePopular.value = list["popularAnime"];
      if (list["trendingAnime"]?.isNotEmpty ?? false) trending.value = list["trendingAnime"];
      updated.value ??= [];
      popularMovies.value ??= [];
      topRatedSeries.value ??= [];
      mostFavSeries.value ??= [];
      animePopular.value ??= [];
      trending.value ??= [];
    } catch (e) {
      debugPrint("Error loading MAL anime list: $e");
      snackString("MyAnimeList API is down or unreachable");
      updated.value ??= [];
      popularMovies.value ??= [];
      topRatedSeries.value ??= [];
      mostFavSeries.value ??= [];
      animePopular.value ??= [];
      trending.value ??= [];
    }
  }

  @override
  int get refreshID => RefreshId.Mal.animePage;

  void resetPageData() {
    trending.value = null;
    animePopular.value = null;
    updated.value = null;
    popularMovies.value = null;
    topRatedSeries.value = null;
    mostFavSeries.value = null;
    loadMore.value = true;
    canLoadMore.value = true;
    page = 1;
  }

  @override
  Future<void>? loadNextPage() async {
    final nextPage = page + 1;
    var result = await (Mal.query as MalQueries?)?.loadNextPage('anime', nextPage);
    if (result != null) {
      if (result.isNotEmpty) {
        page = nextPage;
        canLoadMore.value = true;
        final existingIds = (animePopular.value ?? []).map((m) => m.id).toSet();
        final unique = result.where((m) => !existingIds.contains(m.id)).toList();
        if (unique.isNotEmpty) {
          animePopular.value = [...?animePopular.value, ...unique];
        } else {
          canLoadMore.value = false;
        }
      } else {
        canLoadMore.value = false;
      }
    } else {
      canLoadMore.value = true;
    }
    loadMore.value = true;
    return;
  }

  @override
  Future<void> loadTrending(int page) async {
    this.trending.value = null;
    var currentSeasonMap = Mal.currentSeasons[page];
    var season = currentSeasonMap.keys.first;
    var year = currentSeasonMap.values.first;
    var trending = await (Mal.query as MalQueries?)!
        .getTrending(year: year.toString(), season: season);
    this.trending.value = trending;
  }

  @override
  List<Widget> mediaContent(BuildContext context) {
    final mediaSections = [
      MediaSectionData(
        type: 0,
        title: getString.topAiring,
        pairTitle: 'Top Airing',
        list: updated.value,
      ),
      MediaSectionData(
        type: 0,
        title: getString.trending(getString.movie(2)),
        pairTitle: 'Trending Movies',
        list: popularMovies.value,
      ),
      MediaSectionData(
        type: 0,
        title: getString.topRated(getString.series),
        pairTitle: 'Top Rated Series',
        list: topRatedSeries.value,
      ),
      MediaSectionData(
        type: 0,
        title: getString.mostFavourite(getString.series),
        pairTitle: 'Most Favourite Series',
        list: mostFavSeries.value,
      ),
    ];
    final animeLayoutMap = loadData(PrefName.malAnimeLayout);
    final sectionMap = {
      for (var section in mediaSections) section.pairTitle: section
    };
    Future<List<Media>?> Function(int page)? getFetchMore(String pairTitle) {
      final malQuery = Mal.query as MalQueries?;
      if (malQuery == null) return null;
      switch (pairTitle) {
        case 'Top Airing':
          return (page) => malQuery.loadRankingPage('anime', 'airing', page);
        case 'Trending Movies':
          return (page) => malQuery.loadRankingPage('anime', 'movie', page);
        case 'Top Rated Series':
          return (page) => malQuery.loadRankingPage('anime', 'tv', page);
        case 'Most Favourite Series':
          return (page) => malQuery.loadRankingPage('anime', 'favorite', page);
        default:
          return null;
      }
    }

    return animeLayoutMap.entries
        .where((entry) => entry.value)
        .map((entry) => sectionMap[entry.key])
        .whereType<MediaSectionData>()
        .map(
          (section) => MediaSection(
            context: context,
            type: section.type,
            title: section.title,
            mediaList: section.list,
            scrollController: section.scrollController,
            onTrailingIconTap: () {
              if (section.list?.isNotEmpty ?? false) {
                navigateToPage(
                  context,
                  MediaListDetailScreen(
                    title: section.title,
                    mediaList: section.list!,
                    fetchMore: getFetchMore(section.pairTitle),
                  ),
                );
              }
            },
          ),
        )
        .toList()
      ..add(
        MediaSection(
          context: context,
          type: 2,
          title: getString.popular(getString.anime),
          mediaList: animePopular.value,
          onTrailingIconTap: () {
            if (animePopular.value?.isNotEmpty ?? false) {
              navigateToPage(
                context,
                MediaListDetailScreen(
                  title: getString.popular(getString.anime),
                  mediaList: animePopular.value!,
                  fetchMore: (page) async =>
                      await (Mal.query as MalQueries?)?.loadRankingPage('anime', 'bypopularity', page),
                ),
              );
            }
          },
        ),
      );
  }
}
