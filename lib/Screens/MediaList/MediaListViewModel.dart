import 'package:flutter/foundation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../Api/Anilist/Anilist.dart';
import '../../DataClass/Media.dart';
import '../../Services/ApiCacheManager.dart';
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
    final serviceName = service?.getName.toLowerCase() ?? 'anilist';
    final cacheKey = "${serviceName}_user_medialist_${anime ? 'anime' : 'manga'}_$userId";

    // Cache-first hydration
    if (!force && (mediaList.value == null || mediaList.value!.isEmpty)) {
      final cached = ApiCacheManager.instance.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        try {
          final decoded = MediaMapWrapper.fromJson(cached).mediaMap;
          if (decoded.isNotEmpty && decoded.values.any((list) => list.isNotEmpty)) {
            mediaList.value = decoded;
          }
        } catch (_) {}
      }
    }

    if (mediaList.value != null && mediaList.value!.isNotEmpty && !force) return;

    try {
      if (mediaList.value == null || mediaList.value!.isEmpty) {
        isLoading.value = true;
      }
      Map<String, List<Media>>? result;
      if (service?.data.query != null) {
        result = await service!.data.query!.getMediaLists(
          anime: anime,
          userId: userId,
          sortOrder: sortOrder,
          force: force,
        );
      } else if (Anilist.query != null) {
        result = await Anilist.query!.getMediaLists(
          anime: anime,
          userId: userId,
          sortOrder: sortOrder,
          force: force,
        );
      } else {
        result = {};
      }

      if (result.isNotEmpty) {
        mediaList.value = result;
        try {
          ApiCacheManager.instance.set(
            cacheKey,
            MediaMapWrapper(mediaMap: result).toJson(),
            ttl: const Duration(minutes: 30),
          );
        } catch (_) {}
      } else if (mediaList.value == null) {
        mediaList.value = {};
      }
    } catch (e) {
      debugPrint("Error loading media list: $e");
      if (mediaList.value == null) {
        mediaList.value = {};
      }
    } finally {
      isLoading.value = false;
    }
  }
}
