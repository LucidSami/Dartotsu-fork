import 'dart:collection';
import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

import '../../../../Logger.dart';
import '../../Models/Source.dart';
import '../../Util/extension_preferences_providers.dart';
import '../../Util/interface.dart';
import '../dart/model/filter.dart';
import '../dart/model/m_manga.dart';
import '../dart/model/m_pages.dart';
import '../dart/model/page.dart';
import '../dart/model/source_preference.dart';
import '../dart/model/video.dart';
import 'dom_selector.dart';
import 'extractors.dart';
import 'http.dart';
import 'js_errors.dart';
import 'preferences.dart';
import 'utils.dart';

class JsExtensionService implements ExtensionService {
  late JavascriptRuntime runtime;
  @override
  late MSource source;
  bool _isInitialized = false;

  JsExtensionService(this.source);

  void _init() {
    if (_isInitialized) return;
    runtime = getJavascriptRuntime();
    JsHttpClient(runtime).init();
    JsDomSelector(runtime).init();
    JsVideosExtractors(runtime).init();
    JsUtils(runtime).init();
    final jsPreferences = JsPreferences(runtime, source);
    jsPreferences.init();

    final sourceJson = jsonEncode(source.toMSource().toJson());
    runtime.evaluate('''
class MProvider {
    get source() {
        return $sourceJson;
    }
    get supportsLatest() {
        throw new Error("supportsLatest not implemented");
    }
    getHeaders(url) {
        throw new Error("getHeaders not implemented");
    }
    async getPopular(page) {
        throw new Error("getPopular not implemented");
    }
    async getLatestUpdates(page) {
        throw new Error("getLatestUpdates not implemented");
    }
    async search(query, page, filters) {
        throw new Error("search not implemented");
    }
    async getDetail(url) {
        throw new Error("getDetail not implemented");
    }
    async getPageList() {
        throw new Error("getPageList not implemented");
    }
    async getVideoList(url) {
        throw new Error("getVideoList not implemented");
    }
    async getHtmlContent(name, url) {
        throw new Error("getHtmlContent not implemented");
    }
    async cleanHtmlContent(html) {
        throw new Error("cleanHtmlContent not implemented");
    }
    getFilterList() {
        throw new Error("getFilterList not implemented");
    }
    getSourcePreferences() {
        throw new Error("getSourcePreferences not implemented");
    }
}
async function jsonStringify(fn) {
    return JSON.stringify(await fn());
}
''');
    // evaluate() reports a failure by returning a result with isError set; it
    // does not throw. Ignoring that meant a source which failed to evaluate
    // still set _isInitialized, so `extention` was never created and every
    // later call answered its default. That is what "Video list is empty"
    // was: not an empty list from the source, but a source that never loaded.
    // See kodjodevf/mangayomi#873.
    final code = source.sourceCode;
    if (code == null || code.isEmpty) {
      throw Exception("Source code is empty for ${source.name}");
    }
    _throwIfError(
      runtime.evaluate('''$code
var extention = new DefaultExtension();
'''),
      'loading the source',
    );

    // Extract default preferences synchronously now while runtime is clean and idle
    final defaultPrefs = <String, dynamic>{};
    try {
      final prefsRes = runtime.evaluate('JSON.stringify(extention.getSourcePreferences())');
      if (!prefsRes.isError && prefsRes.stringResult != 'null' && prefsRes.stringResult.isNotEmpty) {
        final decoded = jsonDecode(prefsRes.stringResult);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map && item['key'] != null) {
              final key = item['key'].toString();
              if (item['editTextPreference'] != null && item['editTextPreference'] is Map) {
                defaultPrefs[key] = item['editTextPreference']['value'];
              } else if (item['listPreference'] != null && item['listPreference'] is Map) {
                final lp = item['listPreference'] as Map;
                final idx = lp['valueIndex'] as int? ?? 0;
                final entryVals = lp['entryValues'] as List?;
                if (entryVals != null && idx >= 0 && idx < entryVals.length) {
                  defaultPrefs[key] = entryVals[idx];
                } else if (entryVals != null && entryVals.isNotEmpty) {
                  defaultPrefs[key] = entryVals[0];
                }
              } else if (item['checkBoxPreference'] != null && item['checkBoxPreference'] is Map) {
                defaultPrefs[key] = item['checkBoxPreference']['value'];
              } else if (item['switchPreferenceCompat'] != null && item['switchPreferenceCompat'] is Map) {
                defaultPrefs[key] = item['switchPreferenceCompat']['value'];
              }
            }
          }
        }
      }
    } catch (_) {}
    jsPreferences.setDefaultPreferences(defaultPrefs);

    _isInitialized = true;
  }

  @override
  Map<String, String> getHeaders() {
    return _extensionCall<Map>(
      'getHeaders(${jsonEncode(source.baseUrl ?? '')})',
      {},
    ).toMapStringString!;
  }

  @override
  bool get supportsLatest {
    return _extensionCall<bool>('supportsLatest', true);
  }

  @override
  String get sourceBaseUrl {
    return source.baseUrl!;
  }

  @override
  Future<MPages> getPopular(int page) async {
    final res = await _extensionCallAsync('getPopular($page)');
    if (res == null) return MPages(list: [], hasNextPage: false);
    return MPages.fromJson(res);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    final res = await _extensionCallAsync('getLatestUpdates($page)');
    if (res == null) return MPages(list: [], hasNextPage: false);
    return MPages.fromJson(res);
  }

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
    final activeFilters =
        filters.isNotEmpty ? filters : getFilterList().filters;
    final res = await _extensionCallAsync(
      'search(${jsonEncode(query)},$page,${jsonEncode(filterValuesListToJson(activeFilters))})',
    );
    if (res == null) return MPages(list: [], hasNextPage: false);
    return MPages.fromJson(res);
  }

  @override
  Future<MManga> getDetail(String url) async {
    final res = await _extensionCallAsync('getDetail(${jsonEncode(url)})');
    if (res == null) return MManga();
    return MManga.fromJson(res);
  }

  @override
  Future<List<PageUrl>> getPageList(String url) async {
    final res = await _extensionCallAsync('getPageList(${jsonEncode(url)})');
    if (res == null || res is! List) return [];
    final pages = LinkedHashSet<PageUrl>(
      equals: (a, b) => a.url == b.url,
      hashCode: (p) => p.url.hashCode,
    );

    for (final e in res) {
      if (e != null) {
        final page = e is String
            ? PageUrl(e.trim())
            : PageUrl.fromJson((e as Map).toMapStringDynamic!);
        pages.add(page);
      }
    }

    return pages.toList();
  }

  @override
  Future<List<Video>> getVideoList(String url) async {
    final res = await _extensionCallAsync('getVideoList(${jsonEncode(url)})');
    if (res == null) return [];
    final List list = res is List ? res : (res is Map ? [res] : []);
    final videos = LinkedHashSet<Video>(
      equals: (a, b) => a.url == b.url && a.quality == b.quality,
      hashCode: (v) => Object.hash(v.url, v.quality),
    );

    for (final element in list) {
      if (element is String && element.trim().isNotEmpty) {
        final u = element.trim();
        videos.add(Video(u, 'Default', u));
      } else if (element != null && element is Map) {
        final elMap = Map<String, dynamic>.from(element);
        final rawUrl = elMap['url'] ??
            elMap['videoUrl'] ??
            elMap['file'] ??
            elMap['link'];
        if (rawUrl != null && rawUrl.toString().trim().isNotEmpty) {
          elMap['url'] = rawUrl.toString().trim();
          if (elMap['originalUrl'] == null ||
              elMap['originalUrl'].toString().trim().isEmpty) {
            elMap['originalUrl'] = elMap['url'];
          }
          if (elMap['quality'] == null ||
              elMap['quality'].toString().trim().isEmpty) {
            elMap['quality'] = 'Default';
          }
          try {
            videos.add(Video.fromJson(elMap));
          } catch (e, st) {
            Logger.log(
              'Mangayomi JsExtensionService.getVideoList parsing error: $e\n$st',
            );
          }
        }
      }
    }
    return videos.toList();
  }

  @override
  Future<String> getHtmlContent(String name, String url) async {
    _init();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.getHtmlContent(${jsonEncode(name)}, ${jsonEncode(url)}))',
      ),
    )).stringResult;
    return res;
  }

  @override
  Future<String> cleanHtmlContent(String html) async {
    _init();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.cleanHtmlContent(${jsonEncode(html)}))',
      ),
    )).stringResult;
    return res;
  }

  @override
  FilterList getFilterList() {
    List<dynamic> list;

    try {
      list = fromJsonFilterValuesToList(_extensionCall('getFilterList()', []));
    } catch (_) {
      list = [];
    }

    return FilterList(list);
  }

  @override
  List<SourcePreference> getSourcePreferences() {
    return _extensionCall('getSourcePreferences()', [])
        .map(
          (e) =>
              SourcePreference.fromJson(e)
                ..sourceId = extractSourceId(source.id!),
        )
        .toList();
  }

  T _extensionCall<T>(String call, T def) {
    _init();

    final res = runtime.evaluate('JSON.stringify(extention.$call)');
    if (res.isError) {
      // A source that simply does not implement an optional method is not a
      // failure, and falling back is the whole point of `def`. Anything else
      // is a real error and used to arrive as a JSON parse failure, or as
      // silence when def was non-null.
      if (_isNotImplemented(res) && def != null) return def;
      _throwIfError(res, call);
    }

    try {
      return jsonDecode(res.stringResult) as T;
    } catch (_) {
      if (def != null) return def;
      rethrow;
    }
  }

  Future<T> _extensionCallAsync<T>(String call) async {
    _init();

    final evaluated = await runtime.evaluateAsync(
      'jsonStringify(() => extention.$call)',
    );
    _throwIfError(evaluated, call);

    final promised = await runtime.handlePromise(evaluated);
    _throwIfError(promised, call);

    return jsonDecode(promised.stringResult) as T;
  }

  /// Turns a failed evaluation into an error that says what the source
  /// actually reported.
  ///
  /// Without this the message reaching the reader is either nothing at all or
  /// a JSON parse failure, neither of which says which source broke or why.
  void _throwIfError(JsEvalResult result, String what) {
    if (!result.isError) return;
    throw Exception(
      jsExtensionErrorMessage(
        sourceName: source.name ?? 'unknown',
        whileDoing: what,
        reported: result.stringResult,
      ),
    );
  }

  /// Whether this is the base class saying the source does not implement
  /// something, rather than the source going wrong.
  bool _isNotImplemented(JsEvalResult result) =>
      isNotImplementedError(result.stringResult);

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed || !_isInitialized) return;
    _disposed = true;
    runtime.dispose();
  }
}
