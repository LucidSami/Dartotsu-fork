import 'package:dartotsu/Screens/Detail/Tabs/Watch/BaseParser.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

import '../../../../../Api/EpisodeDetails/Anify/Anify.dart';
import '../../../../../Api/EpisodeDetails/Kitsu/Kitsu.dart';
import '../../../../../DataClass/Media.dart';
import '../../../../../Preferences/IsarDataClasses/MediaSettings/MediaSettings.dart';
import 'Widget/AnimeCompactSettings.dart';

class AnimeParser extends BaseParser {
  var unModifiedEpisodeList = Rxn<Map<String, DEpisode>>(null);
  var episodeList = Rxn<Map<String, DEpisode>>(null);
  var anifyEpisodeList = Rxn<Map<String, DEpisode>>(null);
  var kitsuEpisodeList = Rxn<Map<String, DEpisode>>(null);
  var fillerEpisodesList = Rxn<Map<String, DEpisode>>(null);
  var viewType = 0.obs;
  Media? currentMedia;

  void init(Media mediaData) async {
    currentMedia = mediaData;
    if (dataLoaded.value) return;

    initSettings(mediaData);
    await getEpisodeData(mediaData);
  }

  var dataLoaded = false.obs;
  var reversed = false.obs;

  void initSettings(Media mediaData) {
    viewType.value = mediaData.settings.viewType;
    reversed.value = mediaData.settings.isReverse;
  }

  void settingsDialog(BuildContext context, Media media) =>
      AnimeCompactSettings(
        context,
        media,
        source.value,
        scanlator.value,
        toggledScanlators.value,
        (s, t) {
          viewType.value = s.viewType;
          reversed.value = s.isReverse;
          toggledScanlators.value = t;
          if (unModifiedEpisodeList.value != null) {
            episodeList.value = Map.fromEntries(
              unModifiedEpisodeList.value!.entries.where((entry) {
                final scanlator = entry.value.scanlator;

                if (scanlator == null) return true;

                final index = this.scanlator.value?.indexOf(scanlator) ?? -1;
                if (index < 0) return false;

                final toggled = toggledScanlators.value;
                if (toggled == null || index >= toggled.length) return true;
                return toggled[index];
              }),
            );
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
      unModifiedEpisodeList.value = null;
      scanlator.value = null;
      toggledScanlators.value = null;
      episodeList.value = null;
      getEpisode(m, source.value!);
    });
  }

  @override
  void clearMediaContent() {
    super.clearMediaContent();
    unModifiedEpisodeList.value = null;
    episodeList.value = null;
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
      onFinish: (r) => getEpisode(r, source),
    );
  }

  void getEpisode(DMedia? media, Source source) async {
    if (media == null || media.url == null) {
      episodeList.value = {};
      return;
    }

    DMedia? m;
    try {
      m = await source.methods.getDetail(media);
    } catch (e, c) {
      error.value = ParserError(
        ErrorType.NoResult,
        "Failed to fetch media details: $e",
      );
      episodeList.value = {};
      debugPrint("Error fetching media details: $e \n$c");
      return;
    }

    dataLoaded.value = true;

    final chapters = m.episodes;
    if (chapters == null) {
      episodeList.value = {};
      error.value = ParserError(ErrorType.NoResult, "No episodes found");
      return;
    }

    Map<String, DEpisode> sorted;

    if (chapters.length < 50) {
      sorted = processEpisodes(chapters);
    } else {
      sorted = await compute(processEpisodes, chapters);
    }

    if (currentMedia != null) {
      applyMetadataToEpisodes(sorted, currentMedia!);
    }

    unModifiedEpisodeList.value = sorted;
    episodeList.value = sorted;

    var uniqueScanlators = {
      for (var element in sorted.values)
        if (element.scanlator != null) element.scanlator!,
    };

    scanlator.value = uniqueScanlators.toList();
    toggledScanlators.value = List<bool>.filled(uniqueScanlators.length, true);

    error.value = null;
  }

  var episodeDataLoaded = false.obs;

  Future<void> getEpisodeData(Media mediaData) async {
    currentMedia = mediaData;
    try {
      final results = await Future.wait([
        Anify.fetchAndParseMetadata(mediaData),
        Kitsu.getKitsuEpisodesDetails(mediaData),
      ]);
      anifyEpisodeList.value = results[0];
      kitsuEpisodeList.value = results[1];
      fillerEpisodesList.value = results[0];

      // If episodeList is already loaded, merge metadata and trigger reactive UI refresh
      if (episodeList.value != null && episodeList.value!.isNotEmpty) {
        applyMetadataToEpisodes(episodeList.value!, mediaData);
        if (unModifiedEpisodeList.value != null) {
          applyMetadataToEpisodes(unModifiedEpisodeList.value!, mediaData);
        }
        episodeList.refresh();
      }
    } catch (e) {
      debugPrint("Error in getEpisodeData: $e");
    } finally {
      episodeDataLoaded.value = true;
    }
  }

  void applyMetadataToEpisodes(
      Map<String, DEpisode> episodes, Media mediaData) {
    final anify = anifyEpisodeList.value;
    final kitsu = kitsuEpisodeList.value;

    mediaData.anime?.episodes = episodes;
    mediaData.anime?.anifyEpisodes = anify;
    mediaData.anime?.kitsuEpisodes = kitsu;
    mediaData.anime?.fillerEpisodes = fillerEpisodesList.value ?? anify;

    episodes.forEach((key, episode) {
      final anifyEp = findMatchingMetadataEpisode(anify, key, episode);
      final kitsuEp = findMatchingMetadataEpisode(kitsu, key, episode);

      // Title priority: AniZip English/canonical -> Kitsu -> Provider original -> "Episode X"
      final cleanAnifyTitle = (anifyEp?.name ?? '').trim();
      final cleanKitsuTitle = (kitsuEp?.name ?? '').trim();
      final cleanProvTitle = (episode.name ?? '').trim();

      String title;
      if (cleanAnifyTitle.isNotEmpty) {
        title = cleanAnifyTitle;
      } else if (cleanKitsuTitle.isNotEmpty) {
        title = cleanKitsuTitle;
      } else if (cleanProvTitle.isNotEmpty) {
        title = cleanProvTitle;
      } else {
        final epNum = (episode.episodeNumber.isNotEmpty)
            ? episode.episodeNumber
            : key;
        title = 'Episode $epNum';
      }
      episode.name = title;
      episode.title = title;

      // Description priority: AniZip -> Kitsu -> Provider original
      final desc = (anifyEp?.description?.isNotEmpty == true)
          ? anifyEp!.description!
          : (kitsuEp?.description?.isNotEmpty == true)
              ? kitsuEp!.description!
              : (episode.description ?? '');
      episode.description = desc;

      // Thumbnail priority: AniZip TVDB screencap -> Kitsu thumbnail -> Provider thumbnail -> Media Banner -> Media Cover
      final thumb = (anifyEp?.thumbnail?.isNotEmpty == true)
          ? anifyEp!.thumbnail!
          : (kitsuEp?.thumbnail?.isNotEmpty == true)
              ? kitsuEp!.thumbnail!
              : (episode.thumbnail?.isNotEmpty == true)
                  ? episode.thumbnail!
                  : (mediaData.banner ?? mediaData.cover);
      episode.thumbnail = thumb;

      // Rating: AniZip rating
      if (anifyEp?.rating?.isNotEmpty == true) {
        episode.rating = anifyEp!.rating;
      }

      // AirDate: AniZip airDate -> Kitsu airDate
      if (anifyEp?.dateUpload?.isNotEmpty == true) {
        episode.dateUpload = anifyEp!.dateUpload;
      } else if (kitsuEp?.dateUpload?.isNotEmpty == true) {
        episode.dateUpload = kitsuEp!.dateUpload;
      }

      // Filler: check filler flag from AniZip/filler list
      if (anifyEp?.filler != null) {
        episode.filler = anifyEp!.filler;
      }
    });
  }

  static DEpisode? findMatchingMetadataEpisode(
      Map<String, DEpisode>? metaMap, String key, DEpisode ep) {
    if (metaMap == null || metaMap.isEmpty) return null;

    // 1. Direct match on key or episodeNumber
    if (metaMap.containsKey(key)) return metaMap[key];
    if (metaMap.containsKey(ep.episodeNumber)) return metaMap[ep.episodeNumber];

    // Helper: normalize number strings e.g. "01" -> "1", "1.0" -> "1"
    String? cleanNum(String s) {
      if (s.isEmpty) return null;
      final asInt = int.tryParse(s);
      if (asInt != null) return asInt.toString();
      final asDouble = double.tryParse(s);
      if (asDouble != null) {
        if (asDouble == asDouble.toInt()) return asDouble.toInt().toString();
        return asDouble.toString();
      }
      return null;
    }

    final normKey = cleanNum(key);
    if (normKey != null && metaMap.containsKey(normKey)) {
      return metaMap[normKey];
    }

    final normEpNum = cleanNum(ep.episodeNumber);
    if (normEpNum != null && metaMap.containsKey(normEpNum)) {
      return metaMap[normEpNum];
    }

    // 2. Extract numeric token from string (e.g. "Episode 01", "[Sub] Ep 1", name)
    String? extractNum(String text) {
      if (text.isEmpty) return null;
      final epRegex = RegExp(
          r'(?:episode|episodio|ep|e)[\s:.\-]*([0-9]+(?:\.[0-9]+)?)',
          caseSensitive: false);
      final m = epRegex.firstMatch(text);
      if (m != null) return m.group(1);
      final basicNum = RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\b');
      final bm = basicNum.firstMatch(text);
      if (bm != null) return bm.group(1);
      return null;
    }

    final extracted = extractNum(ep.episodeNumber) ??
        extractNum(key) ??
        extractNum(ep.name ?? '');

    if (extracted != null) {
      final cleanExt = cleanNum(extracted);
      if (cleanExt != null && metaMap.containsKey(cleanExt)) {
        return metaMap[cleanExt];
      }
      if (metaMap.containsKey(extracted)) {
        return metaMap[extracted];
      }
    }

    // 3. Scan metadata items if key was an index or formatted differently
    final target =
        normEpNum ?? normKey ?? (extracted != null ? cleanNum(extracted) : null);
    if (target != null) {
      for (final m in metaMap.values) {
        if (cleanNum(m.episodeNumber) == target) {
          return m;
        }
      }
    }

    return null;
  }
}

Map<String, DEpisode> processEpisodes(List<DEpisode> chapters) {
  if (chapters.isEmpty) return {};

  final workingList = List<DEpisode>.from(chapters);

  // Determine if source provided episodes in reverse order (e.g. newest first: Ep 24 ... Ep 1)
  final firstNum = double.tryParse(workingList.first.episodeNumber) ?? 0.0;
  final lastNum = double.tryParse(workingList.last.episodeNumber) ?? 0.0;
  if (workingList.length > 1 && firstNum > lastNum && lastNum > 0.0) {
    workingList.sort((a, b) {
      final aN = double.tryParse(a.episodeNumber) ?? 0.0;
      final bN = double.tryParse(b.episodeNumber) ?? 0.0;
      return aN.compareTo(bN);
    });
  }

  var seenKeys = <String>{};
  var fallbackCounter = 1;

  final map = <String, DEpisode>{};

  for (var i = 0; i < workingList.length; i++) {
    final episode = workingList[i];

    // Clean folder hierarchy in name if present
    final rawTitle = episode.name ?? episode.episodeNumber;
    final normalized = rawTitle.replaceAll(r'\', '/');
    if (normalized.contains('/')) {
      final parts = normalized.split('/').where((s) => s.trim().isNotEmpty).toList();
      if (parts.length > 1) {
        if (episode.scanlator == null || episode.scanlator!.isEmpty) {
          episode.scanlator = parts.sublist(0, parts.length - 1).join(' / ');
        }
        episode.name = parts.last;
      }
    }

    final titleToInspect = episode.name ?? rawTitle;
    final cleanTitle = titleToInspect.trim();

    // 1. Season/Episode detection from title using AnymeX robust regexes
    double? epNumDouble;
    int? detectedSeason;

    for (final reg in [
      RegExp(r'(?:^|[\s_.:\(\[-])S(\d+)[\s:_.-]*E(\d+)(?![\d\w])', caseSensitive: false),
      RegExp(r'(?:^|[\s_.:\(\[-])Season\s*(\d+)[\s,:-]+(?:Episode|Ep\.?)\s*(\d+)(?![\d\w])', caseSensitive: false),
      RegExp(r'(?:^|[\s_.:\(\[-])(\d+)x(\d+)(?![\d\w])', caseSensitive: false),
      RegExp(r'(?:^|[\s_.:\(\[-])S(\d+)[\s:_.-]+(?:Ep\.?|Episode\s+)?(\d+)(?![\d\w])', caseSensitive: false),
    ]) {
      final match = reg.firstMatch(cleanTitle);
      if (match != null) {
        detectedSeason = int.tryParse(match.group(1)!);
        final ep = int.tryParse(match.group(2)!);
        if (ep != null) {
          epNumDouble = ep.toDouble();
          break;
        }
      }
    }

    if (epNumDouble == null) {
      final epMatch = RegExp(r'(?:^|[\s_.:\(\[-])(?:Episode|Ep\.?)\s*(\d+(?:\.\d+)?)(?![\d\w])', caseSensitive: false).firstMatch(cleanTitle);
      if (epMatch != null) {
        epNumDouble = double.tryParse(epMatch.group(1)!);
      }
    }

    if (detectedSeason != null && (episode.scanlator == null || episode.scanlator!.isEmpty)) {
      episode.scanlator = (detectedSeason == 0) ? 'Specials' : 'Season $detectedSeason';
    }

    // 2. If not matched from title, try episode.episodeNumber
    epNumDouble ??= double.tryParse(episode.episodeNumber);

    // 3. If episode number is invalid, 0, or negative, extract using MediaNameAdapter
    if (epNumDouble == null || epNumDouble <= 0.0 || (epNumDouble < 1.0 && epNumDouble > 0.0)) {
      final detectedFromTitle = MediaNameAdapter.findEpisodeNumber(cleanTitle);
      final detectedFromUrl = detectedFromTitle ?? MediaNameAdapter.findEpisodeNumber(episode.url ?? '');
      if (detectedFromUrl != null && detectedFromUrl > 0) {
        epNumDouble = detectedFromUrl;
      } else if (epNumDouble == null || epNumDouble <= 0.0) {
        epNumDouble = fallbackCounter.toDouble();
      }
    }
    fallbackCounter++;

    var formattedNum = epNumDouble % 1 == 0
        ? epNumDouble.toInt().toString()
        : epNumDouble.toString();

    // Preserve the clean, actual episode number (e.g. "14", not "14.2")
    episode.episodeNumber = formattedNum;

    // Detect exact identical clones (same episode number, same scanlator, same URL)
    final streamUrl = episode.url?.trim() ?? '';
    final cloneKey = '$formattedNum|${episode.scanlator ?? ""}|$streamUrl';
    if (streamUrl.isNotEmpty && seenKeys.contains(cloneKey)) {
      continue;
    }
    seenKeys.add(cloneKey);

    if (map.containsKey(formattedNum)) {
      final existing = map[formattedNum]!;
      final bool isTrueSibling = (existing.scanlator != null &&
              episode.scanlator != null &&
              existing.scanlator!.toLowerCase() != episode.scanlator!.toLowerCase());

      if (isTrueSibling) {
        if ((existing.thumbnail == null || existing.thumbnail!.isEmpty) &&
            (episode.thumbnail != null && episode.thumbnail!.isNotEmpty)) {
          existing.thumbnail = episode.thumbnail;
        }
        if ((existing.description == null || existing.description!.isEmpty) &&
            (episode.description != null && episode.description!.isNotEmpty)) {
          existing.description = episode.description;
        }
        existing.siblings ??= [];
        existing.siblings!.add(episode);
        continue;
      } else {
        // Not a distinct audio/scanlator sibling, but a distinct episode colliding on number.
        // Assign next available sequential index so every episode is visible.
        int nextNum = map.length + 1;
        while (map.containsKey(nextNum.toString())) {
          nextNum++;
        }
        formattedNum = nextNum.toString();
        episode.episodeNumber = formattedNum;
      }
    }

    map[formattedNum] = episode;
  }

  // Sort episodes numerically by actual episode number
  final sorted = Map.fromEntries(
    map.entries.toList()
      ..sort((a, b) {
        final aN = double.tryParse(a.key) ?? 0.0;
        final bN = double.tryParse(b.key) ?? 0.0;
        if (aN != bN) return aN.compareTo(bN);
        return a.key.compareTo(b.key);
      }),
  );

  return sorted;
}

class MediaNameAdapter {
  static final _allBracketsRegex = RegExp(r'\[[^\]]*\]|\([^\)]*\)');
  static final _unwantedTags = RegExp(
    r'\b(?:sub|subbed|dub|dubbed|raw|softsub|hardsub|multi|dual|audio|v\d+|ver\d+|version\d+|season\s*\d+|s\d+|\d+p|hi10|hevc|x264|x265|av1|aac|flac|web-dl|bdrip|bluray|remux|repack|proper|5\.1(?:ch)?|7\.1(?:ch)?|2\.0(?:ch)?|stereo|dts|ac3|eac3|truehd|atmos|opus|mp3|ddp?5\.1|10bit|8bit|10-bit|8-bit|hdr(?:10)?|dv|dovi|4k|2k|uhd|fhd|hd|\d+x\d+)\b',
    caseSensitive: false,
  );
  static final _seasonEpRegex = RegExp(
    r'\bS(\d+)[:\s]*E(\d+)\b',
    caseSensitive: false,
  );
  static final _basicEpRegex = RegExp(
    r'(?:\be\.?|\bep\.?|\bepisode|\bepisodio)[\s:.\-]*([0-9]+(?:\.[0-9]+)?)',
    caseSensitive: false,
  );
  static final _hyphenEpRegex = RegExp(
    r'(?:[\s_\-]-\s*|\s+-\s*|\s+#\s*|\bE)([0-9]{1,4}(?:\.[0-9]+)?)(?:\s+|v\d+|\.[a-zA-Z0-9]+|$)',
    caseSensitive: false,
  );
  static final _endEpRegex = RegExp(
    r'(?:^|\s)([0-9]{1,4}(?:\.[0-9]+)?)(?:\s*(?:v\d+|final|end)?\s*(?:\.[a-zA-Z0-9]+)?$)',
    caseSensitive: false,
  );
  static final _numberRegex = RegExp(r'\b([0-9]+(?:\.[0-9]+)?)\b');
  static final _seasonRegex = RegExp(
    r'(?:season|s)[\s:.\-]*([0-9]+)',
    caseSensitive: false,
  );

  static double? findEpisodeNumber(String text) {
    if (text.trim().isEmpty) return null;

    final parsed = double.tryParse(text.trim());
    if (parsed != null) return parsed;

    // 0. Season and Episode pattern (e.g. S0:E10, S01E05)
    final seMatch = _seasonEpRegex.firstMatch(text);
    if (seMatch != null) {
      final num = double.tryParse(seMatch.group(2)!);
      if (num != null) return num;
    }

    // 1. Direct match with standard episode prefix (e.g. "Episode 01", "Ep. 2")
    final basicMatch = _basicEpRegex.firstMatch(text);
    if (basicMatch != null) {
      final num = double.tryParse(basicMatch.group(1)!);
      if (num != null) return num;
    }

    // 2. Strip bracketed metadata (release groups, resolutions, checksums)
    var clean = text;
    final withoutBrackets = clean.replaceAll(_allBracketsRegex, ' ').trim();
    if (withoutBrackets.isNotEmpty && RegExp(r'[0-9]').hasMatch(withoutBrackets)) {
      clean = withoutBrackets;
    }

    // 3. Strip unwanted audio, video, codec, and release tags
    clean = clean
        .replaceAll(_unwantedTags, ' ')
        .replaceAll(',', '.')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();

    // 4. Try prefix match on cleaned text
    final cleanedBasic = _basicEpRegex.firstMatch(clean);
    if (cleanedBasic != null) {
      final num = double.tryParse(cleanedBasic.group(1)!);
      if (num != null) return num;
    }

    // 5. Try hyphen/separator match (e.g. "Frieren - 02")
    final hyphenMatch = _hyphenEpRegex.firstMatch(text);
    if (hyphenMatch != null) {
      final num = double.tryParse(hyphenMatch.group(1)!);
      if (num != null) return num;
    }

    // 6. Try end of title match
    final endMatch = _endEpRegex.firstMatch(clean);
    if (endMatch != null) {
      final num = double.tryParse(endMatch.group(1)!);
      if (num != null) return num;
    }

    // 7. General number matching on cleaned text
    final matches = _numberRegex.allMatches(clean).toList();
    if (matches.isNotEmpty) {
      for (final match in matches) {
        final num = double.tryParse(match.group(1)!);
        if (num != null) return num;
      }
    }

    return double.tryParse(text);
  }

  static int? findSeasonNumber(String text) {
    final match = _seasonRegex.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}
