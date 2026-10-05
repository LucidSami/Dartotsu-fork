import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

import '../../../LnReader/Js/Cheerio.dart';
import '../../../LnReader/Js/HtmlParser.dart';
import '../../../LnReader/Js/HttpClient.dart';
import '../../../LnReader/Js/Libs.dart';
import '../../../LnReader/Js/Polyfills.dart';
import '../../../LnReader/Models/NovelModels.dart';
import '../dart/model/filter.dart';
import '../dart/model/m_chapter.dart';
import '../dart/model/m_manga.dart';
import '../dart/model/m_pages.dart';
import '../dart/model/page.dart';
import '../dart/model/source_preference.dart';
import '../dart/model/video.dart';
import '../../Models/Source.dart';
import '../../Util/extension_preferences_providers.dart';
import '../../Util/interface.dart';


class LNReaderExtensionService implements ExtensionService {
  late JavascriptRuntime runtime;
  @override
  late MSource source;
  bool _isInitialized = false;

  LNReaderExtensionService(this.source);

  void _init() {
    if (_isInitialized) return;
    runtime = getJavascriptRuntime();
    runtime.evaluate('''
globalThis.global = globalThis;
globalThis.window = globalThis;
globalThis.self = globalThis;
module={},exports=Function("return this")(),Object.defineProperties(module,{namespace:{set:function(a){exports=a}},exports:{set:function(a){for(var b in a)a.hasOwnProperty(b)&&(exports[b]=a[b])},get:function(){return exports}}});
''');
    JsPolyfills(runtime).init();
    JsHttpClient(runtime).init();
    JsLibs(runtime).init();
    JsHtmlParser(runtime).init();
    JsCheerio(runtime).init();
    runtime.evaluate('''
const require = (package) => {
  switch (package) {
    case "htmlparser2":
        return {Parser: Parser};
    case "cheerio":
        return {load: load};
    case "dayjs":
        return globalThis.dayjs || module.exports.dayjs;
    case "urlencode":
        return {encode: urlencode, decode: urldecode};
    case "@libs/fetch":
        return {fetchApi: fetchApi, fetchText: fetchText, fetchProto: fetchProto};
    case "@libs/novelStatus":
        return {NovelStatus: NovelStatus};
    case "@libs/isAbsoluteUrl":
        return {isUrlAbsolute: isUrlAbsolute};
    case "@libs/filterInputs":
        return {
          FilterTypes: FilterTypes,
          isPickerValue: isPickerValue,
          isCheckboxValue: isCheckboxValue,
          isSwitchValue: isSwitchValue,
          isTextValue: isTextValue,
          isXCheckboxValue: isXCheckboxValue
        };
    case "@libs/defaultCover":
        return {defaultCover: 'https://raw.githubusercontent.com/LNReader/lnreader-plugins/refs/heads/master/public/static/coverNotAvailable.webp'};
    case "@libs/storage":
        return {storage: {get: () => null, set: () => null}, localStorage: {get: () => null, set: () => null}, sessionStorage: {get: () => null, set: () => null}};
    case "@libs/aes":
        return {
          gcm: function(key, nonce) {
            return {
              encrypt: function(p) { return p; },
              decrypt: function(c) { return c; }
            };
          }
        };
    case "@libs/utils":
    case "@/lib/utils":
        return {
          utf8ToBytes: (s) => Array.from(new TextEncoder().encode(s)),
          bytesToUtf8: (b) => new TextDecoder().decode(new Uint8Array(b))
        };
    case "@libs/parseDate":
        return {
          parseDate: function(d) {
            try {
              var dj = globalThis.dayjs || module.exports.dayjs;
              return dj ? dj(d).format('LL') : String(d);
            } catch(e) {
              return String(d);
            }
          }
        };
    case "lodash-es/reverse":
        return function(arr) { return arr ? arr.slice().reverse() : []; };
    case "lodash-es/uniqBy":
        return function(arr, key) {
          if (!arr) return [];
          var seen = new Set();
          return arr.filter(function(item) {
            var k = typeof key === 'function' ? key(item) : item[key];
            if (seen.has(k)) return false;
            seen.add(k);
            return true;
          });
        };
    case "lodash-es/filter":
        return function(arr, fn) { return arr ? arr.filter(fn) : []; };
    case "lodash-es/map":
        return function(arr, fn) { return arr ? arr.map(fn) : []; };
    default:
        return {};
  }
};
''');
    runtime.evaluate('''
${source.sourceCode}
var pluginInstance = module.exports.default || module.exports || exports.default || exports;
if (typeof pluginInstance === 'function') {
  try {
    pluginInstance = new pluginInstance();
  } catch (e) {}
}
globalThis.extension = pluginInstance;
var extension = pluginInstance;
''');
    _isInitialized = true;
  }

  @override
  Map<String, String> getHeaders() {
    return {};
  }

  @override
  bool get supportsLatest {
    return true;
  }

  @override
  String get sourceBaseUrl {
    return source.baseUrl ?? '';
  }

  @override
  Future<MPages> getPopular(int page) async {
    final items = ((await _extensionCallAsync(
      'popularNovels($page, {showLatestNovels: false, filters: extension.filters})',
      [],
    )))
        .map((e) => NovelItem.fromJson(Map<String, dynamic>.from(e)))
        .map(
          (e) => MManga(
            name: e.name,
            imageUrl: e.cover,
            link: e.path,
            chapters: [],
          ),
        )
        .toList();
    return MPages(list: items, hasNextPage: true);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    final items = ((await _extensionCallAsync(
      'popularNovels($page, {showLatestNovels: true, filters: extension.filters})',
      [],
    )))
        .map((e) => NovelItem.fromJson(Map<String, dynamic>.from(e)))
        .map(
          (e) => MManga(
            name: e.name,
            imageUrl: e.cover,
            link: e.path,
            chapters: [],
          ),
        )
        .toList();
    return MPages(list: items, hasNextPage: true);
  }

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
    try {
      final res = await _extensionCallAsync(
        'searchNovels(${jsonEncode(query)},$page)',
        [],
      );
      final list = res
          .whereType<Map>()
          .map((e) => NovelItem.fromJson(Map<String, dynamic>.from(e)))
          .map(
            (e) => MManga(
              name: e.name,
              imageUrl: e.cover,
              link: e.path,
              chapters: [],
            ),
          )
          .toList();
      return MPages(list: list, hasNextPage: list.isNotEmpty);
    } catch (_) {
      try {
        final res = await _extensionCallAsync(
          'popularNovels($page, {showLatestNovels: false, filters: extension.filters})',
          [],
        );
        final list = res
            .whereType<Map>()
            .map((e) => NovelItem.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .map(
              (e) => MManga(
                name: e.name,
                imageUrl: e.cover,
                link: e.path,
                chapters: [],
              ),
            )
            .toList();
        return MPages(list: list, hasNextPage: list.isNotEmpty);
      } catch (_) {
        return MPages(list: [], hasNextPage: false);
      }
    }
  }

  @override
  Future<MManga> getDetail(String url) async {
    final item = SourceNovel.fromJson(
      Map<String, dynamic>.from(
        await _extensionCallAsync('parseNovel(${jsonEncode(url)})', {}),
      ),
    );

    var chaptersList = item.chapters ?? <ChapterItem>[];
    final int totalPages = item.totalPages.clamp(1, 200);
    if (totalPages > 1 || chaptersList.isEmpty) {
      final allChapters = <ChapterItem>[...chaptersList];
      final seen = <String>{for (final c in chaptersList) c.path};
      for (int page = 1; page <= totalPages; page++) {
        if (page == 1 && chaptersList.isNotEmpty) continue;
        try {
          final res = await _extensionCallAsync(
            'parsePage(${jsonEncode(item.path)}, "$page")',
            {},
          );
          if (res.isNotEmpty) {
            final pageChapters = SourcePage.fromJson(
              Map<String, dynamic>.from(res),
            ).chapters;
            for (final c in pageChapters) {
              if (seen.add(c.path)) {
                allChapters.add(c);
              }
            }
            if (pageChapters.isEmpty) break;
          }
        } catch (_) {
          if (page == 1 && allChapters.isEmpty) break;
        }
      }
      chaptersList = allChapters;
    }

    final chaps = chaptersList
        .map(
          (e) => MChapter(
            name: e.name,
            url: e.path,
            dateUpload: e.releaseTime != null
                ? DateTime.tryParse(
                      e.releaseTime!,
                    )?.millisecondsSinceEpoch.toString() ??
                    int.tryParse(e.releaseTime!)?.toString() ??
                    DateTime.now().millisecondsSinceEpoch.toString()
                : DateTime.now().millisecondsSinceEpoch.toString(),
            scanlator: e.scanlator,
          ),
        )
        .toList();

    return MManga(
      name: item.name,
      imageUrl: item.cover,
      link: item.path,
      artist: item.artist,
      author: item.author,
      description: item.summary,
      status: switch (item.status) {
        "Ongoing" => Status.ongoing,
        "Completed" => Status.completed,
        _ => Status.unknown,
      },
      genre: item.genres?.split(","),
      chapters: chaps.reversed.toList(),
    );
  }

  @override
  Future<List<PageUrl>> getPageList(String url) async {
    return [];
  }

  @override
  Future<List<Video>> getVideoList(String url) async {
    return [];
  }

  @override
  Future<String> getHtmlContent(String name, String url) async {
    _init();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extension.parseChapter(${jsonEncode(url)}))',
      ),
    ))
        .stringResult;
    return res;
  }

  @override
  Future<String> cleanHtmlContent(String html) async {
    return html;
  }

  @override
  FilterList getFilterList() {
    List<dynamic> list;

    try {
      list = fromJsonFilterValuesToList(_extensionCall('filters', []));
    } catch (_) {
      list = [];
    }

    return FilterList(list);
  }

  @override
  List<SourcePreference> getSourcePreferences() {
    return _extensionCall(
      'pluginSettings',
      [],
    )
        .map((e) => SourcePreference.fromJson(Map<String, dynamic>.from(e))
          ..sourceId = extractSourceId(source.id!))
        .toList();
  }

  T _extensionCall<T>(String call, T def) {
    _init();

    try {
      final res = runtime.evaluate('JSON.stringify(extension.$call)');

      return jsonDecode(res.stringResult) as T;
    } catch (_) {
      if (def != null) {
        return def;
      }
      rethrow;
    }
  }

  Future<T> _extensionCallAsync<T>(String call, T def) async {
    _init();

    try {
      final promised = await runtime.handlePromise(
        await runtime.evaluateAsync('jsonStringify(() => extension.$call)'),
      );

      return jsonDecode(promised.stringResult) as T;
    } catch (e) {
      if (def != null) {
        return def;
      }
      rethrow;
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed || !_isInitialized) return;
    _disposed = true;
    runtime.dispose();
  }
}
