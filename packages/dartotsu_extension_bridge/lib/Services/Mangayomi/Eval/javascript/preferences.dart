import 'package:flutter_qjs/flutter_qjs.dart';

import '../../Models/Source.dart';
import '../../Util/extension_preferences_providers.dart';

class JsPreferences {
  late JavascriptRuntime runtime;
  late MSource? source;
  final Map<String, dynamic> defaultPreferences = {};

  JsPreferences(this.runtime, this.source);

  void setDefaultPreferences(Map<String, dynamic> prefs) {
    defaultPreferences.addAll(prefs);
  }

  void init() {
    runtime.onMessage('get', (dynamic args) {
      final key = (args is List && args.isNotEmpty) ? args[0]?.toString() : args?.toString();
      if (key == null || key.isEmpty) return null;

      try {
        // 1. User configured preference
        final userVal = getUserPreferenceValue(source?.id ?? '', key);
        if (userVal != null) return userVal;

        // 2. Pre-extracted default preference
        if (defaultPreferences.containsKey(key)) {
          return defaultPreferences[key];
        }

        // 3. Fallback for baseUrl
        final lower = key.toLowerCase();
        if (lower.contains('url') || lower.contains('base')) {
          if (source?.baseUrl != null && source!.baseUrl!.isNotEmpty) {
            return source!.baseUrl;
          }
        }
        return null;
      } catch (_) {
        final lower = key.toLowerCase();
        if (lower.contains('url') || lower.contains('base')) {
          return source?.baseUrl;
        }
        return null;
      }
    });

    runtime.onMessage('getString', (dynamic args) {
      final key = (args is List && args.isNotEmpty) ? args[0]?.toString() : args?.toString();
      final def = (args is List && args.length > 1) ? args[1]?.toString() : '';
      if (key == null || key.isEmpty) return def ?? '';

      try {
        // 1. User configured preference
        final userVal = getSourcePreferenceStringValue(source?.id ?? '', key, '');
        if (userVal.isNotEmpty) return userVal;

        // 2. Pre-extracted default preference
        if (defaultPreferences.containsKey(key)) {
          return defaultPreferences[key]?.toString() ?? def ?? '';
        }

        // 3. If defaultValue was passed, return it
        if (def != null && def.isNotEmpty) return def;

        // 4. Fallback for baseUrl
        final lower = key.toLowerCase();
        if (lower.contains('url') || lower.contains('base')) {
          if (source?.baseUrl != null && source!.baseUrl!.isNotEmpty) {
            return source!.baseUrl;
          }
        }
        return def ?? '';
      } catch (_) {
        return def ?? '';
      }
    });

    runtime.onMessage('setString', (dynamic args) {
      try {
        final key = (args is List && args.isNotEmpty) ? args[0]?.toString() : args?.toString();
        final val = (args is List && args.length > 1) ? args[1]?.toString() : '';
        if (key != null && key.isNotEmpty && val != null && source?.id != null) {
          setSourcePreferenceStringValue(source!.id!, key, val);
        }
      } catch (_) {}
    });

    runtime.evaluate('''
class SharedPreferences {
    get(key) {
        return sendMessage(
            "get",
            JSON.stringify([key])
        );
    }
    getString(key, defaultValue) {
        return sendMessage(
            "getString",
            JSON.stringify([key, defaultValue])
        );
    }
    setString(key, defaultValue) {
        return sendMessage(
            "setString",
            JSON.stringify([key, defaultValue])
        );
    }
}
''');
  }
}
