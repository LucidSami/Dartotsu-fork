import 'dart:async';

import 'package:async/async.dart';
import 'package:dartotsu/Downloader/AnimeLocalSource.dart';
import 'package:dartotsu/Theme/LanguageSwitcher.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/cupertino.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:get/get.dart';

import '../../../../DataClass/Media.dart';
import '../../../../Preferences/IsarDataClasses/ShowResponse/ShowResponse.dart';
import '../../../../Preferences/PrefManager.dart';
import '../../../../Widgets/CustomBottomDialog.dart';
import '../../../Settings/language.dart';
import 'Widgets/WrongTitle.dart';

abstract class BaseParser extends GetxController {
  var selectedMedia = Rxn<DMedia?>(null);
  var status = Rxn<String>(null);
  var source = Rxn<Source>(null);
  var error = Rxn<ParserError>();

  var scanlator = Rxn<List<String>>(null);

  var toggledScanlators = Rxn<List<bool>>(null);
  final Rx<List<Source>> sourceList = Rx([]);
  final RxBool sourcesLoaded = false.obs;

  StreamSubscription<List<Source>>? _sourceListSubscription;
  Worker? _managerWorker;
  Worker? _languageWorker;
  void initSourceList(Media media) {
    final isAnime = media.anime != null;
    final itemType = isAnime
        ? ItemType.anime
        : media.format?.toLowerCase() == 'novel'
        ? ItemType.novel
        : ItemType.manga;

    final extensionManager = Get.find<ExtensionManager>();
    String orderKey =
        '${extensionManager[itemType].name}_${itemType.name}_order';

    void updateSourceList(List<Source> sources) {
      final selectedLanguages = extensionManager[itemType]
          .state(itemType)
          .selectedLanguages;
      final filteredSources = selectedLanguages.isEmpty
          ? sources
          : sources.where((source) {
              final lang = source.lang?.toLowerCase() ?? '';
              return selectedLanguages.contains(lang);
            }).toList();

      final sortedSources = [
        ...applySavedOrder(List<Source>.from(filteredSources), orderKey),
        AnimeLocalSource(),
      ];

      sourceList.value = sortedSources;

      final nonLocalSources =
          sortedSources.where((s) => s is! AnimeLocalSource).toList();

      final currentSourceExists = source.value != null &&
          sortedSources.any((s) => s.id == source.value!.id);
      final isCurrentlyLocalOnly =
          source.value == null || source.value is AnimeLocalSource;
      final hasRealSources = nonLocalSources.isNotEmpty;

      if (!sourcesLoaded.value || !currentSourceExists || (isCurrentlyLocalOnly && hasRealSources)) {
        if (nonLocalSources.isEmpty && sources.isEmpty) {
          sourcesLoaded.value = true;
          final fallback = sortedSources.firstOrNull;
          source.value = fallback;
          if (fallback != null) {
            clearMediaContent();
            searchMedia(fallback, media);
          }
          return;
        }

        String nameAndLang(Source source) {
          final isDuplicateName =
              sortedSources.where((s) => s.name == source.name).length > 1;

          return isDuplicateName
              ? '${source.name!} - ${completeLanguageName(source.lang!.toLowerCase())}'
              : source.name!;
        }

        var lastUsedSource = media.settings.lastUsedSource;
        if (lastUsedSource == null ||
            !sortedSources.any((e) => nameAndLang(e) == lastUsedSource)) {
          final firstCandidate = nonLocalSources.isNotEmpty
              ? nonLocalSources.first
              : sortedSources.first;
          lastUsedSource = nameAndLang(firstCandidate);
        }

        final selectedSource =
            sortedSources.firstWhereOrNull(
              (e) => nameAndLang(e) == lastUsedSource,
            ) ??
            (nonLocalSources.isNotEmpty
                ? nonLocalSources.first
                : sortedSources.first);

        source.value = selectedSource;
        clearMediaContent();
        searchMedia(selectedSource, media);
        sourcesLoaded.value = true;
      }
    }

    void subscribeToCurrentManager({bool isSwitch = false}) {
      _sourceListSubscription?.cancel();
      _languageWorker?.dispose();

      if (isSwitch) {
        _currentOperation?.cancel();
        sourcesLoaded.value = false;
        source.value = null;
        clearMediaContent();
      }

      final manager = extensionManager[itemType];
      final state = manager.state(itemType);

      if (state.installed.value.isEmpty) {
        if (itemType == ItemType.anime) {
          manager.fetchInstalledAnimeExtensions();
        } else if (itemType == ItemType.manga) {
          manager.fetchInstalledMangaExtensions();
        } else if (itemType == ItemType.novel) {
          manager.fetchInstalledNovelExtensions();
        }
      }

      updateSourceList(state.installed.value);

      _sourceListSubscription = state.installed.listen(updateSourceList);

      _languageWorker = ever<Set<String>>(
        state.selectedLanguages,
        (_) => updateSourceList(state.installed.value),
      );
    }

    _sourceListSubscription?.cancel();
    _managerWorker?.dispose();

    subscribeToCurrentManager();

    _managerWorker = ever(extensionManager.current, (_) {
      subscribeToCurrentManager(isSwitch: true);
    });
  }

  void clearMediaContent() {
    selectedMedia.value = null;
    error.value = null;
    status.value = null;
  }

  void switchManager(ItemType itemType, String managerId, Media media) {
    final extensionManager = Get.find<ExtensionManager>();
    if (extensionManager[itemType].id == managerId) return;

    _currentOperation?.cancel();
    sourcesLoaded.value = false;
    source.value = null;
    clearMediaContent();

    extensionManager.switchManager(itemType, managerId);
  }

  List<Source> applySavedOrder(List<Source> list, String orderKey) {
    final saved = loadCustomData<List<String>>(
      orderKey,
      defaultValue: const [],
    );

    if (saved == null || saved.isEmpty) return list;

    final order = <String, int>{
      for (var i = 0; i < saved.length; i++) saved[i]: i,
    };

    list.sort((a, b) {
      final ai = order[a.id] ?? 1 << 30;
      final bi = order[b.id] ?? 1 << 30;
      return ai.compareTo(bi);
    });

    return list;
  }

  @override
  void dispose() {
    _currentOperation?.cancel();
    _sourceListSubscription?.cancel();
    _managerWorker?.dispose();
    _languageWorker?.dispose();
    super.dispose();
  }

  CancelableOperation? _currentOperation;

  Future<void> searchMedia(
    Source source,
    Media mediaData, {
    Function(DMedia? response)? onFinish,
  }) async {
    _currentOperation?.cancel();

    _currentOperation = CancelableOperation.fromFuture(
      _performSearch(source, mediaData, onFinish),
      onCancel: () {
        status.value = "Search canceled";
      },
    );

    await _currentOperation?.valueOrCancellation();
  }

  Future<void> _performSearch(
    Source source,
    Media mediaData,
    Function(DMedia? response)? onFinish,
  ) async {
    try {
      selectedMedia.value = null;
      status.value = "Searching...";
      var saved = _loadShowResponse(source, mediaData);
      if (saved != null) {
        var response = DMedia(
          title: saved.name,
          cover: saved.coverUrl,
          url: saved.link,
        );
        selectedMedia.value = response;
        _saveShowResponse(mediaData, response, source, selected: true);
        onFinish?.call(response);
        return;
      }
      DMedia? response;
      final mainName = mediaData.mainName();
      status.value = "Searching : $mainName";
      final mediaFuture = source.methods.search(mainName, 1, []);

      final media = await mediaFuture;

      List<DMedia> sortedResults = media.list.isNotEmpty
          ? (media.list..sort((a, b) {
              final aRatio = ratio(
                a.title!.toLowerCase(),
                mainName.toLowerCase(),
              );
              final bRatio = ratio(
                b.title!.toLowerCase(),
                mainName.toLowerCase(),
              );
              return bRatio.compareTo(aRatio);
            }))
          : [];
      response = sortedResults.firstOrNull;

      final currentMainRatio = response != null && response.title != null
          ? ratio(response.title!.toLowerCase(), mainName.toLowerCase())
          : 0;

      // Phase 2: If no response or match is not 100%, search romaji
      if (response == null || currentMainRatio < 100) {
        final romajiName = mediaData.nameRomaji;
        if (romajiName.isNotEmpty && romajiName != mainName) {
          status.value = "Searching : $romajiName";
          try {
            final romajiMedia = await source.methods.search(romajiName, 1, []);
            List<DMedia> sortedRomajiResults = romajiMedia.list.isNotEmpty
                ? (romajiMedia.list..sort((a, b) {
                    final aRatio = ratio(
                      a.title!.toLowerCase(),
                      romajiName.toLowerCase(),
                    );
                    final bRatio = ratio(
                      b.title!.toLowerCase(),
                      romajiName.toLowerCase(),
                    );
                    return bRatio.compareTo(aRatio);
                  }))
                : [];
            final closestRomaji = sortedRomajiResults.firstOrNull;
            if (response == null) {
              response = closestRomaji;
            } else if (closestRomaji != null && closestRomaji.title != null) {
              final romajiRatio = ratio(
                closestRomaji.title!.toLowerCase(),
                romajiName.toLowerCase(),
              );
              if (romajiRatio > currentMainRatio) {
                response = closestRomaji;
              }
            }
          } catch (_) {}
        }
      }

      // Phase 3: If still null or match ratio < 80, iterate synonyms
      final bestRatio = response != null && response.title != null
          ? ratio(response.title!.toLowerCase(), mainName.toLowerCase())
          : 0;

      if (response == null || bestRatio < 80) {
        var currentBestRatio = bestRatio;
        for (var rawSynonym in mediaData.synonyms) {
          final synonym = rawSynonym.trim();
          if (synonym.isEmpty || synonym == mainName || synonym == mediaData.nameRomaji) {
            continue;
          }
          status.value = "Searching : $synonym";
          try {
            final synonymMedia = await source.methods.search(synonym, 1, []);
            List<DMedia> sortedSynonymResults = synonymMedia.list.isNotEmpty
                ? (synonymMedia.list..sort((a, b) {
                    final aRatio = ratio(
                      a.title!.toLowerCase(),
                      synonym.toLowerCase(),
                    );
                    final bRatio = ratio(
                      b.title!.toLowerCase(),
                      synonym.toLowerCase(),
                    );
                    return bRatio.compareTo(aRatio);
                  }))
                : [];
            final closestSynonym = sortedSynonymResults.firstOrNull;
            if (closestSynonym != null && closestSynonym.title != null) {
              final synRatio = ratio(
                closestSynonym.title!.toLowerCase(),
                synonym.toLowerCase(),
              );
              if (synRatio >= 80 && synRatio > currentBestRatio) {
                response = closestSynonym;
                currentBestRatio = synRatio;
                if (synRatio >= 95) {
                  break;
                }
              }
            }
          } catch (_) {}
        }
      }
      if (response != null) {
        error.value = null;
        _saveShowResponse(mediaData, response, source);
        selectedMedia.value = response;
        onFinish?.call(response);
      } else {
        status.value = "Nothing Found";
        error.value = ParserError(
          ErrorType.NotFound,
          "No matching media found",
        );
        onFinish?.call(response);
      }
    } catch (e, c) {
      status.value = "Error during search";
      error.value = ParserError(ErrorType.Error, e.toString());
      debugPrint("Error during search: $e \n$c");
      onFinish?.call(null);
    }
  }

  ShowResponse? _loadShowResponse(Source source, Media mediaData) {
    return loadCustomData<ShowResponse?>(
      "${source.name}_${mediaData.id}_source",
    );
  }

  void _saveShowResponse(
    Media mediaData,
    DMedia response,
    Source source, {
    bool selected = false,
  }) {
    status.value = selected
        ? "${getString.selected} : ${response.title}"
        : "${getString.found} : ${response.title}";
    var show = ShowResponse(
      name: response.title,
      link: response.url,
      coverUrl: response.cover,
    );
    saveCustomData<ShowResponse>("${source.name}_${mediaData.id}_source", show);
  }

  void clearResponseCache(Source source, Media mediaData) {
    removeCustomData("${source.name}_${mediaData.id}_source");
    searchMedia(source, mediaData);
  }

  Future<void> wrongTitle(
    BuildContext context,
    Media mediaData,
    Function(DMedia)? onChange,
  ) async {
    var dialog = WrongTitleDialog(
      source: source.value!,
      mediaData: mediaData,
      selectedMedia: selectedMedia,
      onChanged: (m) {
        selectedMedia.value = m;
        _saveShowResponse(mediaData, m, source.value!, selected: true);
        onChange?.call(m);
      },
    );
    showCustomBottomDialog(context, dialog);
  }
}

class ParserError {
  final ErrorType type;
  final String message;

  ParserError(this.type, this.message);
}

enum ErrorType { None, NotFound, NoResult, Error }
