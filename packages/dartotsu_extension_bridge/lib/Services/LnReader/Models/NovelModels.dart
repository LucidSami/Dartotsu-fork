class ChapterItem {
  String name;
  String path;
  String? releaseTime;
  double? chapterNumber;
  String? page;
  String? scanlator;

  ChapterItem({
    required this.name,
    required this.path,
    this.releaseTime,
    this.chapterNumber,
    this.page,
    this.scanlator,
  });

  factory ChapterItem.fromJson(Map<String, dynamic> json) {
    double? parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ChapterItem(
      name: json['name']?.toString() ?? json['chapterName']?.toString() ?? '',
      path: json['path']?.toString() ?? json['chapterUrl']?.toString() ?? '',
      releaseTime: json['releaseTime']?.toString() ??
          json['releaseDate']?.toString(),
      chapterNumber: parseNum(json['chapterNumber']),
      page: json['page']?.toString(),
      scanlator: json['scanlator']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'releaseTime': releaseTime,
      'chapterNumber': chapterNumber,
      'page': page,
      'scanlator': scanlator,
    };
  }
}

class NovelItem {
  String name;
  String path;
  String? cover;

  NovelItem({required this.name, required this.path, this.cover});

  factory NovelItem.fromJson(Map<String, dynamic> json) {
    return NovelItem(
      name: json['name']?.toString() ??
          json['novelName']?.toString() ??
          json['title']?.toString() ??
          '',
      path: json['path']?.toString() ??
          json['novelUrl']?.toString() ??
          json['url']?.toString() ??
          json['link']?.toString() ??
          '',
      cover: json['cover']?.toString() ??
          json['novelCover']?.toString() ??
          json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'path': path, 'cover': cover};
  }
}

class SourceNovel extends NovelItem {
  String? genres;
  String? summary;
  String? author;
  String? artist;
  String? status;
  double? rating;
  int totalPages;
  List<ChapterItem>? chapters;

  SourceNovel({
    required super.name,
    required super.path,
    super.cover,
    this.genres,
    this.summary,
    this.author,
    this.artist,
    this.status,
    this.rating,
    this.totalPages = 1,
    this.chapters,
  });

  factory SourceNovel.fromJson(Map<String, dynamic> json) {
    final parsedPath = json['path']?.toString() ??
        json['novelUrl']?.toString() ??
        json['url']?.toString() ??
        json['link']?.toString() ??
        '';
    int pages = 1;
    final rawPages = json['totalPages'];
    if (rawPages is num && rawPages > 0) {
      pages = rawPages.toInt();
    } else if (rawPages is String) {
      pages = int.tryParse(rawPages) ?? 1;
    }
    return SourceNovel(
      name: json['name']?.toString() ??
          json['novelName']?.toString() ??
          json['title']?.toString() ??
          '',
      path: parsedPath,
      cover: json['cover']?.toString() ??
          json['novelCover']?.toString() ??
          json['image']?.toString(),
      genres: json['genres']?.toString(),
      summary: json['summary']?.toString(),
      author: json['author']?.toString(),
      artist: json['artist']?.toString(),
      status: json['status']?.toString(),
      rating: json['rating'] is double
          ? json['rating']
          : (json['rating'] is num ? json['rating'].toDouble() : null),
      totalPages: pages,
      chapters: (json['chapters'] as List<dynamic>?)
          ?.whereType<Map>()
          .map((item) => ChapterItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'cover': cover,
      'genres': genres,
      'summary': summary,
      'author': author,
      'artist': artist,
      'status': status,
      'rating': rating,
      'totalPages': totalPages,
      'chapters': chapters?.map((item) => item.toJson()).toList(),
    };
  }
}

class SourcePage {
  List<ChapterItem> chapters;

  SourcePage({required this.chapters});

  factory SourcePage.fromJson(Map<String, dynamic> json) {
    return SourcePage(
      chapters:
          (json['chapters'] as List<dynamic>?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    ChapterItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'chapters': chapters.map((item) => item.toJson()).toList()};
  }
}
