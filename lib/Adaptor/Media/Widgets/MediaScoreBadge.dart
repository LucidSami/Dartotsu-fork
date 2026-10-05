import 'package:flutter/material.dart';
import '../../../DataClass/Media.dart';
import '../../../Services/MalScoreService.dart';

Widget ScoreBadge(BuildContext context, Media mediaInfo) {
  final theme = Theme.of(context).colorScheme;

  Widget buildAnilistBadge(String scoreText, {bool isOnlyBadge = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: mediaInfo.userScore == 0
            ? const Color(0xFF02A9FF) // Saikou AniList blue #02a9ff
            : theme.tertiary,
        borderRadius: BorderRadius.only(
          bottomRight: const Radius.circular(16.0),
          topLeft: const Radius.circular(10.0),
          bottomLeft: isOnlyBadge ? const Radius.circular(4.0) : const Radius.circular(0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Text(
              scoreText,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Padding(
            padding: EdgeInsets.only(top: 1.0),
            child: Text(
              'A',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMalBadge(String scoreText, {bool isBottomBadge = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isBottomBadge ? 0 : 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2E51A2), // Saikou MAL blue #2e51a2
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10.0),
          bottomLeft: const Radius.circular(4.0),
          topRight: const Radius.circular(4.0),
          bottomRight: isBottomBadge ? const Radius.circular(16.0) : const Radius.circular(0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Text(
              scoreText,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Padding(
            padding: EdgeInsets.only(top: 1.0),
            child: Text(
              'M',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Case 1: MAL is the source provider
  if (mediaInfo.mal) {
    final malScoreVal = mediaInfo.malScore ??
        ((mediaInfo.meanScore != null && mediaInfo.meanScore! > 0)
            ? mediaInfo.meanScore! / 10.0
            : null);
    final hasMal = malScoreVal != null && malScoreVal > 0;
    final malScoreFormatted = hasMal ? malScoreVal.toStringAsFixed(1) : null;

    final malId = mediaInfo.idMAL ?? mediaInfo.id;
    if (malId > 0) {
      MalScoreService().fetchAnilistScore(malId);
      return Positioned(
        bottom: 0,
        right: 0,
        child: ValueListenableBuilder<double?>(
          valueListenable: MalScoreService().getAnilistScoreNotifier(malId),
          builder: (context, anilistScore, _) {
            final hasAni = anilistScore != null && anilistScore > 0;
            final anilistScoreFormatted = hasAni ? anilistScore.toStringAsFixed(1) : null;

            if (hasMal && hasAni) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  buildMalBadge(malScoreFormatted!),
                  buildAnilistBadge(anilistScoreFormatted!),
                ],
              );
            } else if (hasMal) {
              return buildMalBadge(malScoreFormatted!, isBottomBadge: true);
            } else if (hasAni) {
              return buildAnilistBadge(anilistScoreFormatted!, isOnlyBadge: true);
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    if (hasMal) {
      return Positioned(
        bottom: 0,
        right: 0,
        child: buildMalBadge(malScoreFormatted!, isBottomBadge: true),
      );
    }
    return const SizedBox.shrink();
  }

  // Case 2: AniList is the source provider (or general provider)
  final rawAnilistScore = mediaInfo.userScore != 0
      ? mediaInfo.userScore
      : mediaInfo.meanScore;
  final hasAnilist = rawAnilistScore != null && rawAnilistScore > 0;
  final anilistScoreFormatted = hasAnilist
      ? (rawAnilistScore / 10.0).toStringAsFixed(1)
      : null;

  final malId = mediaInfo.idMAL;
  if (malId != null && malId > 0) {
    if (mediaInfo.malScore == null) {
      MalScoreService().fetchMalScore(
        malId,
        isAnime: mediaInfo.anime != null,
      );
    }
    return Positioned(
      bottom: 0,
      right: 0,
      child: ValueListenableBuilder<double?>(
        valueListenable: MalScoreService().getScoreNotifier(
          malId,
          initialScore: mediaInfo.malScore,
        ),
        builder: (context, malScore, _) {
          final effectiveMal = (malScore != null && malScore > 0)
              ? malScore
              : (mediaInfo.malScore != null && mediaInfo.malScore! > 0)
                  ? mediaInfo.malScore
                  : null;
          final hasMal = effectiveMal != null && effectiveMal > 0;
          final malScoreFormatted = hasMal ? effectiveMal.toStringAsFixed(1) : null;

          if (hasAnilist && hasMal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                buildMalBadge(malScoreFormatted!),
                buildAnilistBadge(anilistScoreFormatted!),
              ],
            );
          } else if (hasAnilist) {
            return buildAnilistBadge(anilistScoreFormatted!, isOnlyBadge: true);
          } else if (hasMal) {
            return buildMalBadge(malScoreFormatted!, isBottomBadge: true);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  if (hasAnilist) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: buildAnilistBadge(anilistScoreFormatted!, isOnlyBadge: true),
    );
  }

  return const SizedBox.shrink();
}
