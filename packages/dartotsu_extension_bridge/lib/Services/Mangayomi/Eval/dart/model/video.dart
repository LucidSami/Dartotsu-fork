import '../../javascript/http.dart';

class Video {
  String url;
  String quality;
  String originalUrl;
  Map<String, String>? headers;
  List<Track>? subtitles;
  List<Track>? audios;

  Video(
    this.url,
    this.quality,
    this.originalUrl, {
    this.headers,
    this.subtitles,
    this.audios,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? json['videoUrl'] ?? json['file'] ?? json['link'])?.toString().trim() ?? '';
    final rawQuality = (json['quality'] != null && json['quality'].toString().trim().isNotEmpty)
        ? json['quality'].toString().trim()
        : 'Default';
    final rawOriginalUrl = (json['originalUrl'] != null && json['originalUrl'].toString().trim().isNotEmpty)
        ? json['originalUrl'].toString().trim()
        : rawUrl;
    return Video(
      rawUrl,
      rawQuality,
      rawOriginalUrl,
      headers: (json['headers'] as Map?)?.toMapStringString,
      subtitles: _parseTracks(json['subtitles']),
      audios: _parseTracks(json['audios']),
    );
  }

  static List<Track> _parseTracks(dynamic value) {
    if (value is! List) return [];
    final tracks = <Track>[];
    for (final e in value) {
      if (e == null) continue;
      try {
        if (e is Map) {
          tracks.add(Track.fromJson(Map<String, dynamic>.from(e)));
        }
      } catch (_) {}
    }
    return tracks;
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'quality': quality,
    'originalUrl': originalUrl,
    'headers': headers,
    'subtitles': subtitles?.map((e) => e.toJson()).toList(),
    'audios': audios?.map((e) => e.toJson()).toList(),
  };
}

class Track {
  String? file;
  String? label;

  Track({this.file, this.label});

  Track.fromJson(Map<String, dynamic> json) {
    file = (json['file'] ?? json['url'])?.toString().trim();
    label = (json['label'] ?? json['lang'] ?? json['language'])?.toString().trim();
  }

  Map<String, dynamic> toJson() => {'file': file, 'label': label};
}
