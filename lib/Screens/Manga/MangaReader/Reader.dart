import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartotsu/Preferences/IsarDataClasses/DefaultReaderSettings/DafaultReaderSettings.dart';
import 'package:dartotsu/Widgets/ScrollConfig.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../DataClass/Media.dart';
import '../../../Preferences/PrefManager.dart';
import '../../../Services/TrackSyncManager.dart';
import 'ReaderController.dart';

class MediaReader extends StatefulWidget {
  final Media media;
  final DEpisode currentChapter;
  final List<PageUrl> pages;
  final Source source;

  const MediaReader({
    super.key,
    required this.media,
    required this.currentChapter,
    required this.pages,
    required this.source,
  });

  @override
  State<MediaReader> createState() => MediaReaderState();
}

class MediaReaderState extends State<MediaReader> {
  late final FocusNode focusNode = FocusNode();
  late final ItemScrollController itemScrollController = ItemScrollController();
  late final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  late final PageController pageController = PageController();
  late ReaderSettings readerSettings;
  final showControls = true.obs;
  final currentPage = 1.obs;
  final transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    readerSettings = widget.media.settings.readerSettings;
    focusNode.requestFocus();
    itemPositionsListener.itemPositions.addListener(_updateCurrentPage);
    pageController.addListener(_onPageChanged);
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    var list = List<int>.from(
      loadCustomData<List<int>>("continueMangaList") ?? [],
    );
    if (list.contains(widget.media.id)) {
      list.remove(widget.media.id);
    }
    list.add(widget.media.id);
    saveCustomData<List<int>>("continueMangaList", list);
  }

  @override
  void dispose() {
    focusNode.dispose();
    itemPositionsListener.itemPositions.removeListener(_updateCurrentPage);
    pageController.removeListener(_onPageChanged);
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    updateProgress();
    super.dispose();
  }

  bool _progressUpdated = false;

  void updateProgress({bool force = false}) {
    if (_progressUpdated && !force) return;
    var currentPage = this.currentPage.value;
    var totalPages = widget.pages.length;
    var chapterEnd = totalPages > 0 && totalPages - currentPage <= 1;
    if (!chapterEnd && !force) return;

    _progressUpdated = true;
    TrackSyncManager.instance.syncProgress(
      media: widget.media,
      episodeOrChapterNumber: widget.currentChapter.episodeNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildReader(),
    );
  }

  Widget _buildReader() {
    return KeyboardListener(
      focusNode: focusNode,
      child: GestureDetector(
        onTap: () => showControls.value = !showControls.value,
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent &&
                HardwareKeyboard.instance.isControlPressed) {
              _zoomOnScroll(event.scrollDelta.dy, event.localPosition);
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onDoubleTapDown: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: transformationController,
                  minScale: 0.5,
                  maxScale: 4,
                  scaleEnabled: Platform.isAndroid || Platform.isIOS,
                  child: readerSettings.layoutType == LayoutType.Continuous
                      ? _buildContinuousMode()
                      : _buildPagedMode(),
                ),
              ),
              _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Obx(() {
      return Positioned.fill(
        child: AnimatedOpacity(
          opacity: showControls.value ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !showControls.value,
            child: ReaderController(reader: this),
          ),
        ),
      );
    });
  }

  Widget _buildContinuousMode() {
    var direction = readerSettings.direction == Direction.UTD ||
            readerSettings.direction == Direction.DTU
        ? Axis.vertical
        : Axis.horizontal;
    var reverse = readerSettings.direction == Direction.DTU ||
        readerSettings.direction == Direction.RTL;

    return ScrollConfig(
      context,
      child: ScrollablePositionedList.builder(
        scrollDirection: direction,
        itemCount: widget.pages.length,
        reverse: reverse,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        itemBuilder: (context, index) {
          return _buildPageImage(widget.pages[index]);
        },
      ),
    );
  }

  Widget _buildPagedMode() {
    var direction = readerSettings.direction == Direction.UTD ||
            readerSettings.direction == Direction.DTU
        ? Axis.vertical
        : Axis.horizontal;
    var reverse = readerSettings.direction == Direction.DTU ||
        readerSettings.direction == Direction.RTL;

    return ScrollConfig(
      context,
      child: PageView.builder(
        controller: pageController,
        scrollDirection: direction,
        reverse: reverse,
        itemCount: widget.pages.length,
        itemBuilder: (context, index) {
          return _buildPageImage(widget.pages[index]);
        },
      ),
    );
  }

  Widget _buildPageImage(PageUrl page) {
    var isHorizontal = readerSettings.direction == Direction.LTR ||
        readerSettings.direction == Direction.RTL;
    return Padding(
      padding: readerSettings.spacedPages
          ? isHorizontal
              ? const EdgeInsets.symmetric(horizontal: 16)
              : const EdgeInsets.symmetric(vertical: 16)
          : EdgeInsets.zero,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width,
          ),
          child: _MangaPageImage(
            page: page,
            source: widget.source,
          ),
        ),
      ),
    );
  }

  void _onPageChanged() {
    if (!pageController.hasClients) return;
    final rawPage = pageController.page;
    if (rawPage == null || rawPage.isNaN || rawPage.isInfinite) return;
    final maxPages = widget.pages.isEmpty ? 1 : widget.pages.length;
    final page = (rawPage.round() + 1).clamp(1, maxPages);
    if (page != currentPage.value) {
      currentPage.value = page;
    }
  }

  void _updateCurrentPage() {
    final positions = itemPositionsListener.itemPositions.value;

    if (positions.isEmpty) {
      currentPage.value = 1;
      return;
    }

    final maxPages = widget.pages.isEmpty ? 1 : widget.pages.length;
    final rawIndex = positions
            .reduce((a, b) => (a.itemLeadingEdge < b.itemLeadingEdge &&
                    a.itemTrailingEdge < b.itemTrailingEdge)
                ? a
                : b)
            .index;
    currentPage.value = (rawIndex + 1).clamp(1, maxPages);
  }

  double currentScale = 1.0;

  void _toggleZoom(TapDownDetails details) {
    final tapPosition = details.localPosition;
    final targetScale = (currentScale < 2.0) ? 2.0 : 1.0;
    _zoomAtPoint(tapPosition, targetScale);
  }

  void _zoomOnScroll(double scrollDelta, Offset pointerPosition) {
    final zoomFactor = (scrollDelta < 0) ? 1.1 : 0.9;
    final newScale = (currentScale * zoomFactor).clamp(1.0, 4.0);
    _zoomAtPoint(pointerPosition, newScale);
  }

  void _zoomAtPoint(Offset focalPoint, double targetScale) {
    final matrix = transformationController.value;
    currentScale = targetScale;
    final focalPointInScene = _transformPoint(matrix, focalPoint);
    transformationController.value = Matrix4.identity()
      ..translate(focalPointInScene.dx, focalPointInScene.dy)
      ..scale(currentScale)
      ..translate(-focalPointInScene.dx, -focalPointInScene.dy);
  }

  Offset _transformPoint(Matrix4 matrix, Offset point) {
    final invertedMatrix = Matrix4.inverted(matrix);
    final x = (invertedMatrix[0] * point.dx) + (invertedMatrix[12]);
    final y = (invertedMatrix[5] * point.dy) + (invertedMatrix[13]);
    return Offset(x, y);
  }
}

class _MangaPageImage extends StatefulWidget {
  final PageUrl page;
  final Source source;

  const _MangaPageImage({required this.page, required this.source});

  @override
  State<_MangaPageImage> createState() => _MangaPageImageState();
}

class _MangaPageImageState extends State<_MangaPageImage> {
  int _retryKey = 0;

  @override
  Widget build(BuildContext context) {
    final rawUrl = widget.page.url.trim();

    if (rawUrl.startsWith('data:image/') ||
        (rawUrl.startsWith('data:') && rawUrl.contains(';base64,'))) {
      try {
        final commaIndex = rawUrl.indexOf(',');
        if (commaIndex != -1) {
          final bytes = base64Decode(rawUrl.substring(commaIndex + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.fitWidth,
            errorBuilder: (context, error, stackTrace) =>
                _buildErrorWidget(error.toString()),
          );
        }
      } catch (e) {
        return _buildErrorWidget(e.toString());
      }
    }

    if (rawUrl.startsWith('file://') ||
        (!rawUrl.startsWith('http://') &&
            !rawUrl.startsWith('https://') &&
            File(rawUrl).existsSync())) {
      final filePath = rawUrl.startsWith('file://')
          ? rawUrl.replaceFirst('file://', '')
          : rawUrl;
      return Image.file(
        File(filePath),
        fit: BoxFit.fitWidth,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorWidget(error.toString()),
      );
    }

    final headers = Map<String, String>.from(widget.page.headers ?? {});
    if (!headers.containsKey('User-Agent')) {
      headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }
    if (!headers.containsKey('Referer')) {
      if (widget.source.baseUrl != null && widget.source.baseUrl!.isNotEmpty) {
        headers['Referer'] = widget.source.baseUrl!.endsWith('/')
            ? widget.source.baseUrl!
            : '${widget.source.baseUrl!}/';
      } else {
        try {
          final uri = Uri.parse(rawUrl);
          headers['Referer'] = '${uri.scheme}://${uri.host}/';
        } catch (_) {}
      }
    }

    return KeyedSubtree(
      key: ValueKey('page_${widget.page.url}_$_retryKey'),
      child: CachedNetworkImage(
        imageUrl: rawUrl,
        httpHeaders: headers,
        fit: BoxFit.fitWidth,
        errorWidget: (context, url, error) =>
            _buildErrorWidget(error.toString()),
        progressIndicatorBuilder: (context, url, downloadProgress) {
          return SizedBox(
            height: MediaQuery.of(context).size.height / 2,
            width: double.infinity,
            child: Center(
              child: CircularProgressIndicator(
                value: downloadProgress.progress,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 2,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.redAccent, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Failed to load image',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                error,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _retryKey++;
                });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
