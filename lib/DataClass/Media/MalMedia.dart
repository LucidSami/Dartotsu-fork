part of '../Media.dart';

Media _fromMal(malApi.Media apiMedia) {
  String mapAiringStatus(String status) {
    switch (status) {
      case 'finished_airing':
        return 'FINISHED';
      case 'currently_airing':
        return 'RELEASING';
      case 'currently_publishing':
        return 'RELEASING';
      case 'not_yet_published':
        return 'NOT_YET_RELEASED';
      case 'not_yet_aired':
        return 'NOT_YET_RELEASED';
      default:
        return 'UNKNOWN';
    }
  }

  anilistApi.MediaType? getMediaType(String? mediaType) {
    anilistApi.MediaType type;
    if (['tv', 'ova', 'movie', 'special', 'ona', 'music'].contains(mediaType)) {
      type = anilistApi.MediaType.ANIME;
    } else if ([
      'unknown',
      'manga',
      'novel',
      'one_shot',
      'doujinshi',
      'manhwa',
      'manhua',
      'oel'
    ].contains(mediaType)) {
      type = anilistApi.MediaType.MANGA;
    } else {
      type = anilistApi.MediaType.ANIME;
    }
    return type;
  }

  int? nextAiringEpisode;
  int? airingAtTimestamp;
  int? timeUntilAiring;

  final now = DateTime.now();
  final rawStatus = apiMedia.status ?? '';

  if (rawStatus == 'currently_airing') {
    if (apiMedia.startDate != null) {
      final diff = now.difference(apiMedia.startDate!);
      if (diff.isNegative) {
        nextAiringEpisode = 0;
        final remainingSec = apiMedia.startDate!.difference(now).inSeconds;
        if (remainingSec > 0) {
          airingAtTimestamp = apiMedia.startDate!.millisecondsSinceEpoch ~/ 1000;
          timeUntilAiring = remainingSec * 1000;
        }
      } else {
        final days = diff.inDays;
        int released = (days ~/ 7) + 1;
        if (apiMedia.numEpisodes != null &&
            apiMedia.numEpisodes! > 0 &&
            released > apiMedia.numEpisodes!) {
          released = apiMedia.numEpisodes!;
        }
        nextAiringEpisode = released;

        if (apiMedia.numEpisodes == null ||
            apiMedia.numEpisodes! == 0 ||
            released < apiMedia.numEpisodes!) {
          final nextEpDate = apiMedia.startDate!.add(Duration(days: released * 7));
          final nextSec = nextEpDate.difference(now).inSeconds;
          if (nextSec > 0) {
            airingAtTimestamp = nextEpDate.millisecondsSinceEpoch ~/ 1000;
            timeUntilAiring = nextSec * 1000;
          }
        }
      }
    } else {
      nextAiringEpisode = 1;
    }
  } else if (rawStatus == 'not_yet_aired') {
    nextAiringEpisode = 0;
    if (apiMedia.startDate != null) {
      final remainingSec = apiMedia.startDate!.difference(now).inSeconds;
      if (remainingSec > 0) {
        airingAtTimestamp = apiMedia.startDate!.millisecondsSinceEpoch ~/ 1000;
        timeUntilAiring = remainingSec * 1000;
      }
    }
  }

  return Media(
    id: apiMedia.id!,
    idMAL: apiMedia.id,
    mal: true,
    malScore: apiMedia.mean?.toDouble(),
    name: apiMedia.title ?? '',
    nameRomaji: apiMedia.alternativeTitles?.ja ?? apiMedia.title ?? '',
    userPreferredName: apiMedia.title ?? '',
    cover: apiMedia.mainPicture?.medium ?? '',
    banner: apiMedia.mainPicture?.large ?? apiMedia.mainPicture?.medium ?? '',
    status: mapAiringStatus(apiMedia.status ?? ''),
    isAdult: apiMedia.nsfw == 'black',
    userStatus: apiMedia.myListStatus?.status,
    userProgress: apiMedia.myListStatus?.numEpisodesWatched ??
        apiMedia.myListStatus?.numChaptersRead,
    userScore: ((apiMedia.myListStatus?.score ?? 0) * 10).toInt(),
    notes: apiMedia.myListStatus?.comments,
    userRepeat: apiMedia.myListStatus?.numTimesRewatched ??
        apiMedia.myListStatus?.numTimesReread ??
        0,
    userStartedAt: apiMedia.myListStatus?.startDate != null
        ? FuzzyDate(
            year: apiMedia.myListStatus!.startDate!.year,
            month: apiMedia.myListStatus!.startDate!.month,
            day: apiMedia.myListStatus!.startDate!.day,
          )
        : null,
    userCompletedAt: apiMedia.myListStatus?.finishDate != null
        ? FuzzyDate(
            year: apiMedia.myListStatus!.finishDate!.year,
            month: apiMedia.myListStatus!.finishDate!.month,
            day: apiMedia.myListStatus!.finishDate!.day,
          )
        : null,
    meanScore: ((apiMedia.mean ?? 0) * 10).toInt(),
    genres: apiMedia.genres?.map((genre) => genre.name ?? '').toList() ?? [],
    format: apiMedia.mediaType,
    timeUntilAiring: timeUntilAiring,
    airingAtTimestamp: airingAtTimestamp,
    anime: getMediaType(apiMedia.mediaType) == anilistApi.MediaType.ANIME
        ? Anime(
            totalEpisodes:
                apiMedia.numEpisodes != 0 ? apiMedia.numEpisodes : null,
            nextAiringEpisode: nextAiringEpisode,
          )
        : null,
    manga: getMediaType(apiMedia.mediaType) == anilistApi.MediaType.MANGA
        ? Manga(
            totalChapters:
                apiMedia.numChapters != 0 ? apiMedia.numChapters : null,
          )
        : null,
    description: apiMedia.synopsis,
    popularity: apiMedia.popularity,
    startDate: apiMedia.startDate != null
        ? FuzzyDate(
            year: apiMedia.startDate!.year,
            month: apiMedia.startDate!.month,
            day: apiMedia.startDate!.day,
          )
        : null,
    endDate: apiMedia.endDate != null
        ? FuzzyDate(
            year: apiMedia.endDate!.year,
            month: apiMedia.endDate!.month,
            day: apiMedia.endDate!.day,
          )
        : null,
    recommendations: apiMedia.recommendations
        ?.where((r) => r.node != null)
        .map((r) => Media.fromMal(r.node!))
        .toList(),
    relations: [
      ...?apiMedia.relatedAnime
          ?.where((r) => r.node != null)
          .map((r) => Media.fromMal(r.node!)),
      ...?apiMedia.relatedManga
          ?.where((r) => r.node != null)
          .map((r) => Media.fromMal(r.node!)),
    ],
  );
}
