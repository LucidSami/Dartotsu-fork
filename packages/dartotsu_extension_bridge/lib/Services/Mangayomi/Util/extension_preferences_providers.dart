import 'dart:convert';

import '../../../Settings/KvStore.dart';
import '../Eval/dart/model/source_preference.dart';
import '../Models/Source.dart';
import 'get_source_preference.dart';
import 'string_extensions.dart';

List<SourcePreference> _loadPrefs(String sourceId) {
  final encoded = getVal<List<String>>("sourcePrefs_$sourceId");

  if (encoded == null || encoded.isEmpty) return [];

  final list = <SourcePreference>[];

  for (final e in encoded) {
    try {
      list.add(SourcePreference.fromJson(jsonDecode(e)));
    } catch (_) {}
  }

  return list;
}

void _savePrefs(String sourceId, List<SourcePreference> prefs) {
  setVal(
    "sourcePrefs_$sourceId",
    prefs.map((e) => jsonEncode(e.toJson())).toList(growable: false),
  );
}

void setPreferenceSetting(SourcePreference sourcePreference, MSource source) {
  var id = extractSourceId(source.id!).toString();
  final prefs = _loadPrefs(id);

  final index = prefs.indexWhere((e) => e.key == sourcePreference.key);

  if (index >= 0) {
    prefs[index] = sourcePreference;
  } else {
    prefs.add(sourcePreference);
  }

  _savePrefs(id, prefs);
}

dynamic getUserPreferenceValue(String sourceId, String key) {
  try {
    final id = extractSourceId(sourceId).toString();
    final prefs = _loadPrefs(id);
    final pref = prefs.where((e) => e.key == key).firstOrNull;
    if (pref == null) return null;

    if (pref.listPreference != null) {
      final p = pref.listPreference!;
      final idx = p.valueIndex;
      if (idx != null && p.entryValues != null && idx >= 0 && idx < p.entryValues!.length) {
        return p.entryValues![idx];
      }
      return null;
    } else if (pref.checkBoxPreference != null) {
      return pref.checkBoxPreference!.value;
    } else if (pref.switchPreferenceCompat != null) {
      return pref.switchPreferenceCompat!.value;
    } else if (pref.editTextPreference != null) {
      return pref.editTextPreference!.value;
    } else if (pref.multiSelectListPreference != null) {
      return pref.multiSelectListPreference!.values;
    }
    return null;
  } catch (_) {
    return null;
  }
}

dynamic getPreferenceValue(String sourceId, String key) {
  try {
    final pref = getSourcePreferenceEntry(key, sourceId);
    if (pref == null) return null;

    if (pref.listPreference != null) {
      final p = pref.listPreference!;
      final idx = p.valueIndex;
      if (idx != null && p.entryValues != null && idx >= 0 && idx < p.entryValues!.length) {
        return p.entryValues![idx];
      }
      return null;
    } else if (pref.checkBoxPreference != null) {
      return pref.checkBoxPreference!.value;
    } else if (pref.switchPreferenceCompat != null) {
      return pref.switchPreferenceCompat!.value;
    } else if (pref.editTextPreference != null) {
      return pref.editTextPreference!.value;
    } else if (pref.multiSelectListPreference != null) {
      return pref.multiSelectListPreference!.values;
    }

    return null;
  } catch (_) {
    return null;
  }
}

SourcePreference? getSourcePreferenceEntry(String key, String sourceId) {
  var id = extractSourceId(sourceId).toString();
  final prefs = _loadPrefs(id);

  final pref = prefs.where((e) => e.key == key).firstOrNull;

  if (pref != null) return pref;

  try {
    final source = getInstalledSource(sourceId);
    final defaultPref = getSourcePreference(source: source)
        .where((e) => e.key == key)
        .firstOrNull;
    if (defaultPref != null) {
      setPreferenceSetting(defaultPref, source);
      return defaultPref;
    }
  } catch (_) {}

  return null;
}

String getSourcePreferenceStringValue(
  String sourceId,
  String key,
  String defaultValue,
) {
  final kvKey = "sourcePrefString_${sourceId}_$key";

  final value = getVal<String>(kvKey);

  if (value == null) {
    setSourcePreferenceStringValue(sourceId, key, defaultValue);
    return defaultValue;
  }

  return value;
}

void setSourcePreferenceStringValue(String sourceId, String key, String value) {
  final kvKey = "sourcePrefString_${sourceId}_$key";
  setVal(kvKey, value);
}

int extractSourceId(String id) {
  final index = id.indexOf('@');
  if (index == -1) return id.toNullInt() ?? 0;
  return id.substring(0, index).toNullInt() ?? 0;
}

MSource getInstalledSource(String sourceId) {
  final anime = getVal<List<String>>('mangayomi-Installed-anime') ?? [];
  final manga = getVal<List<String>>('mangayomi-Installed-manga') ?? [];

  for (final list in [anime, manga]) {
    for (final e in list) {
      try {
        final source = MSource.fromJson(jsonDecode(e));
        if (source.id == sourceId) {
          return source;
        }
      } catch (_) {}
    }
  }

  throw Exception("Installed source not found: $sourceId");
}
