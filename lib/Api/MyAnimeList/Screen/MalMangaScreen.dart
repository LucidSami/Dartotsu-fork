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
    if (Mal.token.isNotEmpty) {
      await (Mal.query as MalQueries?)?.getUserData();
    }
  }

  @override
  Future<void> loadAll({bool force = false}) async {
    resetPageData();
    await getUserId();
    try {
      final list = await Mal.query!.getMangaList(force: force);
      trending.value = list["trendingManga"] ?? [];
      mangaPopular.value = list["popularManga"] ?? [];
      popularManhwa.value = list["trendingManhwa"] ?? [];
      popularNovel.value = list["trendingNovels"] ?? [];
      topRatedManga.value = list["topRatedManga"] ?? [];
      mostFavManga.value = list["mostFavouriteManga"] ?? [];
    } catch (e) {
      debugPrint("Error loading MAL manga list: $e");
      snackString("MyAnimeList API is down or unreachable");
      trending.value = [];
      mangaPopular.value = [];
      popularManhwa.value = [];
      popularNovel.value = [];
      topRatedManga.value = [];
      mostFavManga.value = [];
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
    var result = await (Mal.query as MalQueries?)?.loadNextPage('manga', page);
    page++;
    if (result != null) {
      canLoadMore.value = true;
      mangaPopular.value = [...?mangaPopular.value, ...result];
    } else {
      canLoadMore.value = false;
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
    Future<List<Media>> Function(int page)? getFetchMore(String pairTitle) {
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
                  fetchMore: (page) async {
                    final res = await (Mal.query as MalQueries?)
                        ?.loadRankingPage('manga', 'bypopularity', page);
                    return res ?? [];
                  },
                ),
              );
            }
          },
        ),
      );
  }
}
