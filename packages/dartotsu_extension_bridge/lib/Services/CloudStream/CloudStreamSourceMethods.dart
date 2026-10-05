import 'dart:async';
import 'package:flutter/services.dart';

import '../../Extensions/BridgeSourceMethods.dart';
import '../../dartotsu_extension_bridge.dart';

class CloudStreamSourceMethods<T extends Source>
    extends BridgeSourceMethods<T> {
  CloudStreamSourceMethods(super.source, super.bridge);

  static const videoStreamChannel =
      EventChannel('cloudstreamExtensionBridge/videoStream');

  @override
  Stream<List<Video>> getVideoListStream(DEpisode episode) {
    final controller = StreamController<List<Video>>();

    final subscription = videoStreamChannel.receiveBroadcastStream({
      'apiName': source.id,
      'url': episode.url,
    }).listen(
      (event) {
        try {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(event as Map);
          
          final quality = data['quality'] ?? "auto";
          final url = data['url'];
          
          if (url != null) {
            final rawSubs = data['subtitles'];
            final List<Track>? subs = (rawSubs is List && rawSubs.isNotEmpty)
                ? rawSubs.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList()
                : null;
            final rawAudios = data['audioTracks'];
            final List<Track>? audios = (rawAudios is List && rawAudios.isNotEmpty)
                ? rawAudios.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList()
                : null;
            final video = Video(
              data['title']?.toString() ?? quality,
              url,
              quality,
              headers: data['headers'] != null 
                  ? Map<String, String>.from(data['headers']) 
                  : null,
              subtitles: subs,
              audios: audios,
            );
            if (!controller.isClosed) {
              controller.add([video]);
            }
          }
        } catch (e) {}
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
      cancelOnError: false,
    );

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  @override
  Future<List<PageUrl>> getPageList(DEpisode episode) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getNovelContent(DEpisode episode) async {
    throw UnimplementedError();
  }

  @override
  Future<List<SourcePreference>> getPreference() async => const [];

  @override
  Future<bool> setPreference(SourcePreference pref, dynamic value) async =>
      false;

  Future<bool> openNativeSettings() async {
    try {
      final result = await const MethodChannel('cloudstreamExtensionBridge').invokeMethod<bool>('openSettings', {
        'pluginName': source.name ?? source.id ?? '',
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  void cancelRequest(String token) {}
}
