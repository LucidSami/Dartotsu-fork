import 'package:dartotsu/Functions/string_extensions.dart';
import 'package:dartotsu/Theme/Colors.dart';
import 'package:dartotsu/Theme/ThemeProvider.dart';
import 'package:dartotsu/Widgets/CachedNetworkImage.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../DataClass/Media.dart';
import 'Widget/HandleProgress.dart';

class EpisodeListView extends StatelessWidget {
  final DEpisode episode;
  final Media mediaData;
  final bool isWatched;

  EpisodeListView({
    super.key,
    required this.episode,
    required this.mediaData,
  }) : isWatched =
            (mediaData.userProgress != null && mediaData.userProgress! > 0)
                ? mediaData.userProgress!.toString().toDouble() >=
                    episode.episodeNumber.toDouble()
                : false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final themeManager = Provider.of<ThemeNotifier>(context);
    final isDark = themeManager.isDarkMode;

    Color cardColor = (episode.filler ?? false)
        ? (isDark ? fillerDark : fillerLight)
        : theme.surfaceContainerHighest;

    return Opacity(
      opacity: isWatched ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 4,
        color: cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEpisodeHeader(context, theme),
            if (episode.description != null && episode.description!.isNotEmpty)
              _buildEpisodeDescription(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeHeader(BuildContext context, ColorScheme theme) {
    final hasRating = episode.rating != null && episode.rating!.isNotEmpty;
    final hasDate =
        episode.dateUpload != null && episode.dateUpload!.isNotEmpty;
    final isFiller = episode.filler ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildThumbnail(context, theme),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFiller || hasRating || hasDate)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFiller)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Filler",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        if (hasRating)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                episode.rating!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.onSurface.withOpacity(0.85),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              if (hasDate) const SizedBox(width: 6),
                            ],
                          ),
                        if (hasDate)
                          Text(
                            episode.dateUpload!.contains('T')
                                ? episode.dateUpload!.split('T').first
                                : episode.dateUpload!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.onSurface.withOpacity(0.55),
                              fontFamily: 'Poppins',
                            ),
                          ),
                      ],
                    ),
                  ),
                Text(
                  episode.name ?? '',
                  maxLines: 4,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(BuildContext context, ColorScheme theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      color: theme.surfaceContainerLowest,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: cachedNetworkImage(
              imageUrl: episode.thumbnail ?? '',
              fit: BoxFit.cover,
              width: 164,
              height: 109,
              placeholder: (context, url) => Container(
                color: Colors.white12,
                width: 164,
                height: 109,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: theme.surfaceContainerLowest,
                width: 164,
                height: 109,
                child: Center(
                  child: Icon(
                    Icons.movie_outlined,
                    color: theme.onSurface.withOpacity(0.3),
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -4,
            left: -4,
            child: Card(
              color: theme.onSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(16.0),
                  topLeft: Radius.circular(17.0),
                  bottomLeft: Radius.circular(-1.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 4.0,
                ),
                child: Text(
                  episode.episodeNumber,
                  style: TextStyle(
                    fontSize: 20,
                    color: theme.surface,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
          if (isWatched)
            Positioned(
              bottom: 6,
              left: 3,
              child: Icon(
                Icons.remove_red_eye,
                color: theme.onSurface,
                size: 26,
              ),
            ),
          handleProgress(
            context: context,
            mediaId: mediaData.id,
            ep: episode.episodeNumber,
            width: 162,
          )
        ],
      ),
    );
  }

  Widget _buildEpisodeDescription(ColorScheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ExpandableText(
        episode.description!,
        style: TextStyle(
          color: theme.onSurface,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w400,
        ),
        maxLines: 3,
        expandText: 'Show more',
        collapseText: 'Show less',
      ),
    );
  }
}
