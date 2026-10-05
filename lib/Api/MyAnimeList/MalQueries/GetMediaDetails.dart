part of '../MalQueries.dart';

extension GetMediaDetails on MalQueries {
  static const _detailRecRelFields =
      "%7Bnode%7Bid,title,main_picture,num_episodes,num_chapters,mean,media_type,status%7D%7D";
  static const _mediaDetailFields =
      "mean,status,media_type,synopsis,genres,num_episodes,num_chapters,"
      "main_picture,alternative_titles,title_synonyms,start_date,end_date,start_season,source,rating,"
      "average_episode_duration,studios,authors,rank,popularity,my_list_status,"
      "recommendations$_detailRecRelFields,related_anime$_detailRecRelFields,related_manga$_detailRecRelFields";

  Future<Media?> _getMediaDetails(Media media) async {
    final malId = media.idMAL ?? (media.mal ? media.id : null);
    if (malId == null || malId == 0) return media;

    final isAnime = media.anime != null || media.manga == null;
    final type = isAnime ? "anime" : "manga";
    final url = "${MalStrings.endPoint}$type/$malId?fields=$_mediaDetailFields";

    try {
      final res = await executeQuery<Map<String, dynamic>>(url);
      if (res != null) {
        final malMedia = malApi.Media.fromJson(res);
        return Media.fromMal(malMedia);
      }
    } catch (e) {
      Logger.log("Error fetching MAL media details for $malId: $e");
    }
    return media;
  }
}
