import 'dart:async';
import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

import '../../Extensions/SourceMethods.dart';
import '../../Logger.dart';
import '../../Models/DEpisode.dart';
import '../../Models/DMedia.dart';
import '../../Models/Page.dart';
import '../../Models/Pages.dart';
import '../../Models/SourcePreference.dart';
import '../../Models/Video.dart';
import '../../NetworkClient.dart';
import 'Js/Cheerio.dart';
import 'Js/HtmlParser.dart';
import 'Js/HttpClient.dart';
import 'Js/Libs.dart';
import 'Js/Polyfills.dart';
import 'Js/Storage.dart';
import 'Models/NovelModels.dart';
import 'Models/Source.dart';

/// Runs a single LNReader plugin (`source.sourceCode`) in its own QuickJS
/// runtime and maps its output onto the bridge's [SourceMethods] surface.
///
/// LNReader is novel-only: [getPageList] / [getVideoList] are stubs and chapter
/// bodies come back from [getNovelContent] as an HTML string.
class LnReaderSourceMethods extends SourceMethods {
  @override
  final LSource source;

  LnReaderSourceMethods(this.source) {
    _live.add(this);
  }

  /// Every live instance, so [LnReaderExtensions.dispose] can free the runtimes.
  static final Set<LnReaderSourceMethods> _live = {};

  static void disposeAll() {
    for (final m in _live.toList()) {
      m.dispose();
    }
  }

  JavascriptRuntime? _runtime;
  Completer<void>? _initCompleter;

  Future<void> _ensureInit() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;

    final completer = _initCompleter = Completer<void>();
    _doInit().then(completer.complete).catchError((Object e, StackTrace s) {
      _initCompleter = null;
      completer.completeError(e, s);
    });
    return completer.future;
  }

  Future<void> _doInit() async {
    var code = source.sourceCode ?? '';
    if (code.isEmpty && (source.sourceCodeUrl?.isNotEmpty ?? false)) {
      final res = await MClient.init().get(Uri.parse(source.sourceCodeUrl!));
      if (res.statusCode != 200) {
        throw Exception(
          'Failed to fetch plugin from ${source.sourceCodeUrl}: '
          '${res.statusCode}',
        );
      }
      code = res.body;
    }
    if (code.isEmpty) {
      throw Exception('No plugin code available for ${source.name}');
    }

    final runtime = QuickJsRuntime2(stackSize: 1024 * 1024 * 4);
    runtime.enableHandlePromises();

    runtime.evaluate('''
module={},exports=Function("return this")(),Object.defineProperties(module,{namespace:{set:function(a){exports=a}},exports:{set:function(a){for(var b in a)a.hasOwnProperty(b)&&(exports[b]=a[b])},get:function(){return exports}}});
''');

    JsPolyfills(runtime).init();
    JsHttpClient(runtime).init();
    JsLibs(runtime).init();
    JsHtmlParser(runtime).init();
    JsCheerio(runtime).init();
    JsStorage(runtime, sourceId: source.id ?? source.name ?? 'lnreader').init();

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
        return {storage: storage, localStorage: localStorage, sessionStorage: sessionStorage};
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
$code
var pluginInstance = module.exports.default || module.exports || exports.default || exports;
if (typeof pluginInstance === 'function') {
  try {
    pluginInstance = new pluginInstance();
  } catch (e) {}
}
globalThis.extension = pluginInstance;
var extension = pluginInstance;
''');

    _runtime = runtime;
  }

  // --- raw plugin calls -----------------------------------------------------

  Future<dynamic> _callAsync(String expr) async {
    await _ensureInit();
    final promised = await _runtime!.handlePromise(
      await _runtime!.evaluateAsync('jsonStringify(() => extension.$expr)'),
    );
    return jsonDecode(promised.stringResult);
  }

  T _call<T>(String expr, T fallback) {
    if (_runtime == null) return fallback;
    try {
      final res = _runtime!.evaluate('JSON.stringify(extension.$expr)');
      return jsonDecode(res.stringResult) as T;
    } catch (_) {
      return fallback;
    }
  }

  // --- SourceMethods ------------------------------------------------------

  List<DMedia> _toMediaList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => NovelItem.fromJson(Map<String, dynamic>.from(e)))
        .map((n) => DMedia(title: n.name, url: n.path, cover: n.cover))
        .toList();
  }

  Future<Pages> _popular(int page, {required bool latest}) async {
    final raw = await _callAsync(
      'popularNovels($page, {showLatestNovels: $latest, '
      'filters: extension.filters})',
    );
    final list = _toMediaList(raw);
    return Pages(list: list, hasNextPage: list.isNotEmpty);
  }

  @override
  Future<Pages> getPopular(int page) => _popular(page, latest: false);

  @override
  Future<Pages> getLatestUpdates(int page) => _popular(page, latest: true);

  @override
  Future<Pages> search(String query, int page, List<dynamic> filters) async {
    try {
      final raw = await _callAsync('searchNovels(${jsonEncode(query)}, $page)');
      final list = _toMediaList(raw);
      return Pages(list: list, hasNextPage: list.isNotEmpty);
    } catch (e) {
      Logger.log('LNReader searchNovels failed: $e, falling back to popularNovels');
      try {
        final raw = await _callAsync(
          'popularNovels($page, {showLatestNovels: false, '
          'filters: extension.filters})',
        );
        final list = _toMediaList(raw);
        final filtered = list
            .where((m) =>
                m.title?.toLowerCase().contains(query.toLowerCase()) ?? false)
            .toList();
        return Pages(list: filtered, hasNextPage: list.isNotEmpty);
      } catch (e2) {
        Logger.log('LNReader popularNovels fallback failed: $e2');
        return Pages(list: [], hasNextPage: false);
      }
    }
  }

  @override
  Future<DMedia> getDetail(DMedia media) async {
    final novel = SourceNovel.fromJson(
      Map<String, dynamic>.from(
        await _callAsync('parseNovel(${jsonEncode(media.url)})'),
      ),
    );

    var chapters = novel.chapters ?? const <ChapterItem>[];

    // Paginated chapter lists: the real LNReader app loops parsePage(path, page)
    // for page = 1 .. totalPages. Our SourceNovel now exposes totalPages.
    final int totalPages = novel.totalPages.clamp(1, 200);
    if (totalPages > 1 || chapters.isEmpty) {
      final allChapters = <ChapterItem>[...chapters];
      final seenPaths = <String>{
        for (final c in chapters) c.path,
      };
      for (int page = 1; page <= totalPages; page++) {
        if (page == 1 && chapters.isNotEmpty) continue;
        try {
          final pageRaw = await _callAsync(
            'parsePage(${jsonEncode(novel.path)}, "$page")',
          );
          final pageChapters = SourcePage.fromJson(
            Map<String, dynamic>.from(pageRaw),
          ).chapters;
          for (final c in pageChapters) {
            if (seenPaths.add(c.path)) {
              allChapters.add(c);
            }
          }
          if (pageChapters.isEmpty) break;
        } catch (e) {
          Logger.log('LNReader parsePage($page) failed: $e');
          if (page == 1 && allChapters.isEmpty) break;
        }
      }
      chapters = allChapters;
    }

    final episodes = <DEpisode>[];
    for (final c in chapters) {
      String epNum = '';
      if (c.chapterNumber != null) {
        final n = c.chapterNumber!;
        epNum = n == n.roundToDouble()
            ? n.toInt().toString()
            : n.toStringAsFixed(2);
      }
      episodes.add(
        DEpisode(
          name: c.name,
          url: c.path,
          episodeNumber: epNum,
          dateUpload: _releaseToMillis(c.releaseTime),
          scanlator: c.scanlator,
        ),
      );
    }

    return DMedia(
      title: novel.name.isNotEmpty ? novel.name : media.title,
      url: novel.path,
      cover: novel.cover ?? media.cover,
      description: novel.summary,
      author: novel.author,
      artist: novel.artist,
      genre: novel.genres
          ?.split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      episodes: episodes.reversed.toList(),
    );
  }

  static String _releaseToMillis(String? release) {
    if (release == null || release.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
    return DateTime.tryParse(release)?.millisecondsSinceEpoch.toString() ??
        int.tryParse(release)?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Future<String?> getNovelContent(DEpisode episode) async {
    try {
      await _ensureInit();
      final res = await _runtime!.handlePromise(
        await _runtime!.evaluateAsync(
          'jsonStringify(() => extension.parseChapter('
          '${jsonEncode(episode.url ?? '')}))',
        ),
      );
      final decoded = jsonDecode(res.stringResult);
      return decoded is String ? decoded : decoded?.toString();
    } catch (e) {
      Logger.log('LNReader parseChapter failed: $e');
      return null;
    }
  }

  @override
  Future<List<PageUrl>> getPageList(DEpisode episode) async => const [];

  @override
  Future<List<Video>> getVideoList(DEpisode episode) async => const [];

  @override
  Future<List<SourcePreference>> getPreference() async {
    await _ensureInit();
    final raw = _call<dynamic>('pluginSettings', null);
    if (raw is! Map) return const [];

    final prefs = <SourcePreference>[];
    raw.forEach((key, value) {
      if (value is! Map) return;
      final label = value['label']?.toString() ?? key.toString();
      final type = value['type']?.toString() ?? 'Text';
      final current = value['value'];

      switch (type) {
        case 'Switch':
          prefs.add(
            SourcePreference(
              key: key.toString(),
              type: 'switch',
              switchPreferenceCompat: SwitchPreferenceCompat(
                title: label,
                value: current == true,
              ),
            ),
          );
          break;
        case 'Select':
          final options = (value['options'] as List?) ?? const [];
          prefs.add(
            SourcePreference(
              key: key.toString(),
              type: 'list',
              listPreference: ListPreference(
                title: label,
                value: current?.toString(),
                entries: options
                    .map((o) => (o as Map)['label']?.toString() ?? '')
                    .toList(),
                entryValues: options
                    .map((o) => (o as Map)['value']?.toString() ?? '')
                    .toList(),
              ),
            ),
          );
          break;
        default:
          prefs.add(
            SourcePreference(
              key: key.toString(),
              type: 'text',
              editTextPreference: EditTextPreference(
                title: label,
                value: current?.toString(),
              ),
            ),
          );
      }
    });
    return prefs;
  }

  @override
  Future<bool> setPreference(SourcePreference pref, dynamic value) async {
    final key = pref.key;
    if (key == null) return false;
    try {
      await _ensureInit();
      _runtime!.evaluate(
        'storage.set(${jsonEncode(key)}, ${jsonEncode(value)})',
      );
      return true;
    } catch (e) {
      Logger.log('LNReader setPreference failed: $e');
      return false;
    }
  }

  void dispose() {
    _live.remove(this);
    try {
      _runtime?.dispose();
    } catch (_) {}
    _runtime = null;
    _initCompleter = null;
  }
}
