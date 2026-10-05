part of '../AnilistQueries.dart';

Future<bool>? _anilistUserDataFuture;

extension on AnilistQueries {
  Future<bool> _getUserData() async {
    if (Anilist.isInitialized.value == true) {
      return true;
    }
    if (Anilist.token.value.isEmpty) {
      return false;
    }
    if (_anilistUserDataFuture != null) {
      return await _anilistUserDataFuture!;
    }

    _anilistUserDataFuture = _fetchUserDataInternal();
    try {
      return await _anilistUserDataFuture!;
    } finally {
      _anilistUserDataFuture = null;
    }
  }

  Future<bool> _fetchUserDataInternal() async {
    try {
      var response = (await executeQuery<ViewerResponse>(_queryUser));
      var user = response?.data?.user;
      if (user == null) return false;

      Anilist.userid = user.id;
      Anilist.username.value = user.name ?? '';
      Anilist.bg.value = user.bannerImage ?? '';
      Anilist.avatar.value = user.avatar?.medium ?? '';
      Anilist.episodesWatched = user.statistics?.anime?.episodesWatched;
      Anilist.chapterRead = user.statistics?.manga?.chaptersRead;
      Anilist.adult = user.options?.displayAdultContent ?? false;
      Anilist.unreadNotificationCount = user.unreadNotificationCount ?? 0;
      Anilist.isInitialized.value = true;

      if (user.name != null && user.name!.isNotEmpty) {
        saveData(PrefName.anilistUsername, user.name!);
      }
      if (user.avatar?.medium != null && user.avatar!.medium!.isNotEmpty) {
        saveData(PrefName.anilistAvatar, user.avatar!.medium!);
      }
      saveData(PrefName.anilistUserId, user.id);

      final options = user.options;
      if (options != null) {
        Anilist.titleLanguage = options.titleLanguage?.name;
        Anilist.staffNameLanguage = options.staffNameLanguage?.name;
        Anilist.airingNotifications = options.airingNotifications ?? false;
        Anilist.restrictMessagesToFollowing =
            options.restrictMessagesToFollowing ?? false;
        Anilist.timezone = options.timezone;
        Anilist.activityMergeTime = options.activityMergeTime;
      }
      final mediaListOptions = user.mediaListOptions;
      if (mediaListOptions != null) {
        Anilist.scoreFormat = mediaListOptions.scoreFormat;
        Anilist.rowOrder = mediaListOptions.rowOrder;
        Anilist.animeCustomLists = mediaListOptions.animeList?.customLists;
        Anilist.mangaCustomLists = mediaListOptions.mangaList?.customLists;
      }
      return true;
    } catch (e) {
      debugPrint("Error fetching Anilist user data: $e");
      return false;
    }
  }
}

String _queryUser = '''{
  Viewer {
    name 
    options {
      timezone 
      titleLanguage 
      staffNameLanguage 
      activityMergeTime 
      airingNotifications 
      displayAdultContent 
      restrictMessagesToFollowing
    } 
    avatar {
      medium
    } 
    bannerImage 
    id 
    mediaListOptions {
      scoreFormat 
      rowOrder 
      animeList {
        customLists
      } 
      mangaList {
        customLists
      }
    } 
    statistics {
      anime {
        episodesWatched
      } 
      manga {
        chaptersRead
      }
    } 
    unreadNotificationCount
  }
}''';
