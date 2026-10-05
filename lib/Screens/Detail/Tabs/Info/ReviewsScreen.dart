import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../Api/Anilist/Anilist.dart';
import '../../../../Api/Anilist/AnilistQueries.dart';
import '../../../../Api/Anilist/Data/others.dart';
import '../../../../Functions/Function.dart';
import '../../../../Widgets/CachedNetworkImage.dart';
import '../../../../Widgets/ScrollConfig.dart';
import 'ReviewDetailScreen.dart';

class ReviewsScreen extends StatefulWidget {
  final int mediaId;
  final String mediaTitle;
  final List<Review>? initialReviews;

  const ReviewsScreen({
    super.key,
    required this.mediaId,
    required this.mediaTitle,
    this.initialReviews,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final List<Review> _reviews = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialReviews != null && widget.initialReviews!.isNotEmpty) {
      _reviews.addAll(widget.initialReviews!);
      _isLoading = false;
    }
    _scrollController.addListener(_onScroll);
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasNextPage) {
      _loadPage(_currentPage + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (page == 1 && _reviews.isNotEmpty) {
      // Background refresh first page
    } else if (page > 1) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final result =
          await (Anilist.query as AnilistQueries?)?.getReviews(widget.mediaId, page: page);
      if (result != null && mounted) {
        setState(() {
          _currentPage = page;
          _hasNextPage = result.hasNextPage;
          if (page == 1) {
            _reviews.clear();
            _reviews.addAll(result.reviews);
          } else {
            // Deduplicate by ID
            final existingIds = _reviews.map((r) => r.id).toSet();
            for (final r in result.reviews) {
              if (!existingIds.contains(r.id)) {
                _reviews.add(r);
              }
            }
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Reviews: ${widget.mediaTitle}",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: theme.primary),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? Center(
                  child: Text(
                    "No reviews found for this title",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: theme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ScrollConfig(
                  context,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    itemCount: _reviews.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _reviews.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final review = _reviews[index];
                      final dateStr = review.createdAt > 0
                          ? DateFormat.yMMMd().format(
                              DateTime.fromMillisecondsSinceEpoch(
                                review.createdAt * 1000,
                              ),
                            )
                          : '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        color: theme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          side: BorderSide(
                            color: theme.outlineVariant.withValues(alpha: 0.2),
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
                                      borderRadius: BorderRadius.circular(20),
                                      child: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: cachedNetworkImage(
                                          imageUrl: review.user?.avatar?.medium ?? '',
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) =>
                                              CircleAvatar(
                                            backgroundColor: theme.primary
                                                .withValues(alpha: 0.2),
                                            child: Icon(Icons.person,
                                                color: theme.primary),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review.user?.name ?? 'Anonymous',
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (dateStr.isNotEmpty)
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 11,
                                                color: theme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${review.score}%",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
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
                                    color:
                                        theme.onSurface.withValues(alpha: 0.85),
                                    height: 1.4,
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (review.ratingAmount > 0) ...[
                                      Icon(
                                        Icons.thumb_up_alt_outlined,
                                        size: 14,
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
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const Spacer(),
                                    ] else
                                      const Spacer(),
                                    Text(
                                      "Read full review",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: theme.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
