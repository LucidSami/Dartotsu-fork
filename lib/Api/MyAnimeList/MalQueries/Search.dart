part of '../MalQueries.dart';

extension MalSearch on MalQueries {
  static const _searchField =
      "fields=mean,num_list_users,status,nsfw,mean,my_list_status,num_episodes,num_chapters,genres,media_type,start_date,end_date,synopsis";

  Future<SearchResults?> _search(SearchResults? searchResults) async {
    if (searchResults == null) return null;

    final isAnime = searchResults.type == SearchType.ANIME;
    final typeStr = isAnime ? "anime" : "manga";
    final page = searchResults.page ?? 1;
    final limit = searchResults.perPage ?? 25;
    final offset = (page - 1) * limit;

    final hasGenres =
        searchResults.genres != null && searchResults.genres!.isNotEmpty;
    final fetchLimit = hasGenres ? (limit < 50 ? 50 : limit) : limit;

    String url;
    final query = searchResults.search?.trim();

    if (query != null && query.isNotEmpty) {
      final encodedQuery = Uri.encodeComponent(query);
      url =
          "${MalStrings.endPoint}$typeStr?q=$encodedQuery&limit=$fetchLimit&offset=$offset&$_searchField";
    } else {
      String rankingType = "all";
      if (searchResults.sort != null) {
        final s = searchResults.sort!.toLowerCase();
        if (s.contains("popular") || s.contains("popularity")) {
          rankingType = "bypopularity";
        } else if (s.contains("favorite") || s.contains("fav")) {
          rankingType = "favorite";
        } else if (s.contains("score")) {
          rankingType = "all";
        }
      } else if (searchResults.format != null) {
        final f = searchResults.format!.toLowerCase();
        if (['tv', 'movie', 'ova', 'special', 'airing', 'upcoming'].contains(f)) {
          rankingType = f;
        } else if (['manga', 'novels', 'oneshots', 'doujin', 'manhwa', 'manhua'].contains(f)) {
          rankingType = f;
        }
      } else if (searchResults.status != null) {
        final st = searchResults.status!.toLowerCase();
        if (st.contains("releasing") || st.contains("airing")) {
          rankingType = "airing";
        } else if (st.contains("not_yet") || st.contains("upcoming")) {
          rankingType = "upcoming";
        }
      } else if (hasGenres) {
        // Default to popular ranking when browsing by genre without text query
        rankingType = "bypopularity";
      }

      url =
          "${MalStrings.endPoint}$typeStr/ranking?ranking_type=$rankingType&limit=$fetchLimit&offset=$offset&$_searchField";
    }

    try {
      final res = await executeQuery<MediaResponse>(url);
      List<Media> mediaList = await processMediaResponse(res);

      if (hasGenres) {
        final targetGenres = searchResults.genres!
            .map((g) => g.toLowerCase().trim())
            .toSet();
        mediaList = mediaList.where((m) {
          if (m.genres.isEmpty) return false;
          final itemGenres =
              m.genres.map((g) => g.toLowerCase().trim()).toSet();
          return targetGenres.every((tg) => itemGenres.contains(tg));
        }).toList();
      }

      if (searchResults.onList == true) {
        mediaList = mediaList
            .where((m) => m.userStatus != null && m.userStatus!.isNotEmpty)
            .toList();
      }

      searchResults.results = mediaList;
      searchResults.hasNextPage =
          (res?.data?.length ?? 0) >= fetchLimit;
      return searchResults;
    } catch (e) {
      Logger.log("Error during MAL search: $e");
      searchResults.results = [];
      searchResults.hasNextPage = false;
      return searchResults;
    }
  }
}
