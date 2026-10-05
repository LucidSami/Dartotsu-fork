import 'package:dartotsu/Services/Screens/BaseHomeScreen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Adaptor/Media/Widgets/MediaSection.dart';
import '../../../DataClass/Media.dart';
import '../../../DataClass/MediaSection.dart';
import '../../../DataClass/SearchResults.dart';
import '../../../DataClass/User.dart';
import '../../../Functions/Function.dart';
import '../../../Preferences/PrefManager.dart';
import '../../../Screens/MediaList/MediaListDetailScreen.dart';
import '../../../Theme/LanguageSwitcher.dart';
import '../../../main.dart';
import '../Anilist.dart';
import '../AnilistQueries.dart';

class AnilistHomeScreen extends BaseHomeScreen {
  final AnilistController Anilist;

  AnilistHomeScreen(this.Anilist);

  var animeContinue = Rx<List<Media>?>(null);
  var animeFav = Rx<List<Media>?>(null);
  var animePlanned = Rx<List<Media>?>(null);
  var mangaContinue = Rx<List<Media>?>(null);
  var mangaFav = Rx<List<Media>?>(null);
  var mangaPlanned = Rx<List<Media>?>(null);
  var recommendation = Rx<List<Media>?>(null);
  var userStatus = Rx<List<userData>?>(null);
  var hidden = Rx<List<Media>?>(null);

  @override
  get paging => false;

  Future<void> getUserId() async {
    if (Anilist.token.isNotEmpty) {
      await Anilist.query!.getUserData();
    }
  }

  @override
  Future<void> loadAll({bool force = false}) async {
    if (animeContinue.value == null) {
      resetPageData();
    }
    try {
      await getUserId();
      await setListImages();
      await loadList(force: force);
    } catch (e, s) {
      debugPrint("Error in Anilist loadAll: $e\n$s");
      if (animeContinue.value == null) {
        snackString("AniList API is down or unreachable");
        _setMediaList({});
      }
    }
  }

  Future<void> setListImages() async {
    try {
      listImages.value = await Anilist.query!.getBannerImages();
    } catch (_) {
      listImages.value = [];
    }
  }

  Future<void> loadList({bool force = false}) async {
    try {
      if (Anilist.token.isNotEmpty &&
          (Anilist.userid == null || Anilist.userid! <= 0)) {
        await getUserId();
      }
      final res = await Anilist.query!.initHomePage(force: force);
      if (res != null && res.isNotEmpty) {
        _setMediaList(res);
      } else if (animeContinue.value == null) {
        snackString("AniList API is down or unreachable");
        _setMediaList({});
      }
    } catch (e, s) {
      debugPrint("Error in Anilist loadList: $e\n$s");
      if (animeContinue.value == null) {
        snackString("AniList API is down or unreachable");
        _setMediaList({});
      }
    }
  }

  void _setMediaList(Map<String, List<Media>> res) {
    animeContinue.value = res["currentAnime"] ?? [];
    animeFav.value = res["favoriteAnime"] ?? [];
    animePlanned.value = res["currentAnimePlanned"] ?? [];
    mangaContinue.value = res["currentManga"] ?? [];
    mangaFav.value = res["favoriteManga"] ?? [];
    mangaPlanned.value = res["currentMangaPlanned"] ?? [];
    recommendation.value = res["recommendations"] ?? [];
    hidden.value = res["hidden"] ?? [];
  }

  @override
  int get refreshID => RefreshId.Anilist.homePage;

  void resetPageData() {
    animeContinue.value = null;
    animeFav.value = null;
    animePlanned.value = null;
    mangaContinue.value = null;
    mangaFav.value = null;
    mangaPlanned.value = null;
    recommendation.value = null;
    hidden.value = null;
  }

  @override
  List<Widget> mediaContent(BuildContext context) {
    var showHidden = false.obs;

    final mediaSections = [
      MediaSectionData(
        type: 0,
        title: getString.continueWatching,
        pairTitle: 'Continue Watching',
        list: animeContinue.value,
        emptyIcon: Icons.movie_filter_rounded,
        emptyMessage: getString.allCaughtUpNew,
        emptyButtonText: getString.browse(getString.anime),
        emptyButtonOnPressed: () => navbar.onClick(0),
      ),
      MediaSectionData(
        type: 0,
        title: getString.favorite(getString.anime),
        pairTitle: 'Favourite Anime',
        list: animeFav.value,
        emptyIcon: Icons.heart_broken,
        emptyMessage: getString.noFavourites,
      ),
      MediaSectionData(
        type: 0,
        title: getString.planned(getString.anime),
        pairTitle: 'Planned Anime',
        list: animePlanned.value,
        emptyIcon: Icons.movie_filter_rounded,
        emptyMessage: getString.allCaughtUpNew,
        emptyButtonText: getString.browse(getString.anime),
        emptyButtonOnPressed: () => navbar.onClick(0),
      ),
      MediaSectionData(
        type: 0,
        title: getString.continueReading,
        pairTitle: 'Continue Reading',
        list: mangaContinue.value,
        emptyIcon: Icons.import_contacts,
        emptyMessage: getString.allCaughtUpNew,
        emptyButtonText: getString.browse(getString.manga),
        emptyButtonOnPressed: () => navbar.onClick(2),
      ),
      MediaSectionData(
        type: 0,
        title: getString.favorite(getString.manga),
        pairTitle: 'Favourite Manga',
        list: mangaFav.value,
        emptyIcon: Icons.heart_broken,
        emptyMessage: getString.noFavourites,
      ),
      MediaSectionData(
        type: 0,
        title: getString.planned(getString.manga),
        pairTitle: 'Planned Manga',
        list: mangaPlanned.value,
        emptyIcon: Icons.import_contacts,
        emptyMessage: getString.allCaughtUpNew,
        emptyButtonText: getString.browse(getString.manga),
        emptyButtonOnPressed: () => navbar.onClick(2),
      ),
      MediaSectionData(
        type: 0,
        title: getString.recommended,
        pairTitle: 'Recommended',
        list: recommendation.value,
        emptyIcon: Icons.auto_awesome,
        isLarge: true,
        emptyMessage: getString.recommendationsEmptyMessage,
      ),
    ];

    final bool migrationDone =
        loadCustomData<bool>('anilist_planned_sections_v2') ?? false;
    Map<dynamic, dynamic> homeLayoutMap =
        Map<dynamic, dynamic>.from(loadData(PrefName.anilistHomeLayout));
    if (!migrationDone) {
      homeLayoutMap['Planned Anime'] = true;
      homeLayoutMap['Planned Manga'] = true;
      saveData(PrefName.anilistHomeLayout, homeLayoutMap);
      saveCustomData('anilist_planned_sections_v2', true);
    }

    final sectionMap = {
      for (var section in mediaSections) section.pairTitle: section,
    };

    final anilistQuery = Anilist.query as AnilistQueries?;

    Future<List<Media>?> Function(int page)? getFetchMore(String pairTitle) {
      if (anilistQuery == null) return null;
      switch (pairTitle) {
        case 'Continue Watching':
          return (page) => anilistQuery.getUserMediaListPaged(
                anime: true,
                status: 'CURRENT',
                page: page,
              );
        case 'Planned Anime':
          return (page) => anilistQuery.getUserMediaListPaged(
                anime: true,
                status: 'PLANNING',
                page: page,
              );
        case 'Continue Reading':
          return (page) => anilistQuery.getUserMediaListPaged(
                anime: false,
                status: 'CURRENT',
                page: page,
              );
        case 'Planned Manga':
          return (page) => anilistQuery.getUserMediaListPaged(
                anime: false,
                status: 'PLANNING',
                page: page,
              );
        case 'Favourite Anime':
          return (page) => anilistQuery.getFavouritesPage(
                anime: true,
                page: page,
              );
        case 'Favourite Manga':
          return (page) => anilistQuery.getFavouritesPage(
                anime: false,
                page: page,
              );
        case 'Recommended':
          return (page) async {
            final res = await anilistQuery.search(
              SearchResults(
                type: SearchType.ANIME,
                page: page,
                perPage: 30,
                sort: "SCORE_DESC",
              ),
            );
            return res?.results ?? [];
          };
        default:
          return null;
      }
    }

    final sectionWidgets = homeLayoutMap.entries
        .where((entry) => entry.value)
        .map((entry) => sectionMap[entry.key])
        .whereType<MediaSectionData>()
        .toList();

    if (sectionWidgets.isNotEmpty) {
      sectionWidgets.first.onLongPressTitle = () =>
          showHidden.value = !showHidden.value;
    }

    final List<Widget> result = sectionWidgets.map((section) {
      return MediaSection(
        context: context,
        type: section.type,
        title: section.title,
        mediaList: section.list,
        isLarge: section.isLarge,
        onLongPressTitle: section.onLongPressTitle,
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
        customNullListIndicator: buildNullIndicator(
          context,
          section.emptyIcon,
          section.emptyMessage,
          section.emptyButtonText,
          section.emptyButtonOnPressed,
        ),
      );
    }).toList();

    var hiddenMedia = MediaSection(
      context: context,
      type: 0,
      title: getString.hiddenMedia,
      mediaList: hidden.value,
      onLongPressTitle: () => showHidden.value = !showHidden.value,
      onTrailingIconTap: () {
        if (hidden.value?.isNotEmpty ?? false) {
          navigateToPage(
            context,
            MediaListDetailScreen(
              title: getString.hiddenMedia,
              mediaList: hidden.value!,
            ),
          );
        }
      },
      customNullListIndicator: buildNullIndicator(
        context,
        Icons.visibility_off,
        getString.noHiddenMediaFound,
        null,
        null,
      ),
    );

    return [
      Obx(() {
        final allSections = List<Widget>.from(result);
        if (showHidden.value) allSections.insert(0, hiddenMedia);

        return LayoutBuilder(
          builder: (context, constraints) {
            final spacing = context.isPhone ? 0.0 : 16.0;
            final horizontalPadding = context.isPhone ? 0.0 : 16.0;
            final maxWidth = constraints.maxWidth - (horizontalPadding * 2);

            final columns = context.isPhone ? 1 : 2;
            final width = (maxWidth - ((columns - 1) * spacing)) / columns;
            final useColumnLayout = width < 480;

            final children = allSections.map((section) {
              return SizedBox(
                width: useColumnLayout ? null : width,
                child: section,
              );
            }).toList();

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
                  const SizedBox(height: 128),
                ],
              ),
            );
          },
        );
      }),
    ];
  }
}
