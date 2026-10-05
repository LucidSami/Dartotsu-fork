import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dartotsu/Preferences/IsarDataClasses/DefaultPlayerSettings/DefaultPlayerSettings.dart';
import 'package:dartotsu/Preferences/PrefManager.dart';
import '../MpvConfig.dart';
import '../VideoCacheManager.dart';
import 'package:dartotsu_extension_bridge/AddonManager.dart';
import 'package:dartotsu_extension_bridge/Engines/TorrentEngine/LibTorrentAddon.dart';
import 'package:dartotsu_extension_bridge/Models/Video.dart' as v;
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MPVDecoder {
  final String id;
  final String name;
  final String androidDecoder;
  final String iosDecoder;
  //maybe split in to Linux, MacOS and Windows later?
  final String desktopDecoder;

  MPVDecoder({
    required this.id,
    required this.name,
    required this.androidDecoder,
    required this.iosDecoder,
    required this.desktopDecoder,
  });

  String getDecoderForPlatform() {
    if (Platform.isAndroid) {
      return androidDecoder;
    } else if (Platform.isIOS) {
      return iosDecoder;
    } else {
      return desktopDecoder;
    }
  }
}

class MediaKitPlayer extends GetxController {
  Rx<BoxFit> resizeMode;
  PlayerSettings settings;

  late Player player;
  late VideoController videoController;

  Rx<Duration> currentTime = Duration.zero.obs;
  Rx<Duration> maxTime = Duration.zero.obs;
  Rx<Duration> bufferingTime = Duration.zero.obs;
  RxBool isBuffering = true.obs;
  RxBool isPlaying = false.obs;
  RxBool isCompleted = false.obs;
  RxList<SubtitleTrack> subtitles = <SubtitleTrack>[].obs;
  RxList<AudioTrack> audios = <AudioTrack>[].obs;
  RxList<String> subtitle = <String>[].obs;
  RxList<Chapter> chapters = <Chapter>[].obs;
  Rx<double> currentSpeed = 1.0.obs;
  Rx<String?> currentSubtitleLanguage = Rx<String?>(null);
  Rx<String?> currentSubtitleUri = Rx<String?>(null);
  late final List<MPVDecoder>? supportedDecoders;
  Rx<MPVDecoder?> currentDecoder = Rx<MPVDecoder?>(null);

  VideoControllerConfiguration getPlatformConfig() {
    return const VideoControllerConfiguration();
  }

  MediaKitPlayer(this.resizeMode, this.settings) {
    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.v,
        bufferSize: 1024 * 1024 * 256,
      ),
    );

    videoController = VideoController(
      player,
      configuration: getPlatformConfig(),
    );

    if (player.platform is NativePlayer) {
      _configureNativePlayerCaching();
      final auto = MPVDecoder(
        id: "auto",
        name: "Auto",
        androidDecoder: "auto",
        iosDecoder: "auto",
        desktopDecoder: "auto",
      );
      final autoSafe = MPVDecoder(
        id: "auto-safe",
        name: "Auto Safe",
        androidDecoder: "auto-safe",
        iosDecoder: "auto-safe",
        desktopDecoder: "auto-safe",
      );
      final sw = MPVDecoder(
        id: "sw",
        name: "Software",
        androidDecoder: "no",
        iosDecoder: "no",
        desktopDecoder: "no",
      );
      final hw = MPVDecoder(
        id: "hw",
        name: "Hardware",
        androidDecoder: "mediacodec-copy",
        iosDecoder: "videotoolbox-copy",
        desktopDecoder: "auto-copy",
      );
      final hwPlus = MPVDecoder(
        id: "hw-plus",
        name: "Hardware Plus",
        androidDecoder: "mediacodec",
        iosDecoder: "videotoolbox",
        desktopDecoder: "auto",
      );

      supportedDecoders = [autoSafe, auto, sw, hw, hwPlus];
      // Saikou fork: auto-safe hardware decoder with copy prevents blank screen in Flutter texture
      useDecoder(Platform.isAndroid ? autoSafe : auto);
    }
  }

  Future<void> _configureNativePlayerCaching() async {
    if (player.platform is NativePlayer) {
      try {
        final cacheDir = await VideoCacheManager().getCacheDirPath();
        await _setNativeProperty("profile", "fast");
        await _setNativeProperty("video-sync", "audio");
        await _setNativeProperty("initial-audio-sync", "yes");
        await _setNativeProperty("demuxer-thread", "yes");
        await _setNativeProperty("demuxer-readahead-secs", "36000"); // 10 hours readahead - aggressive preloading
        await _setNativeProperty("cache", "yes");
        await _setNativeProperty("cache-pause", "yes");
        await _setNativeProperty("cache-pause-initial", "yes");
        await _setNativeProperty("cache-pause-wait", "3");
        await _setNativeProperty("network-timeout", "10");
        await _setNativeProperty("stream-lavf-o", "reconnect=1,reconnect_streamed=1,reconnect_delay_max=5");
        await _setNativeProperty("cache-dir", cacheDir);
        await _setNativeProperty("demuxer-max-bytes", "268435456"); // 256 MB buffer in memory
        await _setNativeProperty("demuxer-max-back-bytes", "134217728"); // 128 MB seek-back buffer
        await _setNativeProperty("framedrop", "vo");
        await _setNativeProperty("vd-lavc-framedrop", "nonkey");

        // Apply custom MPV config if enabled in player settings
        await _applyCustomMpvConfig();
      } catch (e) {
        debugPrint("Error configuring native player caching: $e");
      }
    }
  }

  Future<void> _applyCustomMpvConfig() async {
    if (player.platform is! NativePlayer) return;
    try {
      final useCustom = loadData(PrefName.useCustomMpvConfig);
      if (!useCustom) return;

      final configPath = await MpvConf.getMpvConfigPath();
      final configFile = File(configPath);
      if (!await configFile.exists()) return;

      final lines = await configFile.readAsLines();
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        final idx = line.indexOf('=');
        String key;
        String val;
        if (idx != -1) {
          key = line.substring(0, idx).trim();
          val = line.substring(idx + 1).trim();
        } else {
          key = line.trim();
          val = "yes";
        }

        // Filter out properties that break Flutter texture on Android
        final lowerKey = key.toLowerCase();
        if (lowerKey == 'vo' || lowerKey == 'hwdec' || lowerKey == 'gpu-context') {
          debugPrint("Skipping unsafe custom mpv config key: $key");
          continue;
        }

        try {
          await _setNativeProperty(key, val);
          debugPrint("Applied custom mpv config: $key=$val");
        } catch (err) {
          debugPrint("Failed to set mpv property $key=$val: $err");
        }
      }
    } catch (e) {
      debugPrint("Error applying custom mpv config: $e");
    }
  }

  Future<void> pause() => videoController.player.pause();

  Future<void> play() => videoController.player.play();

  Future<void> playOrPause() => videoController.player.playOrPause();

  Future<void> seek(Duration duration) => videoController.player.seek(duration);

  Future<void> setRate(double rate) => videoController.player.setRate(rate);

  Future<void> setVolume(double volume) =>
      videoController.player.setVolume(volume);

  Future<void> open(v.Video video, Duration duration) async {
    var url = video.url;

    if (_isTorrent(url)) {
      final addon = Get.find<AddonManager>().get<LibtorrentAddon>();
      final fileIndex = int.tryParse(video.headers?['fileId'] ?? video.headers?['file_index'] ?? '');

      final stream = await addon.startStream(url: url, fileIndex: fileIndex);

      url = stream;
    } else if (_isTorrServerStream(url)) {
      try {
        final addon = Get.find<AddonManager>().get<LibtorrentAddon>();
        await addon.ensureStarted();
      } catch (_) {}
    } else {
      try {
        final addon = Get.find<AddonManager>().get<LibtorrentAddon>();
        addon.stop();
      } catch (_) {}
    }

    await VideoCacheManager().clearCache();
    await _configureNativePlayerCaching();
    await videoController.player.open(
      Media(url, start: duration, httpHeaders: video.headers),
    );
  }

  bool _isTorrent(String url) {
    final lower = url.toLowerCase();

    return lower.startsWith("magnet:") ||
        lower.endsWith(".torrent") ||
        lower.contains(".torrent?");
  }

  bool _isTorrServerStream(String url) {
    return url.contains(':8090/stream') ||
        url.contains(':41001/stream') ||
        url.contains('/stream/torrent');
  }

  Future<void> setSubtitle(String subtitleUri, String language, bool isUri) =>
      videoController.player.setSubtitleTrack(
        isUri
            ? SubtitleTrack.uri(subtitleUri, title: language)
            : SubtitleTrack(
                subtitleUri,
                language,
                language,
                uri: false,
                data: false,
              ),
      );

  Future<void> resetSubtitle() =>
      videoController.player.setSubtitleTrack(SubtitleTrack.no());

  Future<void> setAudio(String audioUri, String language, bool isUri) =>
      videoController.player.setAudioTrack(
        isUri
            ? AudioTrack.uri(audioUri, title: language)
            : AudioTrack(audioUri, language, language, uri: false),
      );

  @override
  void dispose() {
    super.dispose();
    player.dispose();
    try {
      final addon = Get.find<AddonManager>().get<LibtorrentAddon>();
      addon.stop();
    } catch (_) {}
    VideoCacheManager().clearCache();
  }

  void listenToPlayerStream() {
    videoController.player.stream.position.listen(currentTime.call);
    videoController.player.stream.duration.listen(maxTime.call);
    videoController.player.stream.buffer.listen(bufferingTime.call);
    videoController.player.stream.completed.listen(isCompleted.call);
    videoController.player.stream.playing.listen(isPlaying.call);
    videoController.player.stream.subtitle.listen(subtitle.call);
    videoController.player.stream.rate.listen(currentSpeed.call);

    videoController.player.stream.tracks.listen((e) {
      subtitles.value = e.subtitle;
      audios.value = e.audio;

      final currentTrack = videoController.player.state.track.subtitle;
      if (currentTrack == SubtitleTrack.auto() || currentTrack == SubtitleTrack.no()) {
        final validTracks = e.subtitle.where(
          (t) => t != SubtitleTrack.auto() && t != SubtitleTrack.no(),
        );
        bool isEng(SubtitleTrack t) {
          final title = (t.title ?? '').toLowerCase();
          final lang = (t.language ?? '').toLowerCase();
          return title.contains('english') ||
              title.contains('eng') ||
              lang.contains('english') ||
              lang.contains('eng') ||
              lang == 'en';
        }

        final preferredTrack = validTracks.firstWhereOrNull(
              (t) => isEng(t) && !((t.title ?? '').toLowerCase().contains('sign')),
            ) ??
            validTracks.firstWhereOrNull((t) => isEng(t));
        if (preferredTrack != null) {
          videoController.player.setSubtitleTrack(preferredTrack);
        }
      }

      _updateSubtitleTrack(videoController.player.state.track.subtitle);
    });
    videoController.player.stream.track.listen((e) {
      _updateSubtitleTrack(e.subtitle);
    });

    if (videoController.player.platform is NativePlayer) {
      observeNativePropertyBool("paused-for-cache", (value) async {
        isBuffering.value = value;
      });
      observeNativePropertyDouble("demuxer-cache-time", (v) async {
        if (v < 1.0) isBuffering.value = true;
      });

      observeNativePropertyInt("chapter-list/count", (value) async {
        final futures = List.generate(value, (i) async {
          final title = await getNativePropertyString("chapter-list/$i/title");
          final startTime = await getNativePropertyDouble(
            "chapter-list/$i/time",
          );

          return Chapter(title: title, startTime: startTime);
        });

        chapters.value = await Future.wait(futures);
      });
    }
  }

  //TODO: add some actual user interface to change decoder
  Future<void> useDecoder(MPVDecoder decoder) {
    if (supportedDecoders == null || !supportedDecoders!.contains(decoder)) {
      throw ArgumentError('Decoder ${decoder.id} is not supported');
    }

    return setNativePropertyString(
      "hwdec",
      decoder.getDecoderForPlatform(),
    ).then((_) {
      currentDecoder.value = decoder;
    });
  }

  void _updateSubtitleTrack(SubtitleTrack track) {
    if (track == SubtitleTrack.no()) {
      currentSubtitleLanguage.value = null;
      currentSubtitleUri.value = null;
    } else if (track == SubtitleTrack.auto()) {
      final validTracks = subtitles.where(
        (element) =>
            element != SubtitleTrack.auto() &&
            element != SubtitleTrack.no(),
      );
      bool isEng(SubtitleTrack t) {
        final title = (t.title ?? '').toLowerCase();
        final lang = (t.language ?? '').toLowerCase();
        return title.contains('english') ||
            title.contains('eng') ||
            lang.contains('english') ||
            lang.contains('eng') ||
            lang == 'en';
      }

      final preferred = validTracks.firstWhereOrNull(
            (t) => isEng(t) && !((t.title ?? '').toLowerCase().contains('sign')),
          ) ??
          validTracks.firstWhereOrNull((t) => isEng(t)) ??
          validTracks.firstOrNull;

      currentSubtitleLanguage.value = preferred?.title ?? preferred?.language;
      currentSubtitleUri.value = preferred?.id;
    } else {
      currentSubtitleLanguage.value = track.title;
      currentSubtitleUri.value = track.id;
    }
  }

  Widget playerWidget() {
    return Video(
      filterQuality: FilterQuality.medium,
      subtitleViewConfiguration: const SubtitleViewConfiguration(
        visible: false,
      ),
      controller: videoController,
      controls: null,
      fit: resizeMode.value,
    );
  }

  Future<String> _getNativeProperty(String property) {
    assert(videoController.player.platform is NativePlayer);

    return (videoController.player.platform as NativePlayer).getProperty(
      property,
    );
  }

  Future<void> _setNativeProperty(String property, String value) {
    assert(videoController.player.platform is NativePlayer);

    return (videoController.player.platform as NativePlayer).setProperty(
      property,
      value,
    );
  }

  Future<void> _observeNativeProperty(
    String property,
    Future<void> Function(String) listener, {
    bool waitForInitialization = true,
  }) {
    assert(videoController.player.platform is NativePlayer);

    return (videoController.player.platform as NativePlayer).observeProperty(
      property,
      listener,
      waitForInitialization: waitForInitialization,
    );
  }

  Future<String> getNativePropertyString(String property) =>
      _getNativeProperty(property);

  Future<double> getNativePropertyDouble(String property) =>
      _getNativeProperty(property).then((value) => double.parse(value));

  Future<int> getNativePropertyInt(String property) =>
      _getNativeProperty(property).then((value) => int.parse(value));

  Future<bool> getNativePropertyBool(String property) =>
      _getNativeProperty(property).then((value) => value == 'yes');

  Future<void> setNativePropertyString(String property, String value) =>
      _setNativeProperty(property, value);

  Future<void> setNativePropertyDouble(String property, double value) =>
      _setNativeProperty(property, value.toString());

  Future<void> setNativePropertyInt(String property, int value) =>
      _setNativeProperty(property, value.toString());

  Future<void> setNativePropertyBool(String property, bool value) =>
      _setNativeProperty(property, value ? 'yes' : 'no');

  Future<void> observeNativePropertyString(
    String property,
    Future<void> Function(String) listener, {
    bool waitForInitialization = true,
  }) => _observeNativeProperty(
    property,
    listener,
    waitForInitialization: waitForInitialization,
  );

  Future<void> observeNativePropertyDouble(
    String property,
    Future<void> Function(double) listener, {
    bool waitForInitialization = true,
  }) => _observeNativeProperty(
    property,
    (value) => listener(double.parse(value)),
    waitForInitialization: waitForInitialization,
  );

  Future<void> observeNativePropertyInt(
    String property,
    Future<void> Function(int) listener, {
    bool waitForInitialization = true,
  }) => _observeNativeProperty(
    property,
    (value) => listener(int.parse(value)),
    waitForInitialization: waitForInitialization,
  );

  Future<void> observeNativePropertyBool(
    String property,
    Future<void> Function(bool) listener, {
    bool waitForInitialization = true,
  }) => _observeNativeProperty(
    property,
    (value) => listener(value == 'yes'),
    waitForInitialization: waitForInitialization,
  );

  Future<void> unobserveNativeProperty(
    String property, {
    bool waitForInitialization = true,
  }) {
    assert(videoController.player.platform is NativePlayer);

    return (videoController.player.platform as NativePlayer).unobserveProperty(
      property,
      waitForInitialization: waitForInitialization,
    );
  }

  Future<void> nativeCommand(
    List<String> command, {
    bool waitForInitialization = true,
  }) {
    assert(videoController.player.platform is NativePlayer);

    return (videoController.player.platform as NativePlayer).command(
      command,
      waitForInitialization: waitForInitialization,
    );
  }
}

class Chapter {
  final String title;
  final double startTime;

  Chapter({required this.title, required this.startTime});
}
