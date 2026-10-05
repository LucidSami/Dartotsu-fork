import 'package:flutter/foundation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../Api/Anilist/Anilist.dart';
import '../../DataClass/Media.dart';
import '../../Services/MediaService.dart';

class MediaListViewModel extends GetxController {
  var mediaList = Rxn<Map<String, List<Media>>>();
  var isLoading = false.obs;

  Future<void> loadAll({
    required bool anime,
    required int userId,
    String? sortOrder,
    MediaService? service,
    bool force = false,
  }) async {
    try {
      if (mediaList.value != null && !force) return;
      isLoading.value = true;
      if (service?.data.query != null) {
        mediaList.value = await service!.data.query!
            .getMediaLists(anime: anime, userId: userId, sortOrder: sortOrder);
      } else if (Anilist.query != null) {
        mediaList.value = await Anilist.query!
            .getMediaLists(anime: anime, userId: userId, sortOrder: sortOrder);
      } else {
        mediaList.value = {};
      }
    } catch (e) {
      debugPrint("Error loading media list: $e");
      mediaList.value = {};
    } finally {
      isLoading.value = false;
    }
  }
}
