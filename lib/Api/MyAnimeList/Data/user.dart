import 'package:json_annotation/json_annotation.dart';

part 'Generated/user.g.dart';

@JsonSerializable()
class User {
  @JsonKey(name: "id")
  int? id;
  @JsonKey(name: "name")
  String? name;
  @JsonKey(name: "birthday")
  DateTime? birthday;
  @JsonKey(name: "location")
  String? location;
  @JsonKey(name: "joined_at")
  DateTime? joinedAt;
  @JsonKey(name: "picture")
  String? picture;
  @JsonKey(name: "anime_statistics")
  Map<String, double>? animeStatistics;
  @JsonKey(name: "manga_statistics")
  Map<String, double>? mangaStatistics;

  User({
    this.id,
    this.name,
    this.birthday,
    this.location,
    this.joinedAt,
    this.picture,
    this.animeStatistics,
    this.mangaStatistics,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    Map<String, double>? stats;
    if (json['anime_statistics'] is Map) {
      stats = {};
      (json['anime_statistics'] as Map).forEach((k, v) {
        if (v is num) {
          stats![k.toString()] = v.toDouble();
        }
      });
    }

    Map<String, double>? mangaStats;
    if (json['manga_statistics'] is Map) {
      mangaStats = {};
      (json['manga_statistics'] as Map).forEach((k, v) {
        if (v is num) {
          mangaStats![k.toString()] = v.toDouble();
        }
      });
    }

    return User(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      birthday: parseDate(json['birthday']),
      location: json['location'] as String?,
      joinedAt: parseDate(json['joined_at']),
      picture: json['picture'] as String?,
      animeStatistics: stats,
      mangaStatistics: mangaStats,
    );
  }

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
