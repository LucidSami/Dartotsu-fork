import 'package:dartotsu/Functions/Extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Functions/Function.dart';
import '../../Theme/ThemeManager.dart';

abstract class BaseMediaScreen extends GetxController {
  var page = 1;
  var scrollToTop = false.obs;
  var loadMore = true.obs;
  var canLoadMore = true.obs;
  var running = true.obs;
  var scrollController = ScrollController();
  var initialLoad = false;

  List<Widget> mediaContent(BuildContext context);

  int get refreshID;

  bool get paging => true;

  Future<void> loadAll({bool force = false});

  Future<void>? loadNextPage() => null;
  Future<void> refreshData({bool force = false}) async {
    if (!running.value) {
      // If a previous load is in progress, wait up to 4 seconds for it to complete
      int waitMs = 0;
      while (!running.value && waitMs < 4000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitMs += 100;
      }
      if (!running.value) {
        // Force recovery if previous load was stuck
        debugPrint("BaseMediaScreen: Forcing recovery from stuck load for refreshID: $refreshID");
        running.value = true;
      }
      // If this was not a user-initiated forced refresh, previous load suffices
      if (!force) return;
    }
    running.value = false;
    try {
      await loadAll(force: force).timeout(const Duration(seconds: 30), onTimeout: () {
        debugPrint("loadAll timed out for refreshID: $refreshID");
      });
    } catch (e, s) {
      debugPrint("Error in loadAll (refreshID: $refreshID): $e\n$s");
    } finally {
      initialLoad = true;
      final live = Refresh.activity[refreshID];
      if (live != null) {
        live.value = false;
      }
      running.value = true;
    }
  }

  @override
  void onInit() {
    super.onInit();
    if (initialLoad) return;
    scrollController.addListener(scrollListener);
    final live = Refresh.getOrPut(refreshID, false);
    ever(live, (shouldRefresh) async {
      if (shouldRefresh) {
        await refreshData(force: initialLoad);
      }
    });
    live.value = true;
  }

  bool _canScroll() {
    final maxScrollExtent = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.offset;
    return currentScroll > (maxScrollExtent * 0.1);
  }

  Future<void> scrollListener() async {
    var scroll = scrollController.position;
    if (scroll.pixels >= scroll.maxScrollExtent - 50 && loadMore.value) {
      loadMore.value = false;
      if (canLoadMore.value) {
        await loadNextPage();
      } else {
        snackString('DAMN! YOU TRULY ARE JOBLESS\nYOU REACHED THE END');
      }
    }
    scrollToTop.value = _canScroll();
  }

  Widget buildScrollToTopButton(BuildContext context) {
    return Positioned(
      bottom: context.isPhone ? 72.0 + 32.bottomBar() : 64,
      left: 0,
      right: 0,
      child: Obx(
        () => scrollToTop.value
            ? Center(
                child: ThemedContainer(
                  context: context,
                  borderRadius: BorderRadius.circular(64.0),
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: () => scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              )
            : const SizedBox(),
      ),
    );
  }
}
