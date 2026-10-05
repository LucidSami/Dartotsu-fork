import 'Video.dart';

class DEpisode {
  String? url;
  String? name;
  String? originalName;
  String? title;
  String? dateUpload;
  String? scanlator;
  String? thumbnail;
  String? description;
  bool? filler;
  String episodeNumber;
  String? originalEpisodeNumber;
  String? memo;
  String? rating;
  List<DEpisode>? siblings;
  List<Video>? servers;

  DEpisode({
    this.url,
    this.name,
    this.originalName,
    this.title,
    this.dateUpload,
    this.scanlator,
    this.thumbnail,
    this.description,
    this.filler,
    required this.episodeNumber,
    this.originalEpisodeNumber,
    this.memo,
    this.rating,
    this.siblings,
    this.servers,
  });

  factory DEpisode.fromJson(Map<String, dynamic> json) {
    double? episodeNum =
        double.tryParse(json['episodeNumber']?.toString() ?? '') ??
        double.tryParse(json['episode_number']?.toString() ?? '');

    String episodeStr;
    if (episodeNum != null) {
      if (episodeNum == episodeNum.toInt()) {
        episodeStr = episodeNum.toInt().toString();
      } else {
        // Limit decimal places to avoid floating-point noise
        // like "0.10000000149011612" which causes issues downstream
        final raw = episodeNum.toString();
        final decimalPart = raw.contains('.') ? raw.split('.').last : '';
        episodeStr = decimalPart.length > 6
            ? episodeNum.toStringAsFixed(4)
            : raw;
      }
    } else {
      episodeStr = '';
    }
    final rawName = json['name']?.toString();
    final rawOrigName = json['original_name']?.toString() ??
        json['originalName']?.toString() ??
        rawName;

    return DEpisode(
      url: json['url']?.toString(),
      name: rawName,
      originalName: rawOrigName,
      title: json['title']?.toString(),
      dateUpload:
          json['dateUpload']?.toString() ?? json['date_upload']?.toString(),
      scanlator: json['scanlator']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      description: json['description']?.toString(),
      filler: json['filler'] as bool?,
      episodeNumber: episodeStr,
      originalEpisodeNumber: json['episode_number']?.toString() ??
          json['episodeNumber']?.toString() ??
          episodeStr,
      memo: json['memo']?.toString(),
      rating: json['rating']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'original_name': originalName ?? name,
    'title': title,
    'dateUpload': dateUpload,
    'date_upload': dateUpload,
    'scanlator': scanlator,
    'thumbnail': thumbnail,
    'description': description,
    'filler': filler,
    'episodeNumber': episodeNumber,
    'episode_number': originalEpisodeNumber ?? episodeNumber,
    'memo': memo,
    'rating': rating,
  };
}
