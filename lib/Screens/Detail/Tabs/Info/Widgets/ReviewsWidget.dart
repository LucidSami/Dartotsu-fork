import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../Api/Anilist/Anilist.dart';
import '../../../../../Api/Anilist/AnilistQueries.dart';
import '../../../../../Api/Anilist/Data/others.dart';
import '../../../../../DataClass/Media.dart';
import '../../../../../Functions/Function.dart';
import '../../../../../Widgets/CachedNetworkImage.dart';
import '../ReviewDetailScreen.dart';
import '../ReviewsScreen.dart';

class ReviewsWidget extends StatefulWidget {
  final Media mediaData;

  const ReviewsWidget({super.key, required this.mediaData});

  @override
  State<ReviewsWidget> createState() => _ReviewsWidgetState();
}

class _ReviewsWidgetState extends State<ReviewsWidget> {
  List<Review>? _reviews;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaData.review != null && widget.mediaData.review!.isNotEmpty) {
      _reviews = widget.mediaData.review;
    } else {
      _loadInitialReviews();
    }
  }

  Future<void> _loadInitialReviews() async {
    final mediaId = widget.mediaData.idAnilist ??
        (widget.mediaData.mal == true ? widget.mediaData.idMAL : null) ??
        widget.mediaData.id;

    if (mediaId == 0) return;

    setState(() => _isLoading = true);
    try {
      final res =
          await (Anilist.query as AnilistQueries?)?.getReviews(mediaId, page: 1, perPage: 4);
      if (mounted && res != null && res.reviews.isNotEmpty) {
        setState(() {
          _reviews = res.reviews;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAllReviews() {
    final mediaId = widget.mediaData.idAnilist ??
        (widget.mediaData.mal == true ? widget.mediaData.idMAL : null) ??
        widget.mediaData.id;

    navigateToPage(
      context,
      ReviewsScreen(
        mediaId: mediaId,
        mediaTitle: widget.mediaData.userPreferredName,
        initialReviews: _reviews,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reviews == null || _reviews!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context).colorScheme;
    final displayReviews = _reviews!.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Header with "Reviews" and Arrow ->
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Reviews",
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: theme.onSurface,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                tooltip: "View all reviews",
                onPressed: _openAllReviews,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Review Cards (3-4 items)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            children: displayReviews.map((review) {
              final dateStr = review.createdAt > 0
                  ? DateFormat.yMMMd().format(
                      DateTime.fromMillisecondsSinceEpoch(
                        review.createdAt * 1000,
                      ),
                    )
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: theme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: theme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.0),
                  onTap: () => navigateToPage(
                    context,
                    ReviewDetailScreen(review: review),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: cachedNetworkImage(
                                  imageUrl: review.user?.avatar?.medium ?? '',
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    backgroundColor:
                                        theme.primary.withValues(alpha: 0.2),
                                    child: Icon(
                                      Icons.person,
                                      size: 18,
                                      color: theme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.user?.name ?? 'Anonymous',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: theme.onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${review.score}%",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: theme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          review.summary,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: theme.onSurface.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (review.ratingAmount > 0)
                              Row(
                                children: [
                                  Icon(
                                    Icons.thumb_up_alt_outlined,
                                    size: 13,
                                    color: theme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${review.rating}/${review.ratingAmount}",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: theme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),
                            Row(
                              children: [
                                Text(
                                  "Read more",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: theme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
