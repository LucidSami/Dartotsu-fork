import 'dart:math';

import 'package:dartotsu/Theme/LanguageSwitcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Adaptor/Media/Widgets/MediaSection.dart';
import '../../../DataClass/Media.dart';
import '../../../DataClass/MediaSection.dart';
import '../../../Functions/Function.dart';
import '../../../Preferences/PrefManager.dart';
import '../../../Screens/MediaList/MediaListDetailScreen.dart';
import '../../../Services/Screens/BaseHomeScreen.dart';
import '../../../main.dart';
import '../Mal.dart';
import '../MalQueries.dart';

class MalHomeScreen extends BaseHomeScreen {
  final MalController Mal;

  MalHomeScreen(this.Mal);

  var animeContinue = Rx<List<Media>?>(null);
  var animeOnHold = Rx<List<Media>?>(null);
  var animePlanned = Rx<List<Media>?>(null);
  var animeDropped = Rx<List<Media>?>(null);
  var mangaContinue = Rx<List<Media>?>(null);
  var mangaPlanned = Rx<List<Media>?>(null);
  var mangaDropped = Rx<List<Media>?>(null);
  var mangaOnHold = Rx<List<Media>?>(null);
  var hidden = Rx<List<Media>?>(null);

  Future<void> getUserId({bool force = false}) async {
    if (Mal.token.isEmpty) {
      Mal.getSavedToken();
    }
    if (Mal.token.isNotEmpty && (force || Mal.userid == null || Mal.userid! <= 0)) {
      await (Mal.query as MalQueries?)?.getUserData(force: force);
    }
  }

  @override
  get paging => false;

  @override
  int get refreshID => RefreshId.Mal.homePage;

  void resetPageData() {
    animeContinue.value = null;
    animeOnHold.value = null;
    animePlanned.value = null;
    animeDropped.value = null;
    mangaContinue.value = null;
    mangaPlanned.value = null;
    mangaDropped.value = null;
    mangaOnHold.value = null;
    hidden.value = null;
  }

  @override
  Future<void> loadAll({bool force = false}) async {
    if (animeContinue.value == null) {
      resetPageData();
    }
    try {
      await getUserId(force: force).timeout(const Duration(seconds: 15), onTimeout: () {});
    } catch (e) {
      debugPrint("MalHomeScreen getUserId error: $e");
    }
    try {
      await loadList(force: force).timeout(const Duration(seconds: 20), onTimeout: () {
        debugPrint("MalHomeScreen loadList timed out");
      });
    } catch (e) {
      debugPrint("MalHomeScreen loadList error: $e");
    } finally {
      if (animeContinue.value == null) {
        _setMediaList({});
      }
    }
  }

  Future<void> loadList({bool force = false}) async {
    if (Mal.token.isEmpty) {
      _setMediaList({});
      return;
    }
    try {
      final res = await Mal.query!.initHomePage(force: force);
      if (res != null && res.isNotEmpty) {
        _setMediaList(res);
      } else if (animeContinue.value == null) {
        snackString("MyAnimeList API is down or unreachable");
        _setMediaList({});
      }
    } catch (e) {
      if (animeContinue.value == null) {
        snackString("MyAnimeList API is down or unreachable");
        _setMediaList({});
      }
    }
  }

  void _setMediaList(Map<String, List<Media>> res) {
    animeContinue.value = res["Watching"] ?? [];
    animeOnHold.value = res["OnHold"] ?? [];
    animeDropped.value = res["Dropped"] ?? [];
    animePlanned.value = res["PlanToWatch"] ?? [];
    mangaContinue.value = res["Reading"] ?? [];
    mangaOnHold.value = res["OnHoldReading"] ?? [];
    mangaDropped.value = res["DroppedReading"] ?? [];
    mangaPlanned.value = res["PlanToRead"] ?? [];
    hidden.value = res["hidden"] ?? [];

    List<String?> listImage = [];

    String? pickRandomCover(List<Media>? list) {
      if (list == null || list.isEmpty) return null;
      return (List.of(list)..shuffle(Random())).first.cover;
    }

    final animeCover = pickRandomCover(animeContinue.value);
    if (animeCover != null) listImage.add(animeCover);

    final mangaCover = pickRandomCover(mangaContinue.value);
    if (mangaCover != null) listImage.add(mangaCover);

    if (listImage.isNotEmpty) {
      if (listImage.length == 1) listImage.add(listImage.first);
      listImages.value = listImage;
    }
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
        onLongPressTitle: () => showHidden.value = !showHidden.value,
      ),
      MediaSectionData(
        type: 0,
        title: getString.onHold(getString.anime),
        pairTitle: 'OnHold Anime',
        list: animeOnHold.value,
        emptyIcon: Icons.movie_filter_rounded,
        emptyMessage: getString.noOnHold,
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
        title: getString.droppedAnime,
        pairTitle: 'Dropped Anime',
        list: animeDropped.value,
        emptyIcon: Icons.movie_filter_rounded,
        emptyMessage: getString.noDropped(getString.anime),
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
        title: getString.onHold(getString.manga),
        pairTitle: 'OnHold Manga',
        list: mangaOnHold.value,
        emptyIcon: Icons.import_contacts,
        emptyMessage: getString.noOnHold,
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
        title: getString.droppedManga,
        pairTitle: 'Dropped Manga',
        list: mangaDropped.value,
        emptyIcon: Icons.import_contacts,
        emptyMessage: getString.noDropped(getString.manga),
      ),
    ];

    final homeLayoutMap = loadData(PrefName.malHomeLayout);
    final sectionMap = {
      for (var section in mediaSections) section.pairTitle: section
    };

    final malQuery = Mal.query as MalQueries?;

    Future<List<Media>?> Function(int page)? getFetchMore(String pairTitle) {
      if (malQuery == null) return null;
      switch (pairTitle) {
        case 'Continue Watching':
          return (page) =>
              malQuery.loadUserMediaListPage('anime', 'watching', page);
        case 'OnHold Anime':
          return (page) =>
              malQuery.loadUserMediaListPage('anime', 'on_hold', page);
        case 'Planned Anime':
          return (page) =>
              malQuery.loadUserMediaListPage('anime', 'plan_to_watch', page);
        case 'Dropped Anime':
          return (page) =>
              malQuery.loadUserMediaListPage('anime', 'dropped', page);
        case 'Continue Reading':
          return (page) =>
              malQuery.loadUserMediaListPage('manga', 'reading', page);
        case 'OnHold Manga':
          return (page) =>
              malQuery.loadUserMediaListPage('manga', 'on_hold', page);
        case 'Planned Manga':
          return (page) =>
              malQuery.loadUserMediaListPage('manga', 'plan_to_read', page);
        case 'Dropped Manga':
          return (page) =>
              malQuery.loadUserMediaListPage('manga', 'dropped', page);
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
      sectionWidgets.first.onLongPressTitle =
          () => showHidden.value = !showHidden.value;
    }

    final result = sectionWidgets.map((section) {
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
      Obx(
        () {
          final allSections = List<Widget>.from(result);
          if (showHidden.value) allSections.insert(0, hiddenMedia);

          return LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 16.0;
              final horizontalPadding = context.isPhone ? 0.0 : 16.0;
              final maxWidth = constraints.maxWidth - horizontalPadding;

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
                padding: EdgeInsets.only(right: horizontalPadding),
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
        },
      ),
    ];
  }
}
