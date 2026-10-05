import 'package:flutter/material.dart';

import '../../Adaptor/Media/MediaAdaptor.dart';
import '../../DataClass/Media.dart';
import '../../Preferences/PrefManager.dart';
import '../../Widgets/ScrollConfig.dart';

class MediaListDetailScreen extends StatefulWidget {
  final String title;
  final List<Media> mediaList;
  final Future<List<Media>?> Function(int page)? fetchMore;

  const MediaListDetailScreen({
    super.key,
    required this.title,
    required this.mediaList,
    this.fetchMore,
  });

  @override
  State<MediaListDetailScreen> createState() => _MediaListDetailScreenState();
}

class _MediaListDetailScreenState extends State<MediaListDetailScreen> {
  late List<Media> _list;
  late int _viewMode; // 2 = list, 3 = grid
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _isCooldown = false;
  bool _hasMore = true;
  DateTime _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _list = List<Media>.from(widget.mediaList);
    _viewMode = loadCustomData<int>('mediaListDetailView') ?? 3;
    _hasMore = widget.fetchMore != null;
    // If the initial preview has fewer than 40 items, initialize page at 0
    // so the first pagination call requests page 1 (50 items) to fill out the list
    _currentPage = widget.mediaList.length < 40 ? 0 : 1;

    if (widget.fetchMore != null) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 350 &&
        !_isLoadingMore &&
        !_isCooldown &&
        _hasMore) {
      final now = DateTime.now();
      if (now.difference(_lastFetchTime).inMilliseconds >= 800) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isCooldown || !_hasMore || widget.fetchMore == null) return;
    _lastFetchTime = DateTime.now();
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final newItems = await widget.fetchMore!(nextPage);
      if (mounted) {
        setState(() {
          if (newItems != null) {
            if (newItems.isEmpty) {
              _hasMore = false;
            } else {
              _currentPage = nextPage;
              // Deduplicate by id
              final existingIds = _list.map((m) => m.id).toSet();
              final unique = newItems.where((m) => !existingIds.contains(m.id)).toList();
              if (unique.isEmpty) {
                _hasMore = false;
              } else {
                _list.addAll(unique);
              }
            }
          } else {
            // Null returned (e.g. rate limit/timeout): allow retry on scroll without locking _hasMore
            _hasMore = true;
          }
        });
      }
    } catch (_) {
      // In case of error (or temporary 429), don't permanently disable hasMore
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _isCooldown = true;
        });
        // Cooldown period before another scroll fetch can trigger to avoid 429 bursts
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() => _isCooldown = false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "${widget.title} (${_list.length})",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
            color: theme.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: theme.primary),
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == 2 ? Icons.grid_view_rounded : Icons.view_list_sharp,
            ),
            tooltip: _viewMode == 2 ? 'Switch to Grid' : 'Switch to List',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 2 ? 3 : 2;
                saveCustomData('mediaListDetailView', _viewMode);
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollConfig(
        context,
        controller: _scrollController,
        children: [
          SliverToBoxAdapter(
            child: MediaAdaptor(
              type: _viewMode,
              mediaList: _list,
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}
