import 'package:collection/collection.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';

import 'ParseChapterNumber.dart';

/// Normalises chapter lists coming from every manga / novel provider
/// (Aniyomi/Mihon, Mangayomi, Kotatsu, LNReader) so that the UI always gets:
///
///  * no duplicated chapters (dedup by url, like Mangayomi / Mihon DB),
///  * a stable oldest -> newest order that preserves the source order
///    (Mihon / Dantotsu never re-sort by number, they only flip direction),
///  * monotonic chapter numbers per scanlator, so chunking, progress and
///    next / previous navigation behave like the native apps.
class ChapterOrdering {
  ChapterOrdering._();

  /// "Chapter 12", "Ch. 12.5", "Episode 3", "Capítulo 4", "Глава 7", "第12話"…
  static final RegExp _chapterKeyword = RegExp(
    r'(?:\b(?:chapters?|chap|ch|episodes?|eps?|capitulo|capítulo|cap|chapitre|kapitel|bab|chuong|chương|hoofdstuk|rozdział|rozdzial)|глава|第)'
    r'\s*[.:#\-]?\s*([0-9]+(?:[.,][0-9]+)?)',
    caseSensitive: false,
  );

  /// Prefixes whose number is NOT the chapter number.
  static final RegExp _unwanted = RegExp(
    r'\b(?:v|ver|vol|version|volume|season|s|book|part|arc|tome|tomo|livre|band)[^a-z0-9]?[0-9]+(?:[.,][0-9]+)?',
    caseSensitive: false,
  );

  /// Parses a chapter number from the chapter [name]. Chapter keywords win
  /// over any other number in the title ("Book 17: Chapter 2" -> 2).
  static double? parseNumber(String mediaTitle, String name) {
    if (name.trim().isEmpty) return null;
    var lower = name.toLowerCase();
    final title = mediaTitle.toLowerCase().trim();
    if (title.isNotEmpty) lower = lower.replaceAll(title, ' ');

    final keyword = _chapterKeyword.firstMatch(lower);
    if (keyword != null) {
      final v = double.tryParse(keyword.group(1)!.replaceAll(',', '.'));
      if (v != null) return _clean(v);
    }

    final stripped = lower.replaceAll(_unwanted, ' ');
    final parsed = ChapterRecognition.parseChapterNumber('', stripped);
    if (parsed is num && parsed > 0) return _clean(parsed.toDouble());
    if (RegExp(r'(^|[^0-9.])0([^0-9.]|$)').hasMatch(stripped)) return 0;
    return null;
  }

  static double _clean(double v) =>
      double.parse(v.toStringAsFixed(4));

  static String format(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    var s = v.toStringAsFixed(4);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  static int? _date(DEpisode e) {
    final raw = e.dateUpload;
    if (raw == null || raw.isEmpty) return null;
    final n = int.tryParse(raw);
    if (n != null && n > 0) return n;
    return DateTime.tryParse(raw)?.millisecondsSinceEpoch;
  }

  /// asc - desc adjacent pair count, evaluated per scanlator group.
  static int _directionScore(List<DEpisode> list, List<double?> values) {
    final last = <String, double>{};
    var score = 0;
    for (var i = 0; i < list.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final key = list[i].scanlator ?? '';
      final prev = last[key];
      if (prev != null) {
        if (v > prev) score++;
        if (v < prev) score--;
      }
      last[key] = v;
    }
    return score;
  }

  /// Number of entries breaking a strictly increasing order per scanlator.
  static int _violations(List<DEpisode> list, List<double?> values) {
    final last = <String, double>{};
    var bad = 0;
    for (var i = 0; i < list.length; i++) {
      final v = values[i];
      if (v == null) {
        bad++;
        continue;
      }
      final key = list[i].scanlator ?? '';
      final prev = last[key];
      if (prev != null && v <= prev) {
        bad++;
        continue;
      }
      last[key] = v;
    }
    return bad;
  }

  /// Returns the chapters ordered oldest -> newest with sane numbering.
  static List<DEpisode> normalize(
    List<DEpisode> input, {
    String mediaTitle = '',
  }) {
    // 1. Dedup by url (official Mangayomi / Mihon behaviour).
    final seen = <String>{};
    var list = <DEpisode>[];
    for (final e in input) {
      final key = (e.url ?? '').trim();
      if (key.isNotEmpty && !seen.add(key)) continue;
      list.add(e);
    }
    if (list.isEmpty) return list;

    List<double?> providerOf(List<DEpisode> l) => l.map((e) {
          final v = double.tryParse(e.episodeNumber.trim());
          return (v == null || v < 0) ? null : v;
        }).toList();
    List<double?> parsedOf(List<DEpisode> l) =>
        l.map((e) => parseNumber(mediaTitle, e.name ?? '')).toList();

    var provider = providerOf(list);
    var parsed = parsedOf(list);

    // 2. Direction: never sort, only flip (sources are newest-first by
    //    convention, so a tie means "reverse").
    if (list.length > 1) {
      final validProvider = provider.where((v) => v != null && v > 0).length;
      final primary = validProvider >= list.length * 0.8 ? provider : parsed;
      var score = _directionScore(list, primary);
      if (score == 0) score = _directionScore(list, primary == provider ? parsed : provider);
      if (score == 0) {
        final dates = list.map((e) => _date(e)?.toDouble()).toList();
        score = _directionScore(list, dates);
      }
      if (score <= 0) {
        list = list.reversed.toList();
        provider = provider.reversed.toList();
        parsed = parsed.reversed.toList();
      }
    }

    // 3. Numbering.
    final providerBad = _violations(list, provider);
    final parsedBad = _violations(list, parsed);
    final tolerance = (list.length * 0.03).floor().clamp(0, 5);

    List<double?>? chosen;
    if (providerBad == 0) {
      chosen = provider;
    } else if (parsedBad == 0) {
      chosen = parsed;
    } else if (providerBad <= tolerance && providerBad <= parsedBad) {
      chosen = provider;
    } else if (parsedBad <= tolerance) {
      chosen = parsed;
    }

    if (chosen != null) {
      // Patch the few entries that break monotonicity (extras, specials…).
      final last = <String, double>{};
      final bump = <String, int>{};
      for (var i = 0; i < list.length; i++) {
        final key = list[i].scanlator ?? '';
        final prev = last[key];
        var v = chosen[i];
        if (v == null || (prev != null && v <= prev)) {
          final k = (bump[key] ?? 0) + 1;
          bump[key] = k;
          v = _clean((prev ?? 0) + 0.01 * k);
        } else {
          bump[key] = 0;
        }
        last[key] = v;
        list[i].episodeNumber = format(v);
      }
    } else {
      // Numbers are unusable (e.g. "Book 3: Chapter 1" restarts per book):
      // number sequentially in source order, per scanlator (Dantotsu style).
      final counters = <String, int>{};
      for (final e in list) {
        final key = e.scanlator ?? '';
        final n = (counters[key] ?? 0) + 1;
        counters[key] = n;
        e.episodeNumber = n.toString();
      }
    }
    return list;
  }

  /// Finds the neighbouring chapter in an oldest -> newest [list].
  /// [step] = 1 for next, -1 for previous. Same-number duplicates from other
  /// scanlators are skipped and the current scanlator is preferred.
  static DEpisode? adjacent(List<DEpisode> list, DEpisode current, int step) {
    if (list.isEmpty) return null;
    var index = list.indexOf(current);
    if (index < 0 && current.url != null) {
      index = list.indexWhere((e) => e.url == current.url);
    }
    final cur = double.tryParse(current.episodeNumber);

    DEpisode? byNumber() {
      if (cur == null) return null;
      final candidates = list.where((c) {
        final v = double.tryParse(c.episodeNumber);
        if (v == null) return false;
        return step > 0 ? v > cur : v < cur;
      }).toList();
      if (candidates.isEmpty) return null;
      double target = double.parse(candidates.first.episodeNumber);
      for (final c in candidates) {
        final v = double.parse(c.episodeNumber);
        if (step > 0 ? v < target : v > target) target = v;
      }
      final same = candidates
          .where((c) => double.parse(c.episodeNumber) == target)
          .toList();
      return same.firstWhereOrNull((c) => c.scanlator == current.scanlator) ??
          same.first;
    }

    if (index < 0) return byNumber();

    final currentNumber = list[index].episodeNumber;
    var i = index + step;
    while (i >= 0 &&
        i < list.length &&
        currentNumber.isNotEmpty &&
        list[i].episodeNumber == currentNumber) {
      i += step;
    }
    if (i < 0 || i >= list.length) return byNumber();

    final candNum = double.tryParse(list[i].episodeNumber);
    if (cur != null &&
        candNum != null &&
        (step > 0 ? candNum <= cur : candNum >= cur)) {
      // Scanlator groups are not interleaved; fall back to numbers.
      return byNumber() ?? list[i];
    }

    final targetNumber = list[i].episodeNumber;
    final scan = current.scanlator;
    if (scan != null && list[i].scanlator != scan && targetNumber.isNotEmpty) {
      var j = i;
      while (j >= 0 && j < list.length && list[j].episodeNumber == targetNumber) {
        if (list[j].scanlator == scan) return list[j];
        j += step;
      }
    }
    return list[i];
  }
}
