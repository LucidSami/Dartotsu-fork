part of '../AnilistQueries.dart';

extension on AnilistQueries {
  Future<Media?> _getMedia(int id, {bool mal = false}) async {
    final res = await executeQuery<MediaResponse>(_queryMediaData(id, mal: mal),
        force: true);
    final media = res?.data?.media;
    if (media == null) return null;
    return Media.mediaData(media);
  }
}

String _queryMediaData(int id, {bool mal = false}) => '''{
  Media(${mal ? 'idMal' : 'id'}: $id) {
    id 
    idMal 
    status 
    chapters 
    episodes 
    nextAiringEpisode {
      episode
    }
    type 
    meanScore 
    isAdult 
    isFavourite 
    format 
    bannerImage 
    coverImage {
      large
    }
    title {
      english 
      romaji 
      userPreferred
    }
    mediaListEntry {
      id
      status
      score(format: POINT_100)
      progress
      repeat
      private
      notes
      startedAt {
        year
        month
        day
      }
      completedAt {
        year
        month
        day
      }
    }
  }
}''';
