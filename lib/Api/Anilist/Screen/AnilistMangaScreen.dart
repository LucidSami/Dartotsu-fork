import 'package:dartotsu/DataClass/SearchResults.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';

import '../../../Adaptor/Media/Widgets/MediaSection.dart';
import '../../../DataClass/Media.dart';
import '../../../DataClass/MediaSection.dart';
import '../../../Functions/Function.dart';
import '../../../Preferences/PrefManager.dart';
import '../../../Screens/MediaList/MediaListDetailScreen.dart';
import '../../../Services/Screens/BaseMangaScreen.dart';
import '../../../Theme/LanguageSwitcher.dart';
import '../Anilist.dart';

class AnilistMangaScreen extends BaseMangaScreen {
  final AnilistController Anilist;

  AnilistMangaScreen(this.Anilist);

  var mangaPopular = Rxn<List<Media>>();
  var popularManhwa = Rxn<List<Media>>();
  var popularNovel = Rxn<List<Media>>();
  var topRatedManga = Rxn<List<Media>>();
  var mostFavManga = Rxn<List<Media>>();

  Future<void> getUserId() async {
    if (Anilist.token.isNotEmpty) {
      await Anilist.query!.getUserData();
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
    try {
      await getUserId();
      final list = await Anilist.query!.getMangaList(force: force);
      trending.value = list["trending"] ?? [];
      mangaPopular.value = list["popularManga"] ?? [];
      popularManhwa.value = list["trendingManhwa"] ?? [];
      popularNovel.value = list["trendingNovel"] ?? [];
      topRatedManga.value = list["topRated"] ?? [];
      mostFavManga.value = list["mostFav"] ?? [];
    } catch (e) {
      snackString("AniList API is down or unreachable");
      trending.value = [];
      mangaPopular.value = [];
      popularManhwa.value = [];
      popularNovel.value = [];
      topRatedManga.value = [];
      mostFavManga.value = [];
    }
  }

  @override
  int get refreshID => RefreshId.Anilist.mangaPage;

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
  Future<void> loadNextPage() async {
    try {
      final result = await Anilist.query!.search(
        SearchResults(
          type: SearchType.MANGA,
          page: page + 1,
          perPage: 50,
          sort: Anilist.sortBy[1],
          onList: loadData(PrefName.includeMangaList),
        ),
      );
      page++;
      if (result != null) {
        canLoadMore.value = result.hasNextPage ?? false;
        mangaPopular.value = [...?mangaPopular.value, ...?result.results];
      }
    } catch (_) {}
    loadMore.value = true;
  }

  @override
  Future<void> loadTrending(String type) async {
    trending.value = null;
    try {
      final country = type == 'MANHWA' ? 'KR' : 'JP';
      final format = type == 'NOVEL' ? 'NOVEL' : null;
      final trendingRes = await Anilist.query!.search(
        SearchResults(
          type: SearchType.MANGA,
          countryOfOrigin: country,
          format: format,
          perPage: 50,
          sort: Anilist.sortBy[2],
          hdCover: true,
        ),
      );
      trending.value = trendingRes?.results ?? [];
    } catch (_) {
      trending.value = [];
    }
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

    final mangaLayoutMap = loadData(PrefName.anilistMangaLayout);

    final sectionMap = {
      for (final section in mediaSections) section.pairTitle: section,
    };

    final sections = mangaLayoutMap.entries
        .where((entry) => entry.value)
        .map((entry) => sectionMap[entry.key])
        .whereType<MediaSectionData>()
        .toList();

    Future<List<Media>> Function(int page)? getFetchMore(String pairTitle) {
      switch (pairTitle) {
        case 'Trending Manhwa':
          return (page) async {
            final res = await Anilist.query!.search(
              SearchResults(
                type: SearchType.MANGA,
                countryOfOrigin: "KR",
                page: page,
                perPage: 50,
                sort: "POPULARITY_DESC",
                onList: loadData(PrefName.includeMangaList),
              ),
            );
            return res?.results ?? [];
          };
        case 'Trending Novels':
          return (page) async {
            final res = await Anilist.query!.search(
              SearchResults(
                type: SearchType.MANGA,
                countryOfOrigin: "JP",
                format: "NOVEL",
                page: page,
                perPage: 50,
                sort: "POPULARITY_DESC",
                onList: loadData(PrefName.includeMangaList),
              ),
            );
            return res?.results ?? [];
          };
        case 'Top Rated Manga':
          return (page) async {
            final res = await Anilist.query!.search(
              SearchResults(
                type: SearchType.MANGA,
                page: page,
                perPage: 50,
                sort: "SCORE_DESC",
                onList: loadData(PrefName.includeMangaList),
              ),
            );
            return res?.results ?? [];
          };
        case 'Most Favourite Manga':
          return (page) async {
            final res = await Anilist.query!.search(
              SearchResults(
                type: SearchType.MANGA,
                page: page,
                perPage: 50,
                sort: "FAVOURITES_DESC",
                onList: loadData(PrefName.includeMangaList),
              ),
            );
            return res?.results ?? [];
          };
        default:
          return null;
      }
    }

    final groupedWidgets = sections
        .map(
          (section) => MediaSection(
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
          ),
        )
        .toList();

    final popularSection = MediaSection(
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
                final res = await Anilist.query!.search(
                  SearchResults(
                    type: SearchType.MANGA,
                    page: page,
                    perPage: 50,
                    sort: Anilist.sortBy[1],
                    onList: loadData(PrefName.includeMangaList),
                  ),
                );
                return res?.results ?? [];
              },
            ),
          );
        }
      },
    );

    return [
      LayoutBuilder(
        builder: (context, constraints) {
          final spacing = context.isPhone ? 0.0 : 16.0;
          final horizontalPadding = context.isPhone ? 0.0 : 16.0;
          final maxWidth = constraints.maxWidth - (horizontalPadding * 2);

          final columns = context.isPhone ? 1 : 2;
          final width = (maxWidth - ((columns - 1) * spacing)) / columns;
          final useColumnLayout = width < 480;

          final children = groupedWidgets
              .map(
                (widget) => SizedBox(
                  width: useColumnLayout ? null : width,
                  child: widget,
                ),
              )
              .toList();

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              children: [
                useColumnLayout
                    ? Column(
                        children: children
                            .map(
                              (child) => Padding(
                                padding: EdgeInsets.only(bottom: spacing),
                                child: child,
                              ),
                            )
                            .toList(),
                      )
                    : Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: children,
                      ),

                SizedBox(height: spacing),

                popularSection,
                const SizedBox(height: 128),
              ],
            ),
          );
        },
      ),
    ];
  }
}
