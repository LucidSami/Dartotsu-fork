part of '../AnilistQueries.dart';

extension GetReviews on AnilistQueries {
  Future<({List<Review> reviews, bool hasNextPage})> _getReviews(
    int mediaId, {
    int page = 1,
    int perPage = 20,
    String sort = "SCORE_DESC",
  }) async {
    final query = """
query (\$page: Int, \$mediaId: Int, \$perPage: Int) {
  Page(page: \$page, perPage: \$perPage) {
    pageInfo {
      total
      perPage
      currentPage
      lastPage
      hasNextPage
    }
    reviews(mediaId: \$mediaId, sort: [$sort, ID_DESC]) {
      id
      mediaId
      mediaType
      summary
      body(asHtml: true)
      rating
      ratingAmount
      userRating
      score
      private
      siteUrl
      createdAt
      updatedAt
      user {
        id
        name
        bannerImage
        avatar {
          large
          medium
        }
      }
    }
  }
}
""";

    try {
      final res = await executeQuery<Map<String, dynamic>>(
        query,
        variables: '{"page": $page, "mediaId": $mediaId, "perPage": $perPage}',
      );

      if (res == null || res['data'] == null || res['data']['Page'] == null) {
        return (reviews: <Review>[], hasNextPage: false);
      }

      final pageData = res['data']['Page'] as Map<String, dynamic>;
      final pageInfo = pageData['pageInfo'] as Map<String, dynamic>?;
      final hasNext = pageInfo?['hasNextPage'] as bool? ?? false;
      final reviewNodes = pageData['reviews'] as List<dynamic>? ?? [];

      final reviews = <Review>[];
      for (final item in reviewNodes) {
        if (item is Map<String, dynamic>) {
          reviews.add(
            Review(
              id: (item['id'] as num?)?.toInt() ?? 0,
              mediaId: (item['mediaId'] as num?)?.toInt() ?? mediaId,
              mediaType: item['mediaType'] as String? ?? 'ANIME',
              summary: item['summary'] as String? ?? '',
              body: item['body'] as String? ?? '',
              rating: (item['rating'] as num?)?.toInt() ?? 0,
              ratingAmount: (item['ratingAmount'] as num?)?.toInt() ?? 0,
              userRating: item['userRating'] as String? ?? 'NO_VOTE',
              score: (item['score'] as num?)?.toInt() ?? 0,
              private: item['private'] as bool? ?? false,
              siteUrl: item['siteUrl'] as String? ?? '',
              createdAt: (item['createdAt'] as num?)?.toInt() ?? 0,
              updatedAt: (item['updatedAt'] as num?)?.toInt(),
              user: item['user'] != null
                  ? User.fromJson(item['user'] as Map<String, dynamic>)
                  : null,
            ),
          );
        }
      }

      return (reviews: reviews, hasNextPage: hasNext);
    } catch (e) {
      debugPrint("Error in _getReviews: $e");
      return (reviews: <Review>[], hasNextPage: false);
    }
  }
}
