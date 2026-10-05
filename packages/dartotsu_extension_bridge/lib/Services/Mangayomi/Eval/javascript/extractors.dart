import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';

import '../../../../Logger.dart';
import '../dart/model/m_bridge.dart';
import '../dart/model/video.dart';
import 'http.dart';

String? _toHeadersJson(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    if (raw.isEmpty || raw == 'null' || raw == 'undefined') return null;
    return raw;
  }
  if (raw is Map) {
    return jsonEncode(raw.toMapStringString);
  }
  return null;
}

class JsVideosExtractors {
  late JavascriptRuntime runtime;
  JsVideosExtractors(this.runtime);

  void init() {
    runtime.onMessage('sibnetExtractor', (dynamic args) async {
      try {
        return (await MBridge.sibnetExtractor(
          args[0],
          args[1] ?? "",
        )).encodeToJson();
      } catch (e) {
        Logger.log('sibnetExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('myTvExtractor', (dynamic args) async {
      try {
        return (await MBridge.myTvExtractor(args[0])).encodeToJson();
      } catch (e) {
        Logger.log('myTvExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('okruExtractor', (dynamic args) async {
      try {
        return (await MBridge.okruExtractor(args[0])).encodeToJson();
      } catch (e) {
        Logger.log('okruExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('voeExtractor', (dynamic args) async {
      try {
        return (await MBridge.voeExtractor(args[0], args[1])).encodeToJson();
      } catch (e) {
        Logger.log('voeExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('vidBomExtractor', (dynamic args) async {
      try {
        return (await MBridge.vidBomExtractor(args[0])).encodeToJson();
      } catch (e) {
        Logger.log('vidBomExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('quarkVideosExtractor', (dynamic args) async {
      try {
        return (await MBridge.quarkVideosExtractor(
          args[0],
          args[1],
        )).encodeToJson();
      } catch (e) {
        Logger.log('quarkVideosExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('ucVideosExtractor', (dynamic args) async {
      try {
        return (await MBridge.ucVideosExtractor(args[0], args[1])).encodeToJson();
      } catch (e) {
        Logger.log('ucVideosExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('quarkFilesExtractor', (dynamic args) async {
      try {
        List<String> urls = (args[0] as List).cast<String>();
        return (await MBridge.quarkFilesExtractor(urls, args[1]));
      } catch (e) {
        Logger.log('quarkFilesExtractor error: $e');
        return [];
      }
    });
    runtime.onMessage('ucFilesExtractor', (dynamic args) async {
      try {
        List<String> urls = (args[0] as List).cast<String>();
        return (await MBridge.ucFilesExtractor(urls, args[1]));
      } catch (e) {
        Logger.log('ucFilesExtractor error: $e');
        return [];
      }
    });
    runtime.onMessage('streamlareExtractor', (dynamic args) async {
      try {
        return (await MBridge.streamlareExtractor(
          args[0],
          args[1] ?? "",
          args[2] ?? "",
        )).encodeToJson();
      } catch (e) {
        Logger.log('streamlareExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('sendVidExtractor', (dynamic args) async {
      try {
        final headers = _toHeadersJson(args[1]);
        return (await MBridge.sendVidExtractor(
          args[0],
          headers,
          args[2] ?? "",
        )).encodeToJson();
      } catch (e) {
        Logger.log('sendVidExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('yourUploadExtractor', (dynamic args) async {
      try {
        final headers = _toHeadersJson(args[1]);
        return (await MBridge.yourUploadExtractor(
          args[0],
          headers,
          args[2],
          args[3] ?? "",
        )).encodeToJson();
      } catch (e) {
        Logger.log('yourUploadExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('gogoCdnExtractor', (dynamic args) async {
      try {
        return (await MBridge.gogoCdnExtractor(args[0])).encodeToJson();
      } catch (e) {
        Logger.log('gogoCdnExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('doodExtractor', (dynamic args) async {
      try {
        return (await MBridge.doodExtractor(args[0], args[1])).encodeToJson();
      } catch (e) {
        Logger.log('doodExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('streamTapeExtractor', (dynamic args) async {
      try {
        return (await MBridge.streamTapeExtractor(
          args[0],
          args[1],
        )).encodeToJson();
      } catch (e) {
        Logger.log('streamTapeExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('mp4UploadExtractor', (dynamic args) async {
      try {
        final headers = _toHeadersJson(args[1]);
        return (await MBridge.mp4UploadExtractor(
          args[0],
          headers,
          args[2] ?? "",
          args[3] ?? "",
        )).encodeToJson();
      } catch (e) {
        Logger.log('mp4UploadExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('streamWishExtractor', (dynamic args) async {
      try {
        return (await MBridge.streamWishExtractor(
          args[0],
          args[1] ?? "",
        )).encodeToJson();
      } catch (e) {
        Logger.log('streamWishExtractor error: $e');
        return jsonEncode([]);
      }
    });
    runtime.onMessage('filemoonExtractor', (dynamic args) async {
      try {
        return (await MBridge.filemoonExtractor(
          args[0],
          args[1] ?? "",
          args[2] ?? "",
        )).encodeToJson();
      } catch (e) {
        Logger.log('filemoonExtractor error: $e');
        return jsonEncode([]);
      }
    });

    runtime.evaluate('''
async function sibnetExtractor(url, prefix) {
    const result = await sendMessage(
        "sibnetExtractor",
        JSON.stringify([url, prefix])
    );
    return JSON.parse(result);
}
async function myTvExtractor(url) {
    const result = await sendMessage(
        "myTvExtractor",
        JSON.stringify([url])
    );
    return JSON.parse(result);
}
async function okruExtractor(url) {
    const result = await sendMessage(
        "okruExtractor",
        JSON.stringify([url])
    );
    return JSON.parse(result);
}
async function voeExtractor(url, quality) {
    const result = await sendMessage(
        "voeExtractor",
        JSON.stringify([url, quality])
    );
    return JSON.parse(result);
}
async function vidBomExtractor(url) {
    const result = await sendMessage(
        "vidBomExtractor",
        JSON.stringify([url])
    );
    return JSON.parse(result);
}
async function streamlareExtractor(url, prefix, suffix) {
    const result = await sendMessage(
        "streamlareExtractor",
        JSON.stringify([url, prefix, suffix])
    );
    return JSON.parse(result);
}
async function sendVidExtractor(url, headers, prefix) {
    const result = await sendMessage(
        "sendVidExtractor",
        JSON.stringify([url, JSON.stringify(headers), prefix])
    );
    return JSON.parse(result);
}
async function yourUploadExtractor(url, headers, name, prefix) {
    const result = await sendMessage(
        "yourUploadExtractor",
        JSON.stringify([url, JSON.stringify(headers), name, prefix])
    );
    return JSON.parse(result);
}
async function gogoCdnExtractor(url) {
    const result = await sendMessage(
        "gogoCdnExtractor",
        JSON.stringify([url])
    );
    return JSON.parse(result);
}
async function doodExtractor(url, quality) {
    const result = await sendMessage(
        "doodExtractor",
        JSON.stringify([url, quality])
    );
    return JSON.parse(result);
}
async function streamTapeExtractor(url, quality) {
    const result = await sendMessage(
        "streamTapeExtractor",
        JSON.stringify([url, quality])
    );
    return JSON.parse(result);
}
async function mp4UploadExtractor(url, headers, prefix, suffix) {
    const result = await sendMessage(
        "mp4UploadExtractor",
        JSON.stringify([url, JSON.stringify(headers), prefix, suffix])
    );
    return JSON.parse(result);
}
async function streamWishExtractor(url, prefix) {
    const result = await sendMessage(
        "streamWishExtractor",
        JSON.stringify([url, prefix])
    );
    return JSON.parse(result);
}
async function filemoonExtractor(url, prefix, suffix) {
    const result = await sendMessage(
        "filemoonExtractor",
        JSON.stringify([url, prefix, suffix])
    );
    return JSON.parse(result);
}
async function quarkVideosExtractor(url, cookie) {
    const result = await sendMessage(
        "quarkVideosExtractor",
        JSON.stringify([url, cookie])
    );
    return JSON.parse(result);
}
async function ucVideosExtractor(url, cookie) {
    const result = await sendMessage(
        "ucVideosExtractor",
        JSON.stringify([url, cookie])
    );
    return JSON.parse(result);
}
async function quarkFilesExtractor(urls, cookie) {
    const result = await sendMessage(
        "quarkFilesExtractor",
        JSON.stringify([urls, cookie])
    );
    return result;
}
async function ucFilesExtractor(urls, cookie) {
    const result = await sendMessage(
        "ucFilesExtractor",
        JSON.stringify([urls, cookie])
    );
    return result;
}
''');
  }
}

extension ResponseExtexsion on List<Video> {
  String encodeToJson() {
    return jsonEncode(map((e) => e.toJson()).toList());
  }
}
