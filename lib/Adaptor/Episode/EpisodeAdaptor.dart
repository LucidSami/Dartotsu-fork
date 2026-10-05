import 'package:dartotsu/Functions/Function.dart';
import 'package:dartotsu/Preferences/IsarDataClasses/MediaSettings/MediaSettings.dart';
import 'package:dartotsu/Preferences/PrefManager.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:string_similarity/string_similarity.dart';

import '../../Animation/ScaleAnimation.dart';
import '../../DataClass/Media.dart';
import '../../Screens/Anime/Player/Player.dart';
import '../../Widgets/CustomBottomDialog.dart';
import 'EpisodeCompactViewHolder.dart';
import 'EpisodeGridViewHolder.dart';
import 'EpisodeListViewHolder.dart';

class EpisodeAdaptor extends StatefulWidget {
  final int type;
  final Source source;
  final List<DEpisode> episodeList;
  final Media mediaData;
  final VoidCallback? onEpisodeClick;

  const EpisodeAdaptor({
    super.key,
    required this.type,
    required this.source,
    required this.episodeList,
    required this.mediaData,
    this.onEpisodeClick,
  });

  @override
  EpisodeAdaptorState createState() => EpisodeAdaptorState();
}

class EpisodeAdaptorState extends State<EpisodeAdaptor> {
  late List<DEpisode> episodeList;

  @override
  void initState() {
    super.initState();
    episodeList = widget.episodeList;
  }

  @override
  void didUpdateWidget(EpisodeAdaptor oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      episodeList = widget.episodeList;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case 0:
        return _buildListLayout();
      case 1:
        return _buildGridLayout();
      case 2:
        return _buildCompactView();
      default:
        return _buildListLayout();
    }
  }

  Widget _buildListLayout() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        constraints: const BoxConstraints(maxHeight: double.infinity),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: episodeList.length,
          itemBuilder: (context, index) {
            return SlideAndScaleAnimation(
              initialScale: 0.0,
              finalScale: 1.0,
              initialOffset: const Offset(1.0, 0.0),
              finalOffset: Offset.zero,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () => onEpisodeClick(
                  context,
                  episodeList[index],
                  widget.source,
                  widget.mediaData,
                  widget.onEpisodeClick,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: EpisodeListView(
                    episode: episodeList[index],
                    mediaData: widget.mediaData,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = constraints.maxWidth;
        var crossAxisCount = (parentWidth / 180).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: StaggeredGrid.count(
              crossAxisCount: crossAxisCount,
              children: List.generate(
                episodeList.length,
                (index) {
                  return SlideAndScaleAnimation(
                    initialScale: 0.0,
                    finalScale: 1.0,
                    initialOffset: const Offset(1.0, 0.0),
                    finalOffset: Offset.zero,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: () => onEpisodeClick(
                        context,
                        episodeList[index],
                        widget.source,
                        widget.mediaData,
                        widget.onEpisodeClick,
                      ),
                      onLongPress: () {},
                      child: SizedBox(
                        width: 180,
                        height: 120,
                        child: EpisodeCardView(
                          episode: episodeList[index],
                          mediaData: widget.mediaData,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth = constraints.maxWidth;
        var crossAxisCount = (parentWidth / 82).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: StaggeredGrid.count(
              crossAxisCount: crossAxisCount,
              children: List.generate(
                episodeList.length,
                (index) {
                  return SlideAndScaleAnimation(
                    initialScale: 0.0,
                    finalScale: 1.0,
                    initialOffset: const Offset(1.0, 0.0),
                    finalOffset: Offset.zero,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: () => onEpisodeClick(
                        context,
                        episodeList[index],
                        widget.source,
                        widget.mediaData,
                        widget.onEpisodeClick,
                      ),
                      onLongPress: () {},
                      child: SizedBox(
                        width: 82,
                        height: 82,
                        child: EpisodeCompactView(
                          episode: episodeList[index],
                          mediaData: widget.mediaData,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

final Map<String, List<Video>> _videoCache = {};

Future<List<Video>> getCombinedVideoList(Source source, DEpisode episode) async {
  if (episode.servers != null && episode.servers!.isNotEmpty) {
    return episode.servers!;
  }
  final cacheKey = "${source.id ?? source.name}-${episode.url ?? episode.episodeNumber}";
  if (_videoCache.containsKey(cacheKey) && _videoCache[cacheKey]!.isNotEmpty) {
    episode.servers = _videoCache[cacheKey];
    return _videoCache[cacheKey]!;
  }

  final combinedVideos = <Video>[];
  final seen = <String>{};

  void addVideos(List<Video> list) {
    for (final v in list) {
      if (v.url.trim().isEmpty) continue;
      final key = "${v.url}|${v.title ?? v.quality}";
      if (!seen.contains(key)) {
        seen.add(key);
        combinedVideos.add(v);
      }
    }
  }

  // Primary episode fetch with generous 60s timeout for JS scrapers and crypto decoders
  try {
    final primaryResults = await source.methods.getVideoList(episode).timeout(
      const Duration(seconds: 60),
      onTimeout: () => <Video>[],
    );
    addVideos(primaryResults);
  } catch (e) {
    debugPrint("Error fetching videos for episode ${episode.episodeNumber}: $e");
  }

  // Fetch siblings sequentially so QuickJS / bridge is never hammered concurrently
  final siblings = episode.siblings;
  if (siblings != null && siblings.isNotEmpty) {
    for (final sib in siblings) {
      try {
        final sibResults = await source.methods.getVideoList(sib).timeout(
          const Duration(seconds: 30),
          onTimeout: () => <Video>[],
        );
        addVideos(sibResults);
      } catch (e) {
        debugPrint("Error fetching sibling videos for episode ${sib.episodeNumber}: $e");
      }
    }
  }

  if (combinedVideos.isNotEmpty) {
    _videoCache[cacheKey] = combinedVideos;
    episode.servers = combinedVideos;
  }

  return combinedVideos;
}

void onEpisodeClick(
  BuildContext context,
  DEpisode episode,
  Source source,
  Media mediaData,
  VoidCallback? onTapCallback, {
  List<Video>? servers,
}) async {
  if (mediaData.nameRomaji == "Local files") {
    onTapCallback?.call();
    navigateToPage(
      context,
      MediaPlayer(
        media: mediaData,
        index: 0,
        videos: [Video(episode.name, episode.url!, "Media")],
        currentEpisode: episode,
        source: source,
      ),
    );
    return;
  }
  servers ??= episode.servers;
  final lastSourceKey = "${mediaData.id}-${source.name}-lastSource";
  final autoKey = "${mediaData.id}-${source.name}-autoSource";

  final autoSourceMatch =
      AutoSourceMatch.fromJson(loadData(PrefName.autoSourceMatch));

  String? lastSelectedSource = loadCustomData(lastSourceKey);
  bool autoSelect = loadCustomData(autoKey, defaultValue: false)!;

  if (servers != null && servers.isNotEmpty) {
    if (!autoSelect || lastSelectedSource == null) {
      openSourceSelectionSheet(
        context,
        episode,
        source,
        mediaData,
        onTapCallback,
      );
      return;
    }
    final index = findBestSourceIndex(
      servers,
      lastSelectedSource,
      autoSourceMatch,
    );

    if (index == null) {
      saveCustomData(lastSourceKey, null);
      openSourceSelectionSheet(
        context,
        episode,
        source,
        mediaData,
        onTapCallback,
      );
      return;
    }

    onTapCallback?.call();
    navigateToPage(
      context,
      MediaPlayer(
        media: mediaData,
        index: index,
        videos: servers,
        currentEpisode: episode,
        source: source,
      ),
    );
    return;
  }

  if (!autoSelect) {
    openSourceSelectionSheet(
        context, episode, source, mediaData, onTapCallback);
    return;
  }

  if (lastSelectedSource == null) {
    openSourceSelectionSheet(
        context, episode, source, mediaData, onTapCallback);
    return;
  }

  showAutoSelectingDialog(context, mediaData, autoKey, lastSourceKey);

  final videos = await getCombinedVideoList(source, episode);

  if (!context.mounted) return;

  if (!loadCustomData(autoKey, defaultValue: false)!) {
    return;
  }

  final index =
      findBestSourceIndex(videos, lastSelectedSource, autoSourceMatch);

  Navigator.pop(context);

  if (index == null) {
    saveCustomData(lastSourceKey, null);
    openSourceSelectionSheet(
        context, episode, source, mediaData, onTapCallback);
    return;
  }

  onTapCallback?.call();
  navigateToPage(
    context,
    MediaPlayer(
      media: mediaData,
      index: index,
      videos: videos,
      currentEpisode: episode,
      source: source,
    ),
  );
}

void showAutoSelectingDialog(
  BuildContext context,
  Media mediaData,
  String autoKey,
  String lastSourceKey,
) {
  final dialog = CustomBottomDialog(
    viewList: [
      Row(
        children: [
          const SizedBox(width: 16),
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 16),
          const Text(
            "Auto selecting...",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              saveCustomData(autoKey, false);
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
        ],
      ),
    ],
  );
  showCustomBottomDialog(context, dialog);
}

int? findBestSourceIndex(
  List<Video> videos,
  String lastSource,
  AutoSourceMatch autoSourceMatch,
) {
  if (autoSourceMatch == AutoSourceMatch.Exact) {
    final index = videos.indexWhere(
      (v) => (v.title ?? v.quality) == lastSource,
    );
    return index == -1 ? null : index;
  }

  var bestScore = 0.0;
  var bestIndex = -1;

  for (var i = 0; i < videos.length; i++) {
    final title = videos[i].title ?? videos[i].quality;
    final score = lastSource.similarityTo(title);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  return bestIndex >= 0 ? bestIndex : null;
}


void openSourceSelectionSheet(
  BuildContext context,
  DEpisode episode,
  Source source,
  Media mediaData,
  VoidCallback? onTapCallback,
) {
  final autoKey = "${mediaData.id}-${source.name}-autoSource";
  final lastSourceKey = "${mediaData.id}-${source.name}-lastSource";

  bool autoSelect = loadCustomData(autoKey, defaultValue: false)!;
  final videoFuture = getCombinedVideoList(source, episode);

  final dialog = CustomBottomDialog(
    title: "Select Source",
    viewList: [
      StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Checkbox(
                value: autoSelect,
                onChanged: (checked) {
                  autoSelect = checked ?? false;
                  saveCustomData(autoKey, autoSelect);
                  if (!autoSelect) {
                    saveCustomData(lastSourceKey, null);
                  }
                  setState(() {});
                },
              ),
              const Text(
                "Auto Select Source",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      FutureBuilder<List<Video>>(
        future: videoFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data?.length == 1) {
            final video = snapshot.data!.first;
            saveCustomData(
              lastSourceKey,
              video.title ?? video.quality,
            );

            Future.microtask(() {
              if (!context.mounted) return;

              Navigator.pop(context);

              onTapCallback?.call();

              navigateToPage(
                context,
                MediaPlayer(
                  media: mediaData,
                  index: 0,
                  videos: snapshot.data!,
                  currentEpisode: episode,
                  source: source,
                ),
              );
            });
            return const SizedBox.shrink();
          }

          return _buildSourceList(
            context,
            snapshot.data!,
            episode,
            source,
            mediaData,
            onTapCallback,
          );
        },
      ),
    ],
  );

  showCustomBottomDialog(context, dialog);
}

Widget _buildSourceList(
  BuildContext context,
  List<Video> videos,
  DEpisode episode,
  Source source,
  Media mediaData,
  VoidCallback? onTapCallback,
) {
  final lastSourceKey = "${mediaData.id}-${source.name}-lastSource";

  final allSubtitles = <Track>[];
  final seenLabels = <String>{};

  for (final video in videos) {
    if (video.subtitles != null && video.subtitles!.isNotEmpty) {
      for (final sub in video.subtitles!) {
        if (sub.label != null && !seenLabels.contains(sub.label)) {
          seenLabels.add(sub.label!);
          allSubtitles.add(
            Track(
              label: "${sub.label} (from external)",
              file: sub.file,
            ),
          );
        }
      }
    }
  }

  for (var video in videos) {
    if (video.subtitles == null || video.subtitles!.length <= 1) {
      video.subtitles = List.from(allSubtitles);
    }
  }

  if (videos.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              "No stream servers found for this episode.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final cacheKey =
                    "${source.id ?? source.name}-${episode.url ?? episode.episodeNumber}";
                _videoCache.remove(cacheKey);
                Navigator.pop(context);
                openSourceSelectionSheet(
                  context,
                  episode,
                  source,
                  mediaData,
                  onTapCallback,
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  return Column(
    children: List.generate(
      videos.length,
      (index) {
        final item = videos[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              saveCustomData(
                lastSourceKey,
                item.title ?? item.quality,
              );

              onTapCallback?.call();
              Navigator.pop(context);

              navigateToPage(
                context,
                MediaPlayer(
                  media: mediaData,
                  index: index,
                  videos: videos,
                  currentEpisode: episode,
                  source: source,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.title ?? item.quality,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.play_arrow,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
