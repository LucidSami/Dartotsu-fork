import 'package:json_annotation/json_annotation.dart';

part 'Generated/media.g.dart';

@JsonSerializable()
class Media {
  int? id;
  String? title;
  @JsonKey(name: "main_picture")
  Picture? mainPicture;
  @JsonKey(name: "alternative_titles")
  AlternativeTitles? alternativeTitles;
  @JsonKey(name: "start_date")
  DateTime? startDate;
  @JsonKey(name: "end_date")
  DateTime? endDate;
  String? synopsis;
  double? mean;
  int? rank;
  int? popularity;
  @JsonKey(name: "num_list_users")
  int? numListUsers;
  @JsonKey(name: "num_scoring_users")
  int? numScoringUsers;
  String? nsfw;
  @JsonKey(name: "created_at")
  DateTime? createdAt;
  @JsonKey(name: "updated_at")
  DateTime? updatedAt;
  @JsonKey(name: "media_type")
  String? mediaType;
  String? status;
  List<Genre>? genres;
  List<Picture>? pictures;
  String? background;
  @JsonKey(name: "related_anime")
  List<Related>? relatedAnime;
  @JsonKey(name: "related_manga")
  List<Related>? relatedManga;
  List<Recommendation>? recommendations;
  @JsonKey(name: "my_list_status")
  MyListStatus? myListStatus;
  @JsonKey(name: "num_episodes")
  int? numEpisodes;
  @JsonKey(name: "num_chapters")
  int? numChapters;

  Media({
    this.id,
    this.title,
    this.mainPicture,
    this.alternativeTitles,
    this.startDate,
    this.endDate,
    this.synopsis,
    this.mean,
    this.rank,
    this.popularity,
    this.numListUsers,
    this.numScoringUsers,
    this.nsfw,
    this.createdAt,
    this.updatedAt,
    this.mediaType,
    this.status,
    this.genres,
    this.pictures,
    this.background,
    this.relatedAnime,
    this.relatedManga,
    this.recommendations,
    this.myListStatus,
    this.numEpisodes,
    this.numChapters,
  });

  factory Media.fromJson(Map<String, dynamic> json) => Media(
        id: (json['id'] as num?)?.toInt(),
        title: json['title'] as String?,
        mainPicture: json['main_picture'] == null
            ? null
            : Picture.fromJson(json['main_picture'] as Map<String, dynamic>),
        alternativeTitles: json['alternative_titles'] == null
            ? null
            : AlternativeTitles.fromJson(
                json['alternative_titles'] as Map<String, dynamic>),
        startDate: safeParseDate(json['start_date']),
        endDate: safeParseDate(json['end_date']),
        synopsis: json['synopsis'] as String?,
        mean: (json['mean'] as num?)?.toDouble(),
        rank: (json['rank'] as num?)?.toInt(),
        popularity: (json['popularity'] as num?)?.toInt(),
        numListUsers: (json['num_list_users'] as num?)?.toInt(),
        numScoringUsers: (json['num_scoring_users'] as num?)?.toInt(),
        nsfw: json['nsfw'] as String?,
        createdAt: safeParseDate(json['created_at']),
        updatedAt: safeParseDate(json['updated_at']),
        mediaType: json['media_type'] as String?,
        status: json['status'] as String?,
        genres: (json['genres'] as List<dynamic>?)
            ?.map((e) => Genre.fromJson(e as Map<String, dynamic>))
            .toList(),
        pictures: (json['pictures'] as List<dynamic>?)
            ?.map((e) => Picture.fromJson(e as Map<String, dynamic>))
            .toList(),
        background: json['background'] as String?,
        relatedAnime: (json['related_anime'] as List<dynamic>?)
            ?.map((e) => Related.fromJson(e as Map<String, dynamic>))
            .toList(),
        relatedManga: (json['related_manga'] as List<dynamic>?)
            ?.map((e) => Related.fromJson(e as Map<String, dynamic>))
            .toList(),
        recommendations: (json['recommendations'] as List<dynamic>?)
            ?.map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
            .toList(),
        myListStatus: json['my_list_status'] == null
            ? null
            : MyListStatus.fromJson(
                json['my_list_status'] as Map<String, dynamic>),
        numEpisodes: (json['num_episodes'] as num?)?.toInt(),
        numChapters: (json['num_chapters'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => _$MediaToJson(this);
}

DateTime? safeParseDate(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  if (val is! String || val.isEmpty) return null;
  final str = val.trim();
  if (str.startsWith("0000")) return null;
  if (str.length == 4) return DateTime.tryParse('$str-01-01');
  if (str.length == 7) return DateTime.tryParse('$str-01');
  return DateTime.tryParse(str);
}

@JsonSerializable()
class MyListStatus {
  @JsonKey(name: "status")
  String? status;
  @JsonKey(name: "score")
  int? score;
  @JsonKey(name: "num_episodes_watched")
  int? numEpisodesWatched;
  @JsonKey(name: "num_chapters_read")
  int? numChaptersRead;
  @JsonKey(name: "is_rewatching")
  bool? isRewatching;
  @JsonKey(name: "updated_at")
  DateTime? updatedAt;
  @JsonKey(name: "start_date")
  DateTime? startDate;
  @JsonKey(name: "finish_date")
  DateTime? finishDate;
  @JsonKey(name: "comments")
  String? comments;
  @JsonKey(name: "num_times_rewatched")
  int? numTimesRewatched;
  @JsonKey(name: "num_times_reread")
  int? numTimesReread;

  MyListStatus({
    this.status,
    this.score,
    this.numEpisodesWatched,
    this.numChaptersRead,
    this.isRewatching,
    this.updatedAt,
    this.startDate,
    this.finishDate,
    this.comments,
    this.numTimesRewatched,
    this.numTimesReread,
  });

  factory MyListStatus.fromJson(Map<String, dynamic> json) => MyListStatus(
        status: json['status'] as String?,
        score: (json['score'] as num?)?.toInt(),
        numEpisodesWatched: (json['num_episodes_watched'] as num?)?.toInt(),
        numChaptersRead: (json['num_chapters_read'] as num?)?.toInt(),
        isRewatching: json['is_rewatching'] as bool?,
        updatedAt: safeParseDate(json['updated_at']),
        startDate: safeParseDate(json['start_date']),
        finishDate: safeParseDate(json['finish_date']),
        comments: json['comments'] as String?,
        numTimesRewatched: (json['num_times_rewatched'] as num?)?.toInt(),
        numTimesReread: (json['num_times_reread'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => _$MyListStatusToJson(this);
}

@JsonSerializable()
class Ranking {
  @JsonKey(name: "rank")
  int? rank;

  Ranking({
    this.rank,
  });

  factory Ranking.fromJson(Map<String, dynamic> json) =>
      _$RankingFromJson(json);

  Map<String, dynamic> toJson() => _$RankingToJson(this);
}

@JsonSerializable()
class AlternativeTitles {
  @JsonKey(name: "synonyms")
  List<String>? synonyms;
  @JsonKey(name: "en")
  String? en;
  @JsonKey(name: "ja")
  String? ja;

  AlternativeTitles({
    this.synonyms,
    this.en,
    this.ja,
  });

  factory AlternativeTitles.fromJson(Map<String, dynamic> json) =>
      _$AlternativeTitlesFromJson(json);

  Map<String, dynamic> toJson() => _$AlternativeTitlesToJson(this);
}

@JsonSerializable()
class Genre {
  @JsonKey(name: "id")
  int? id;
  @JsonKey(name: "name")
  String? name;

  Genre({
    this.id,
    this.name,
  });

  factory Genre.fromJson(Map<String, dynamic> json) => _$GenreFromJson(json);

  Map<String, dynamic> toJson() => _$GenreToJson(this);
}

@JsonSerializable()
class Picture {
  @JsonKey(name: "medium")
  String? medium;
  @JsonKey(name: "large")
  String? large;

  Picture({
    this.medium,
    this.large,
  });

  factory Picture.fromJson(Map<String, dynamic> json) =>
      _$PictureFromJson(json);

  Map<String, dynamic> toJson() => _$PictureToJson(this);
}

@JsonSerializable()
class Recommendation {
  @JsonKey(name: "node")
  Media? node;
  @JsonKey(name: "num_recommendations")
  int? numRecommendations;

  Recommendation({
    this.node,
    this.numRecommendations,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      _$RecommendationFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationToJson(this);
}

@JsonSerializable()
class Related {
  @JsonKey(name: "node")
  Media? node;
  @JsonKey(name: "relation_type")
  String? relationType;
  @JsonKey(name: "relation_type_formatted")
  String? relationTypeFormatted;

  Related({
    this.node,
    this.relationType,
    this.relationTypeFormatted,
  });

  factory Related.fromJson(Map<String, dynamic> json) =>
      _$RelatedFromJson(json);

  Map<String, dynamic> toJson() => _$RelatedToJson(this);
}
