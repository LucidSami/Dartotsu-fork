import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'Preferences/PrefManager.dart';

void logger(String message, {LogLevel logLevel = LogLevel.info, String? tag}) =>
    Logger.log(message, logLevel: logLevel, tag: tag);

class Logger {
  static Future<void> init() async {
    try {
      final directory = await PrefManager.getDirectory(
        useSystemPath: false,
        useCustomPath: true,
      );
      if (directory != null) {
        final logFile = File('${directory.path}/appLogs.txt'.fixSeparator);
        if (await logFile.exists()) {
          await logFile.delete();
        }
      }
    } catch (_) {}
  }

  static void log(
    String message, {
    LogLevel logLevel = LogLevel.info,
    String? tag,
  }) {
    if (kDebugMode) {
      debugPrint('[${tag ?? logLevel.name.toUpperCase()}] $message');
    }
  }

  static Future<void> dispose() async {}
}

enum LogLevel { debug, info, warning, error }
