import 'package:flutter/material.dart';

import '../../../../../DataClass/Media.dart';
import '../../../../../Functions/Function.dart';
import '../../../../../Services/WatchOrder/WatchOrderService.dart';
import '../../../../../Widgets/CachedNetworkImage.dart';
import '../../../MediaScreen.dart';

class WatchOrderWidget extends StatefulWidget {
  final Media media;

  const WatchOrderWidget({super.key, required this.media});

  @override
  State<WatchOrderWidget> createState() => _WatchOrderWidgetState();
}

class _WatchOrderWidgetState extends State<WatchOrderWidget> {
  List<WatchOrderItem>? _items;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchOrder();
  }

  Future<void> _loadWatchOrder() async {
    final items = await WatchOrderService().getWatchOrder(widget.media);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_items == null || _items!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                'Watch Order',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_items!.length}',
                  style: TextStyle(
                    fontFamily: 'Poppins-SemiBold',
                    fontSize: 12,
                    color: theme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _items!.length,
            itemBuilder: (context, index) {
              final item = _items![index];
              return _buildItemCard(context, item, index);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, WatchOrderItem item, int index) {
    final theme = Theme.of(context).colorScheme;
    final isCurrent = item.isCurrent;

    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (item.isCurrent) return;
          final anilistId = int.tryParse(item.anilistId ?? '');
          final malId = int.tryParse(item.id);
          final targetMedia = Media(
            id: anilistId ?? malId ?? 0,
            idMAL: malId,
            idAnilist: anilistId,
            mal: widget.media.mal,
            name: item.name,
            nameRomaji: item.name,
            userPreferredName: item.name,
            cover: item.image,
            format: item.mediaType,
          );
          navigateToPage(
            context,
            MediaInfoPage(targetMedia, '${targetMedia.id}_watch_order'),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 155,
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent ? theme.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.image.isNotEmpty
                        ? cachedNetworkImage(
                            imageUrl: item.image,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: theme.surfaceContainerHigh,
                            child: const Center(
                              child: Icon(Icons.movie, size: 30),
                            ),
                          ),
                  ),
                ),
                // Index / Step badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.primary
                          : Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontFamily: 'Poppins-SemiBold',
                        fontSize: 10,
                        color: isCurrent ? theme.onPrimary : Colors.white,
                      ),
                    ),
                  ),
                ),
                // Format badge
                if (item.mediaType.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.mediaType.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Poppins-SemiBold',
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Relation type badge
                if (item.relationType.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? theme.primary.withValues(alpha: 0.9)
                            : Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.relationType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins-SemiBold',
                          fontSize: 9,
                          color: isCurrent ? theme.onPrimary : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                color: isCurrent ? theme.primary : theme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
