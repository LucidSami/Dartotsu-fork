import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';

import '../../../../Api/Anilist/Data/others.dart';
import '../../../../Functions/Function.dart';
import '../../../../Widgets/CachedNetworkImage.dart';
import '../../../../Widgets/ScrollConfig.dart';

class ReviewDetailScreen extends StatelessWidget {
  final Review review;

  const ReviewDetailScreen({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final createdDate = review.createdAt > 0
        ? DateFormat.yMMMd().format(
            DateTime.fromMillisecondsSinceEpoch(review.createdAt * 1000),
          )
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Review by ${review.user?.name ?? 'Anonymous'}",
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
        actions: [
          if (review.siteUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: "Open on AniList",
              onPressed: () => openLinkInBrowser(review.siteUrl),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ScrollConfig(
        context,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Card
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: theme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: theme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: cachedNetworkImage(
                          imageUrl: review.user?.avatar?.medium ??
                              review.user?.avatar?.large ??
                              '',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => CircleAvatar(
                            backgroundColor: theme.primary.withValues(alpha: 0.2),
                            child: Icon(Icons.person, color: theme.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.user?.name ?? 'Anonymous',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (createdDate.isNotEmpty)
                            Text(
                              createdDate,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: theme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: theme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${review.score}%",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Helpful voting info
              if (review.ratingAmount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.thumb_up_alt_outlined,
                        size: 16,
                        color: theme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${review.rating} of ${review.ratingAmount} users found this review helpful",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: theme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Summary
              if (review.summary.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border(
                      left: BorderSide(color: theme.primary, width: 4),
                    ),
                  ),
                  child: Text(
                    review.summary,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: theme.onSurface,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Review Body (HTML)
              Html(
                data: review.body,
                style: {
                  "body": Style(
                    fontSize: FontSize(14.5),
                    fontFamily: 'Poppins',
                    lineHeight: const LineHeight(1.6),
                    color: theme.onSurface.withValues(alpha: 0.88),
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  "p": Style(
                    margin: Margins.only(bottom: 12),
                  ),
                  "a": Style(
                    color: theme.primary,
                    textDecoration: TextDecoration.underline,
                  ),
                },
                onLinkTap: (url, attributes, element) {
                  if (url != null) openLinkInBrowser(url);
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
