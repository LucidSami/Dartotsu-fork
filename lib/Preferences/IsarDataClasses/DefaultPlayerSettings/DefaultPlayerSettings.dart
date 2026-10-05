import 'package:isar_community/isar.dart';
part 'DefaultPlayerSettings.g.dart';

//TODO => see if i broke anything

@embedded
class PlayerSettings {
  String speed;
  int resizeMode;
//  bool useCustomMpvConfig;

  // subtitlesSettings
  bool showSubtitle;
  String subtitleLanguage;
  int subtitleSize;
  int subtitleColor;
  String subtitleFont;
  int subtitleBackgroundColor;
  int subtitleOutlineColor;
  int subtitleBottomPadding;
  int skipDuration;
  int subtitleWeight;
  bool autoPlay;
  bool adjustBrightness;
  bool adjustVolume;

  PlayerSettings({
    this.speed = '1x',
    this.resizeMode = 0,
    this.subtitleLanguage = 'en',
    this.subtitleSize = 16,
    this.subtitleColor = 0xFFFFFFFF,
    this.subtitleFont = 'Poppins',
    this.subtitleBackgroundColor = 0x00000000,
    this.subtitleOutlineColor = 0xFF000000,
    this.showSubtitle = true,
    this.subtitleBottomPadding = 0,
    this.skipDuration = 85,
    this.subtitleWeight = 5,
    this.autoPlay = true,
    this.adjustBrightness = true,
    this.adjustVolume = true,
    //  this.useCustomMpvConfig = false,
  });

  factory PlayerSettings.fromJson(Map<String, dynamic> json) {
    return PlayerSettings(
      speed: json['speed'],
      resizeMode: json['resizeMode'],
      subtitleLanguage: json['subtitleLanguage'],
      subtitleSize: (json['subtitleSize'] == 32 || json['subtitleSize'] == 20 || json['subtitleSize'] == null)
          ? 16
          : json['subtitleSize'],
      subtitleColor: json['subtitleColor'] ?? 0xFFFFFFFF,
      subtitleFont: json['subtitleFont'] ?? 'Poppins',
      subtitleBackgroundColor: json['subtitleBackgroundColor'] ?? 0x00000000,
      subtitleOutlineColor: (json['subtitleOutlineColor'] == null || json['subtitleOutlineColor'] == 0)
          ? 0xFF000000
          : json['subtitleOutlineColor'],
      showSubtitle: json['showSubtitle'],
      subtitleBottomPadding: json['subtitleBottomPadding'],
      skipDuration: json['skipDuration'],
      subtitleWeight: json['subtitleWeight'],
      autoPlay: json['autoPlay'] ?? true,
      adjustBrightness: json['adjustBrightness'] ?? true,
      adjustVolume: json['adjustVolume'] ?? true,
      //  useCustomMpvConfig: json['useCustomMpvConfig'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'resizeMode': resizeMode,
      'subtitleLanguage': subtitleLanguage,
      'subtitleSize': subtitleSize,
      'subtitleColor': subtitleColor,
      'subtitleFont': subtitleFont,
      'subtitleBackgroundColor': subtitleBackgroundColor,
      'subtitleOutlineColor': subtitleOutlineColor,
      'showSubtitle': showSubtitle,
      'subtitleBottomPadding': subtitleBottomPadding,
      'skipDuration': skipDuration,
      'subtitleWeight': subtitleWeight,
      'autoPlay': autoPlay,
      'adjustBrightness': adjustBrightness,
      'adjustVolume': adjustVolume,
      //'useCustomMpvConfig': useCustomMpvConfig,
    };
  }
}
