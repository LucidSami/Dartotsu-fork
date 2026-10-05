import 'package:dartotsu/Theme/LanguageSwitcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

import '../../../Adaptor/Media/Widgets/MediaSection.dart';
import '../../../DataClass/Media.dart';
import '../../../DataClass/MediaSection.dart';
import '../../../Functions/Function.dart';
import '../../../Preferences/PrefManager.dart';
import '../../../Screens/MediaList/MediaListDetailScreen.dart';
import '../../../Services/Screens/BaseMangaScreen.dart';
import '../Mal.dart';
import '../MalQueries.dart';

class MalMangaScreen extends BaseMangaScreen {
  final MalController Mal;

  MalMangaScreen(this.Mal);

  var mangaPopular = Rxn<List<Media>>();
  var popularManhwa = Rxn<List<Media>>();
  var popularNovel = Rxn<List<Media>>();
  var topRatedManga = Rxn<List<Media>>();
  var mostFavManga = Rxn<List<Media>>();

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
    if (mangaPopular.value == null || mangaPopular.value!.isEmpty) {
      resetPageData();
    } else {
      page = 1;
      loadMore.value = true;
      canLoadMore.value = true;
    }
    await getUserId();
    try {
      final list = await Mal.query!.getMangaList(force: force);
      if (list["trendingManga"]?.isNotEmpty ?? false) trending.value = list["trendingManga"];
      if (list["popularManga"]?.isNotEmpty ?? false) mangaPopular.value = list["popularManga"];
      if (list["trendingManhwa"]?.isNotEmpty ?? false) popularManhwa.value = list["trendingManhwa"];
      if (list["trendingNovels"]?.isNotEmpty ?? false) popularNovel.value = list["trendingNovels"];
      if (list["topRatedManga"]?.isNotEmpty ?? false) topRatedManga.value = list["topRatedManga"];
      if (list["mostFavouriteManga"]?.isNotEmpty ?? false) mostFavManga.value = list["mostFavouriteManga"];
      trending.value ??= [];
      mangaPopular.value ??= [];
      popularManhwa.value ??= [];
      popularNovel.value ??= [];
      topRatedManga.value ??= [];
      mostFavManga.value ??= [];
    } catch (e) {
      debugPrint("Error loading MAL manga list: $e");
      snackString("MyAnimeList API is down or unreachable");
      trending.value ??= [];
      mangaPopular.value ??= [];
      popularManhwa.value ??= [];
      popularNovel.value ??= [];
      topRatedManga.value ??= [];
      mostFavManga.value ??= [];
    }
  }

  @override
  int get refreshID => RefreshId.Mal.mangaPage;

  void resetPageData() {
    trending.value = null;
    mangaPopular.value = null;
    popularManhwa.value = null;
    popularNovel.value = null;
    topRatedManga.value = null;
    mostFavManga.value = null;
    loadMore.value = true;
    canLoadMore.value = true;
    page = 1;
  }

  @override
  Future<void>? loadNextPage() async {
    final nextPage = page + 1;
    var result = await (Mal.query as MalQueries?)?.loadNextPage('manga', nextPage);
    if (result != null) {
      if (result.isNotEmpty) {
        page = nextPage;
        canLoadMore.value = true;
        final existingIds = (mangaPopular.value ?? []).map((m) => m.id).toSet();
        final unique = result.where((m) => !existingIds.contains(m.id)).toList();
        if (unique.isNotEmpty) {
          mangaPopular.value = [...?mangaPopular.value, ...unique];
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
  void loadTrending(String type) async {
    this.trending.value = null;
    if (type == "NOVEL") type = "NOVELS";
    var trending = await (Mal.query as MalQueries?)!
        .getTrending(season: type.toLowerCase());
    this.trending.value = trending;
  }

  @override
  List<Widget> mediaContent(BuildContext context) {
    final mediaSections = [
      MediaSectionData(
        type: 0,
        title: getString.trending(getString.manhwa),
        pairTitle: 'Trending Manhwa',
        list: popularManhwa.value,
      ),
      MediaSectionData(
        type: 0,
        title: getString.trending(getString.novel),
        pairTitle: 'Trending Novels',
        list: popularNovel.value,
      ),
      MediaSectionData(
        type: 0,
        title: getString.topRated(getString.manga),
        pairTitle: 'Top Rated Manga',
        list: topRatedManga.value,
      ),
      MediaSectionData(
        type: 0,
        title: getString.mostFavourite(getString.manga),
        pairTitle: 'Most Favourite Manga',
        list: mostFavManga.value,
      ),
    ];
    final mangaLayoutMap = loadData(PrefName.malMangaLayout);
    final sectionMap = {
      for (var section in mediaSections) section.pairTitle: section
    };
    Future<List<Media>?> Function(int page)? getFetchMore(String pairTitle) {
      final malQuery = Mal.query as MalQueries?;
      if (malQuery == null) return null;
      switch (pairTitle) {
        case 'Trending Manhwa':
          return (page) => malQuery.loadRankingPage('manga', 'manhwa', page);
        case 'Trending Novels':
          return (page) => malQuery.loadRankingPage('manga', 'novels', page);
        case 'Top Rated Manga':
          return (page) => malQuery.loadRankingPage('manga', 'manga', page);
        case 'Most Favourite Manga':
          return (page) => malQuery.loadRankingPage('manga', 'favorite', page);
        default:
          return null;
      }
    }

    return mangaLayoutMap.entries
        .where((entry) => entry.value)
        .map((entry) => sectionMap[entry.key])
        .whereType<MediaSectionData>()
        .map((section) => MediaSection(
              context: context,
              type: section.type,
              title: section.title,
              mediaList: section.list,
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
            ))
        .toList()
      ..add(
        MediaSection(
          context: context,
          type: 2,
          title: getString.popular(getString.manga),
          mediaList: mangaPopular.value,
          onTrailingIconTap: () {
            if (mangaPopular.value?.isNotEmpty ?? false) {
              navigateToPage(
                context,
                MediaListDetailScreen(
                  title: getString.popular(getString.manga),
                  mediaList: mangaPopular.value!,
                  fetchMore: (page) async =>
                      await (Mal.query as MalQueries?)?.loadRankingPage('manga', 'bypopularity', page),
                ),
              );
            }
          },
        ),
      );
  }
}
