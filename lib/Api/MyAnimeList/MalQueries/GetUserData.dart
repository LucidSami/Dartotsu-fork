part of '../MalQueries.dart';

Future<bool>? _malUserDataFuture;

extension on MalQueries {
  Future<bool> _getUserData({bool force = false}) async {
    if (!force &&
        Mal.isInitialized.value == true &&
        Mal.username.value.isNotEmpty) {
      return true;
    }
    if (Mal.token.value.isEmpty) {
      Mal.getSavedToken();
      if (Mal.token.value.isEmpty) {
        return false;
      }
    }
    if (_malUserDataFuture != null) {
      return await _malUserDataFuture!;
    }

    _malUserDataFuture = _fetchUserDataInternal();
    try {
      return await _malUserDataFuture!;
    } finally {
      _malUserDataFuture = null;
    }
  }

  Future<bool> _fetchUserDataInternal() async {
    try {
      var user = (await executeQuery<User>(
          '${MalStrings.endPoint}users/@me?fields=anime_statistics,manga_statistics'));
      if (user == null) return false;

      Mal.userid = user.id;
      Mal.username.value = user.name ?? '';
      Mal.bg.value = user.picture ?? '';
      Mal.avatar.value = user.picture ?? '';
      Mal.episodesWatched = user.animeStatistics?['num_episodes']?.toInt();
      Mal.chapterRead = 0;
      Mal.adult = false;
      Mal.unreadNotificationCount = 0;
      Mal.isInitialized.value = true;

      // Persist profile to preferences so it is available immediately
      if (user.name != null && user.name!.isNotEmpty) {
        saveData(PrefName.malUsername, user.name!);
      }
      if (user.picture != null && user.picture!.isNotEmpty) {
        saveData(PrefName.malAvatar, user.picture!);
      }
      if (user.id != null) {
        saveData(PrefName.malUserId, user.id!);
      }
      if (Mal.episodesWatched != null) {
        saveData(PrefName.malEpisodesWatched, Mal.episodesWatched!);
      }
      return true;
    } catch (e) {
      debugPrint("Error fetching MAL user data: $e");
      return false;
    }
  }
}
