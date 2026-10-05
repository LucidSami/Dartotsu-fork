import 'package:dartotsu/Adaptor/Media/MediaAdaptor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../DataClass/Media.dart';
import '../../Widgets/ScrollConfig.dart';

class MediaListTabs extends StatefulWidget {
  final Map<String, List<Media>?> data;
  final int initialIndex;
  final bool isLarge;

  const MediaListTabs(
      {super.key,
      required this.data,
      this.initialIndex = 0,
      this.isLarge = false});

  @override
  MediaListTabsState createState() => MediaListTabsState();
}

class MediaListTabsState extends State<MediaListTabs>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  void _initTabController() {
    if (widget.data.isNotEmpty) {
      _tabController?.dispose();
      final initialIndex =
          widget.initialIndex.clamp(0, widget.data.keys.length - 1);
      _tabController = TabController(
        initialIndex: initialIndex,
        length: widget.data.keys.length,
        vsync: this,
      );
    }
  }

  @override
  void didUpdateWidget(MediaListTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    var mediaListOld = oldWidget.data;
    var mediaListNew = widget.data;
    if (mediaListOld.keys.length != mediaListNew.keys.length ||
        _tabController == null) {
      _initTabController();
    }
  }

  @override
  Widget build(BuildContext context) {
    var mediaList = widget.data;
    if (mediaList.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
        ),
      );
    }
    if (_tabController == null ||
        _tabController!.length != mediaList.keys.length) {
      _initTabController();
    }
    var theme = Theme.of(context).colorScheme;
    final isLoading =
        mediaList.keys.isNotEmpty && mediaList.keys.first == 'Loading';
    return ScrollConfig(
      context,
      child: DefaultTabController(
        initialIndex: 0,
        length: mediaList.keys.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Skeletonizer(
              enabled: isLoading,
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.label,
                isScrollable: true,
                dragStartBehavior: DragStartBehavior.start,
                controller: _tabController,
                labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
                unselectedLabelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  color: theme.onSurface.withValues(alpha: 0.48),
                ),
                tabs: mediaList.keys.map((String tabTitle) {
                  return Tab(
                      text:
                          '${tabTitle.toUpperCase()} (${mediaList[tabTitle]?.length ?? 0})');
                }).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: mediaList.keys.map((String tabTitle) {
                  return CustomScrollConfig(
                    context,
                    children: [
                      MediaAdaptor(
                        mediaList: mediaList[tabTitle],
                        type: 3,
                        isLarge: widget.isLarge,
                        skeletonObjects: 32,
                        sliver: true,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}
