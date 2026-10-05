import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

import '../../../../../DataClass/Media.dart';
import '../../../../../Preferences/IsarDataClasses/MediaSettings/MediaSettings.dart';
import '../BaseParser.dart';
import 'Widget/MangaCompactSettings.dart';

import '../Functions/ChapterOrdering.dart';

class MangaParser extends BaseParser {
  var unModifiedChapterList = Rxn<List<DEpisode>>(null);
  var chapterList = Rxn<List<DEpisode>>(null);
  var dataLoaded = false.obs;

  void init(Media mediaData) async {
    viewType.value = mediaData.settings.viewType;
    reversed.value = mediaData.settings.isReverse;
  }

  var viewType = 0.obs;
  var reversed = false.obs;

  void settingsDialog(BuildContext context, Media media) =>
      MangaCompactSettings(
        context,
        media,
        source.value,
        scanlator.value,
        toggledScanlators.value,
        (s, t) {
          viewType.value = s.viewType;
          reversed.value = s.isReverse;
          toggledScanlators.value = t;
          if (unModifiedChapterList.value != null) {
            chapterList.value = unModifiedChapterList.value!.where((element) {
              final scanlator = element.scanlator;
              if (scanlator == null) return true;
              final index = this.scanlator.value?.indexOf(scanlator) ?? -1;
              if (index < 0) return false;
              final toggled = toggledScanlators.value;
              if (toggled == null || index >= toggled.length) return true;
              return toggled[index];
            }).toList();
          }
          MediaSettings.saveMediaSettings(
            media
              ..settings.viewType = s.viewType
              ..settings.isReverse = s.isReverse,
          );
        },
      ).showDialog();

  @override
  Future<void> wrongTitle(context, mediaData, onChange) async {
    super.wrongTitle(context, mediaData, (m) {
      unModifiedChapterList.value = null;
      chapterList.value = null;
      scanlator.value = null;
      toggledScanlators.value = null;
      getChapter(m, source.value!);
    });
  }

  @override
  void clearMediaContent() {
    super.clearMediaContent();
    unModifiedChapterList.value = null;
    chapterList.value = null;
    scanlator.value = null;
    toggledScanlators.value = null;
    dataLoaded.value = false;
  }

  @override
  Future<void> searchMedia(source, mediaData, {onFinish}) async {
    clearMediaContent();
    super.searchMedia(
      source,
      mediaData,
      onFinish: (r) => getChapter(r, source),
    );
  }

  void getChapter(DMedia? media, Source source) async {
    if (media == null || media.url == null) {
      chapterList.value = <DEpisode>[];
      error.value = ParserError(ErrorType.NotFound, "Media or URL is missing");
      return;
    }

    DMedia? m;
    try {
      m = await source.methods.getDetail(media);
    } catch (e, c) {
      if (media.url != null &&
          !media.url!.startsWith('http://') &&
          !media.url!.startsWith('https://') &&
          !media.url!.startsWith('/')) {
        try {
          final fixedMedia = DMedia(
            title: media.title,
            cover: media.cover,
            url: '/${media.url}',
            author: media.author,
            artist: media.artist,
            description: media.description,
            genre: media.genre,
          );
          m = await source.methods.getDetail(fixedMedia);
        } catch (_) {}
      }
      if (m == null) {
        debugPrint("$e\n$c");
        error.value = ParserError(ErrorType.NoResult, e.toString());
        chapterList.value = <DEpisode>[];
        return;
      }
    }

    dataLoaded.value = true;

    if (m.episodes == null || m.episodes!.isEmpty) {
      chapterList.value = <DEpisode>[];
      error.value = ParserError(ErrorType.NoResult, "No chapters available");
      return;
    }

    // Dedup, orient oldest -> newest (without re-sorting the source order)
    // and repair numbering so chunks / progress / navigation are accurate.
    final episodes = ChapterOrdering.normalize(
      List<DEpisode>.from(m.episodes!),
      mediaTitle: m.title ?? media.title ?? '',
    );

    chapterList.value = episodes;
    unModifiedChapterList.value = chapterList.value;

    var uniqueScanlators = {
      for (var element in chapterList.value!)
        if (element.scanlator != null) element.scanlator!,
    };

    scanlator.value = uniqueScanlators.toList();
    toggledScanlators.value = List<bool>.filled(uniqueScanlators.length, true);

    error.value = null;
  }
}
