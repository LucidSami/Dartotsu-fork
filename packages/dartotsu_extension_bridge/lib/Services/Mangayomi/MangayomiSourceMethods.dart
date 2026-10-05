import 'package:flutter/foundation.dart';

import '../../Extensions/SourceMethods.dart';
import '../../Models/DEpisode.dart';
import '../../Models/DMedia.dart';
import '../../Models/Page.dart';
import '../../Models/Pages.dart';
import '../../Models/SourcePreference.dart' as s;
import '../../Models/Video.dart';
import 'Eval/dart/model/m_manga.dart';
import 'Eval/dart/model/m_pages.dart';
import 'Eval/dart/model/source_preference.dart';
import 'Models/Source.dart';
import '../../Logger.dart';
import 'Util/ChapterRecognition.dart';
import 'Util/extension_preferences_providers.dart';
import 'Util/get_source_preference.dart';
import 'Util/lib.dart';
import 'Eval/dart/model/filter.dart';

class MangayomiSourceMethods implements SourceMethods {
  @override
  final MSource source;

  MangayomiSourceMethods(this.source);

  @override
  Future<DMedia> getDetail(DMedia media) async {
    final service = getExtensionService(source);
    final MManga data;
    try {
      data = await service.getDetail(media.url!);
    } finally {
      releaseExtensionService(source, service);
    }

    DMedia createMediaData(Map<String, dynamic> args) {
      final media = args['media'] as DMedia;
      final data = args['data'] as MManga;

      final rawChapters = data.chapters
          ?.where((e) => e.name != null && e.url != null)
          .toList();

      final episodes = <DEpisode>[];
      if (rawChapters != null) {
        for (var i = 0; i < rawChapters.length; i++) {
          final e = rawChapters[i];
          final parsedNum = ChapterRecognition.parseChapterNumber(
            media.title ?? '',
            e.name!,
          );
          String epNumStr;
          if (parsedNum is num && parsedNum > 0) {
            epNumStr = parsedNum % 1 == 0
                ? parsedNum.toInt().toString()
                : parsedNum.toString();
          } else {
            final m = RegExp(
              r'(?:episode|ep\.?|ch\.?|chapter)?\s*(\d+(?:\.\d+)?)',
              caseSensitive: false,
            ).firstMatch(e.name!);
            if (m != null) {
              epNumStr = m.group(1)!;
            } else {
              epNumStr = (i + 1).toString();
            }
          }
          episodes.add(
            DEpisode(
              name: e.name!,
              url: e.url!,
              episodeNumber: epNumStr,
              dateUpload: e.dateUpload,
              scanlator: e.scanlator,
            ),
          );
        }
      }
      return DMedia(
        title: media.title,
        url: media.url,
        cover: media.cover,
        description: data.description,
        artist: data.artist,
        author: data.author,
        genre: data.genre,
        episodes: episodes,
      );
    }

    final mediaData = await compute(createMediaData, {
      'media': media,
      'data': data,
    });
    return mediaData;
  }

  @override
  Future<Pages> getLatestUpdates(int page) async {
    final service = getExtensionService(source);
    final MPages data;
    try {
      data = await service.getLatestUpdates(page);
    } finally {
      releaseExtensionService(source, service);
    }

    return Pages(hasNextPage: data.hasNextPage, list: _mapMediaList(data.list));
  }

  @override
  Future<Pages> getPopular(int page) async {
    final service = getExtensionService(source);
    final MPages data;
    try {
      data = await service.getPopular(page);
    } finally {
      releaseExtensionService(source, service);
    }

    return Pages(hasNextPage: data.hasNextPage, list: _mapMediaList(data.list));
  }

  @override
  Future<Pages> search(String query, int page, List<dynamic> filters) async {
    List<dynamic> activeFilters = filters;
    if (filters.isNotEmpty && filters.first is Map) {
      try {
        final filterList = getExtensionService(source).getFilterList();
        _applyMangayomiFilters(filterList.filters, filters);
        activeFilters = filterList.filters;
      } catch (e) {
        Logger.log('MangayomiSourceMethods apply filters error: $e');
      }
    }

    final service = getExtensionService(source);
    final MPages data;
    try {
      data = await service.search(query, page, activeFilters);
    } finally {
      releaseExtensionService(source, service);
    }

    return Pages(hasNextPage: data.hasNextPage, list: _mapMediaList(data.list));
  }

  @override
  Future<List<PageUrl>> getPageList(DEpisode episode) async {
    final service = getExtensionService(source);
    List<dynamic>? data;
    try {
      data = await service.getPageList(episode.url!);
    } catch (e) {
      Logger.log('MangayomiSourceMethods getPageList error: $e');
    } finally {
      releaseExtensionService(source, service);
    }
    if (data == null) return [];
    return data.map((e) => PageUrl(e.url, headers: e.headers)).toList();
  }

  @override
  Future<List<Video>> getVideoList(DEpisode episode) async {
    final service = getExtensionService(source);
    try {
      final data = await service.getVideoList(episode.url!);
      if (data.isEmpty) return [];

      return data.map((e) {
        final q = (e.quality.trim().isNotEmpty) ? e.quality.trim() : 'Default';
        final u = e.url.trim();
        return Video(
          q,
          u,
          q,
          headers: e.headers,
          audios: e.audios
              ?.map((a) => Track(file: a.file, label: a.label))
              .toList(),
          subtitles: e.subtitles
              ?.map((s) => Track(file: s.file, label: s.label))
              .toList(),
        );
      }).toList();
    } catch (e, st) {
      Logger.log('MangayomiSourceMethods getVideoList error: $e\n$st');
      return [];
    } finally {
      releaseExtensionService(source, service);
    }
  }

  @override
  Future<String?> getNovelContent(DEpisode episode) async {
    final service = getExtensionService(source);
    try {
      final data = await service.getHtmlContent(
        episode.name ?? "",
        episode.url ?? "",
      );

      if (data.isEmpty) return null;

      // The JS bridge wraps getHtmlContent in jsonStringify, so the result is
      // a JSON-encoded string. Official Mangayomi does:
      //   html.substring(1, html.length - 1)
      // then passes to _buildHtml which unescapes \\n, \\t, \\" etc.
      // We replicate the same here so novel content renders correctly.
      String result = data;
      if (result.length >= 2 &&
          result.startsWith('"') &&
          result.endsWith('"')) {
        result = result.substring(1, result.length - 1);
      }
      // Decode basic escapes (same as official _buildHtml)
      result = result
          .replaceAll('\\n', '\n')
          .replaceAll('\\r', '')
          .replaceAll('\\t', '\t')
          .replaceAll('\\"', '"')
          .replaceAll("\\'", "'")
          .replaceAll('\\/', '/')
          .replaceAll('\\\\', '\\');

      // Decode unicode escapes (\uXXXX)
      result = result.replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4})'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      );

      return result;
    } catch (e, st) {
      Logger.log('MangayomiSourceMethods getNovelContent error: $e\n$st');
      return null;
    } finally {
      releaseExtensionService(source, service);
    }
  }

  @override
  Future<List<s.SourcePreference>> getPreference() async {
    String getType(SourcePreference pref) {
      if (pref.checkBoxPreference != null) {
        return "checkbox";
      } else if (pref.listPreference != null) {
        return "list";
      } else if (pref.multiSelectListPreference != null) {
        return "multi_select";
      } else if (pref.switchPreferenceCompat != null) {
        return "switch";
      } else if (pref.editTextPreference != null) {
        return "text";
      } else {
        return "other";
      }
    }

    try {
      final data = getSourcePreference(
        source: source,
      )
          .map((e) => getSourcePreferenceEntry(e.key!, source.id!))
          .whereType<SourcePreference>()
          .toList();
      return data
          .map(
            (p) => s.SourcePreference.fromJson(p.toJson())..type = getType(p),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> setPreference(s.SourcePreference pref, value) async {
    var data = SourcePreference.fromJson(pref.toJson())
      ..sourceId = extractSourceId(source.id!);
    if (data.listPreference != null) {
      data.listPreference?.valueIndex = data.listPreference?.entryValues
          ?.indexOf(value ?? '');
    } else if (data.checkBoxPreference != null) {
      data.checkBoxPreference?.value = value;
    } else if (data.switchPreferenceCompat != null) {
      data.switchPreferenceCompat?.value = value;
    } else if (data.editTextPreference != null) {
      data.editTextPreference?.value = value;
    } else if (data.multiSelectListPreference != null) {
      data.multiSelectListPreference?.values = value;
    }
    setPreferenceSetting(data, source);
    return true;
  }

  List<DMedia> _mapMediaList(List<dynamic> list) {
    return list
        .map(
          (e) => DMedia(
            title: e.name,
            url: e.link,
            cover: e.imageUrl,
            description: e.description,
            artist: e.artist,
          ),
        )
        .toList();
  }
  @override
  Stream<List<Video>> getVideoListStream(DEpisode episode) {
    return const Stream.empty();
  }

  @override
  void cancelRequest(String token) {}

  @override
  Future<List<dynamic>> getFilterList() async {
    try {
      final service = getExtensionService(source);
      final filterList = service.getFilterList();
      releaseExtensionService(source, service);
      return filterList.filters.map((f) => _mapMangayomiFilter(f)).toList();
    } catch (e) {
      Logger.log('MangayomiSourceMethods getFilterList error: $e');
      return [];
    }
  }

  Map<String, dynamic> _mapMangayomiFilter(dynamic filter) {
    if (filter is HeaderFilter) {
      return {
        'name': filter.name,
        'type': 'Header',
        'state': null,
      };
    } else if (filter is SeparatorFilter) {
      return {
        'name': '',
        'type': 'Separator',
        'state': null,
      };
    } else if (filter is CheckBoxFilter) {
      return {
        'name': filter.name,
        'type': 'CheckBox',
        'state': filter.state,
      };
    } else if (filter is TriStateFilter) {
      return {
        'name': filter.name,
        'type': 'TriState',
        'state': filter.state,
      };
    } else if (filter is SelectFilter) {
      return {
        'name': filter.name,
        'type': 'Select',
        'state': filter.state,
        'values': filter.values
            .map((v) => v is SelectFilterOption ? v.name : v.toString())
            .toList(),
      };
    } else if (filter is SortFilter) {
      return {
        'name': filter.name,
        'type': 'Sort',
        'state': {
          'index': filter.state.index,
          'ascending': filter.state.ascending,
        },
        'values': filter.values
            .map((v) => v is SelectFilterOption ? v.name : v.toString())
            .toList(),
      };
    } else if (filter is TextFilter) {
      return {
        'name': filter.name,
        'type': 'Text',
        'state': filter.state,
      };
    } else if (filter is GroupFilter) {
      return {
        'name': filter.name,
        'type': 'Group',
        'state': filter.state.map((sub) => _mapMangayomiFilter(sub)).toList(),
      };
    } else {
      if (filter is Map) {
        return Map<String, dynamic>.from(filter);
      }
      return {
        'name': filter.toString(),
        'type': 'Unknown',
        'state': null,
      };
    }
  }

  void _applyMangayomiFilters(List<dynamic> filterList, List<dynamic> uiFilters) {
    for (var i = 0; i < filterList.length && i < uiFilters.length; i++) {
      final filter = filterList[i];
      final uiFilter = uiFilters[i];
      if (uiFilter is! Map) continue;

      final state = uiFilter['state'];
      if (state == null) continue;

      if (filter is CheckBoxFilter) {
        if (state is bool) filter.state = state;
      } else if (filter is TriStateFilter) {
        if (state is int) filter.state = state;
      } else if (filter is SelectFilter) {
        if (state is int) filter.state = state;
      } else if (filter is SortFilter) {
        if (state is Map) {
          filter.state = SortState(
            state['index'] as int? ?? filter.state.index,
            state['ascending'] as bool? ?? filter.state.ascending,
            'SortState',
          );
        }
      } else if (filter is TextFilter) {
        if (state is String) filter.state = state;
      } else if (filter is GroupFilter) {
        if (state is List) {
          _applyMangayomiFilters(filter.state, state);
        }
      }
    }
  }
}
