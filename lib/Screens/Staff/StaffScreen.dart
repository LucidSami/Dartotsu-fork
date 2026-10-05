import 'package:dartotsu/DataClass/Author.dart';
import 'package:flutter/material.dart';

import '../../Adaptor/Media/MediaAdaptor.dart';
import '../../Api/Anilist/Anilist.dart';
import '../../Api/Anilist/AnilistQueries.dart';
import '../../DataClass/Studio.dart';
import '../../Functions/Function.dart';
import '../../Preferences/PrefManager.dart';
import '../../Widgets/ScrollConfig.dart';

class StaffScreen extends StatefulWidget {
  final author staffInfo;

  const StaffScreen({super.key, required this.staffInfo});

  @override
  StaffScreenState createState() => StaffScreenState();
}

class StaffScreenState extends State<StaffScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.staffInfo.name ?? 'No Name',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.onPrimary,
          ),
        ),
        backgroundColor: theme.primary,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Text(
                  widget.staffInfo.name ?? 'No Name',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.onSurface,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class StudioScreen extends StatefulWidget {
  final int studioId;
  final String studioName;
  final String? siteUrl;
  final studio? studioInfo;

  StudioScreen({
    super.key,
    int? studioId,
    String? studioName,
    String? siteUrl,
    this.studioInfo,
  })  : studioId = studioId ?? studioInfo?.id ?? 0,
        studioName = studioName ?? studioInfo?.name ?? '',
        siteUrl = siteUrl ?? studioInfo?.siteUrl;

  @override
  StudioScreenState createState() => StudioScreenState();
}

class StudioScreenState extends State<StudioScreen> {
  studio? _studioDetails;
  bool _isLoading = true;
  late int _viewMode; // 2 = list, 3 = grid

  @override
  void initState() {
    super.initState();
    _viewMode = loadCustomData<int>('studioViewMode') ?? 3;
    _loadStudioDetails();
  }

  Future<void> _loadStudioDetails() async {
    if (widget.studioInfo?.media != null &&
        widget.studioInfo!.media!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _studioDetails = widget.studioInfo;
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final details =
          await (Anilist.query as AnilistQueries?)?.getStudioDetails(
        widget.studioId,
        studioName: widget.studioName,
      );
      if (mounted) {
        setState(() {
          _studioDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final studioName = _studioDetails?.name ?? widget.studioName;
    final studioSiteUrl = _studioDetails?.siteUrl ?? widget.siteUrl;
    final mediaMap = _studioDetails?.media ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          studioName.isNotEmpty ? studioName : 'Studio',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: theme.primary),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == 2 ? Icons.grid_view_rounded : Icons.view_list_sharp,
            ),
            tooltip: _viewMode == 2 ? 'Switch to Grid' : 'Switch to List',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 2 ? 3 : 2;
                saveCustomData('studioViewMode', _viewMode);
              });
            },
          ),
          if (studioSiteUrl != null && studioSiteUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open in Browser',
              onPressed: () => openLinkInBrowser(studioSiteUrl),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : mediaMap.isEmpty
              ? Center(
                  child: Text(
                    'No media found for this studio',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: theme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : CustomScrollConfig(
                  context,
                  children: [
                    for (final entry in mediaMap.entries) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 18,
                            right: 18,
                            top: 20,
                            bottom: 8,
                          ),
                          child: Text(
                            "${entry.key} (${entry.value.length})",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.primary,
                            ),
                          ),
                        ),
                      ),
                      MediaAdaptor(
                        type: _viewMode,
                        mediaList: entry.value,
                        sliver: true,
                      ),
                    ],
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                ),
    );
  }
}

