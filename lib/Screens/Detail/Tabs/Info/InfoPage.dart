import 'dart:math';

import 'package:dartotsu/Adaptor/Charactes/Widgets/EntitySection.dart';
import 'package:dartotsu/DataClass/SearchResults.dart';
import 'package:dartotsu/Functions/Function.dart';
import 'package:dartotsu/Screens/Detail/Tabs/Info/Widgets/GenreWidget.dart';
import 'package:dartotsu/Screens/Search/SearchScreen.dart';
import 'package:dartotsu/Theme/LanguageSwitcher.dart';
import 'package:dartotsu/Services/MalScoreService.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';

import '../../../../../Adaptor/Media/Widgets/MediaSection.dart';
import '../../../../Adaptor/Media/Widgets/Chips.dart';
import '../../../../Adaptor/Media/Widgets/MediaCard.dart';
import '../../../../DataClass/Media.dart';
import '../../../../Services/ServiceSwitcher.dart';
import '../../MediaScreen.dart';
import '../../Widgets/Releasing.dart';
import '../../../Staff/StaffScreen.dart';
import 'Widgets/ReviewsWidget.dart';
import 'Widgets/WatchOrderWidget.dart';

class InfoPage extends StatefulWidget {
  final Media mediaData;

  const InfoPage({super.key, required this.mediaData});

  @override
  State<StatefulWidget> createState() => InfoPageState();
}

class InfoPageState extends State<InfoPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    var service = Provider.of<MediaServiceProvider>(context).currentService;
    if (service.data.query?.mediaDetails == null) {
      return service.notImplemented(widget.runtimeType.toString());
    }
    final horizontalPadding = context.isPhone ? 0.0 : 16.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...releasingIn(widget.mediaData, context),
        _buildWithPadding([..._buildInfoSections(), ..._buildNameSections()]),
        if (widget.mediaData.synonyms.isNotEmpty) ..._buildSynonyms(theme),
        if (widget.mediaData.genres.isNotEmpty)
          _buildWithPadding([
            GenreWidget(
              context,
              widget.mediaData.genres,
              widget.mediaData.anime != null
                  ? SearchType.ANIME
                  : SearchType.MANGA,
            ),
          ]),
        if (widget.mediaData.tags.isNotEmpty) ..._buildTags(theme),
        ..._buildPrequelSection(),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            spacing: 24,
            children: [
              if (widget.mediaData.anime != null)
                WatchOrderWidget(media: widget.mediaData),
              if (widget.mediaData.relations?.isNotEmpty ?? false)
                MediaSection(
                  context: context,
                  type: 0,
                  title: getString.relations,
                  mediaList: widget.mediaData.relations,
                  isLarge: true,
                ),
              if (widget.mediaData.characters?.isNotEmpty ?? false)
                entitySection(
                  context: context,
                  type: EntityType.Character,
                  title: getString.characters,
                  list: widget.mediaData.characters,
                ),
              if (widget.mediaData.staff?.isNotEmpty ?? false)
                entitySection(
                  context: context,
                  type: EntityType.Staff,
                  title: getString.staff,
                  list: widget.mediaData.staff,
                ),
              ReviewsWidget(mediaData: widget.mediaData),
              if (widget.mediaData.recommendations?.isNotEmpty ?? false) ...[
                MediaSection(
                  context: context,
                  type: 0,
                  title: getString.recommended,
                  mediaList: widget.mediaData.recommendations,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 64.0),
      ],
    );
  }

  Widget _buildWithPadding(List<Widget> widgets) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  List<Widget> _buildInfoSections() {
    var mediaData = widget.mediaData;
    bool isAnime = mediaData.anime != null;

    String infoTotal =
        (mediaData.anime?.nextAiringEpisode != null &&
            mediaData.anime?.nextAiringEpisode != -1)
        ? "${mediaData.anime?.nextAiringEpisode} | ${mediaData.anime?.totalEpisodes ?? "~"}"
        : (mediaData.anime?.totalEpisodes ?? "~").toString();

    return [
      if (mediaData.mal) ...[
        _buildInfoRow(
          title: 'MAL Score',
          value: (mediaData.malScore != null && mediaData.malScore! > 0)
              ? '${mediaData.malScore!.toStringAsFixed(1)} / 10'
              : (mediaData.meanScore != null && mediaData.meanScore! > 0)
                  ? '${(mediaData.meanScore! / 10).toStringAsFixed(1)} / 10'
                  : 'N/A',
        ),
        if ((mediaData.idMAL ?? mediaData.id) > 0) _buildAnilistScoreRow(mediaData),
      ] else ...[
        _buildInfoRow(
          title: 'AniList Score',
          value: (mediaData.meanScore != null && mediaData.meanScore! > 0)
              ? '${(mediaData.meanScore! / 10).toStringAsFixed(1)} / 10'
              : 'N/A',
        ),
        if (mediaData.idMAL != null) _buildMalScoreRow(mediaData),
      ],
      _buildInfoRow(
        title: getString.status,
        value: mediaData.status?.toString(),
      ),
      _buildInfoRow(
        title:
            "${getString.total} ${isAnime ? getString.totalEpisodes : getString.totalChapters}",
        value: infoTotal,
      ),
      _buildInfoRow(
        title: getString.averageDuration,
        value: _formatEpisodeDuration(mediaData.anime?.episodeDuration),
      ),
      _buildInfoRow(
        title: getString.format,
        value: mediaData.format?.toString().replaceAll("_", " "),
      ),
      _buildInfoRow(
        title: getString.source,
        value: mediaData.source?.toString().replaceAll("_", " "),
      ),
      _buildInfoRow(
        title: getString.studio,
        value: mediaData.anime?.mainStudio?.name,
        onClick: mediaData.anime?.mainStudio != null
            ? () {
                navigateToPage(
                  context,
                  StudioScreen(
                    studioId: mediaData.anime!.mainStudio!.id,
                    studioName: mediaData.anime!.mainStudio!.name ?? '',
                    siteUrl: mediaData.anime!.mainStudio!.siteUrl,
                  ),
                );
              }
            : null,
      ),
      _buildInfoRow(
        title: getString.author,
        value:
            mediaData.anime?.mediaAuthor?.name ??
            mediaData.manga?.mediaAuthor?.name,
        onClick: (mediaData.anime?.mediaAuthor ?? mediaData.manga?.mediaAuthor) !=
                null
            ? () {
                navigateToPage(
                  context,
                  StaffScreen(
                    staffInfo: (mediaData.anime?.mediaAuthor ??
                        mediaData.manga?.mediaAuthor)!,
                  ),
                );
              }
            : null,
      ),
      _buildInfoRow(
        title: getString.season,
        value: _formatSeason(
          mediaData.anime?.season,
          mediaData.anime?.seasonYear,
        ),
      ),
      _buildInfoRow(
        title: getString.startDate,
        value: mediaData.startDate?.getFormattedDate(),
      ),
      _buildInfoRow(
        title: getString.endDate,
        value: mediaData.endDate?.getFormattedDate() ?? "??",
      ),
      _buildInfoRow(
        title: getString.popularity,
        value: mediaData.popularity?.toString(),
      ),
      _buildInfoRow(
        title: getString.favorites,
        value: mediaData.favourites?.toString(),
      ),
    ];
  }

  List<Widget> _buildNameSections() {
    var mediaData = widget.mediaData;
    return [
      const SizedBox(height: 16.0),
      _buildTextSection(getString.nameRomaji, mediaData.nameRomaji),
      _buildTextSection(getString.name, mediaData.name?.toString()),
      _buildDescriptionSection(getString.synopsis, mediaData.description),
    ];
  }

  List<Widget> _buildSynonyms(ColorScheme theme) => [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Text(
        getString.synonyms,
        style: TextStyle(
          fontSize: 15,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          color: theme.onSurface,
        ),
      ),
    ),
    const SizedBox(height: 16.0),
    ChipsWidget(chips: [..._generateSynonyms(widget.mediaData.synonyms)]),
  ];

  List<Widget> _buildTags(ColorScheme theme) => [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Text(
        getString.tags,
        style: TextStyle(
          fontSize: 15,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          color: theme.onSurface,
        ),
      ),
    ),
    const SizedBox(height: 16.0),
    ChipsWidget(chips: [..._generateChips(widget.mediaData.tags)]),
  ];

  List<Widget> _buildPrequelSection() {
    var prequel = widget.mediaData.prequel;
    var sequel = widget.mediaData.sequel;
    final random = Random().nextInt(100000);
    final prequelTag = '${prequel?.id}$random';
    final sequelTag = '${sequel?.id}$random';
    return [
      const SizedBox(height: 24.0),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (prequel != null)
            MediaCard(
              context,
              getString.prequel,
              prequel.banner ?? prequel.cover ?? 'https://bit.ly/31bsIHq',
              onTap: () =>
                  navigateToPage(context, MediaInfoPage(prequel, prequelTag)),
            ),
          if (sequel != null)
            MediaCard(
              context,
              getString.sequel,
              sequel.banner ?? sequel.cover ?? 'https://bit.ly/2ZGfcuG',
              onTap: () =>
                  navigateToPage(context, MediaInfoPage(sequel, sequelTag)),
            ),
        ],
      ),
    ];
  }

  Widget _buildInfoRow({
    required String title,
    String? value,
    VoidCallback? onClick,
  }) {
    if (value == null || value.isEmpty) {
      return Container();
    }

    final theme = Theme.of(context).colorScheme;
    bool isClickable = onClick != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.onSurface.withValues(alpha: 0.52),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: isClickable ? onClick : null,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isClickable ? theme.primary : theme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection(String title, String? content) {
    if (content == null || content.isEmpty) return Container();
    var theme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String title, String? content) {
    if (content == null || content.isEmpty) return Container();
    var theme = Theme.of(context).colorScheme;
    final document = html_parser.parse(content);
    final String markdownContent = document.body?.text ?? "";
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: theme.onSurface,
            ),
          ),
          const SizedBox(height: 8.0),
          ExpandableText(
            markdownContent,
            maxLines: 3,
            expandText: getString.expandText,
            collapseText: getString.collapseText,
          ),
        ],
      ),
    );
  }

  List<ChipData> _generateSynonyms(List<String> labels) {
    return labels.map((label) {
      return ChipData(label: label, action: () {});
    }).toList();
  }

  List<ChipData> _generateChips(List<String> labels) {
    var title = widget.mediaData.anime != null
        ? SearchType.ANIME
        : SearchType.MANGA;
    return labels.map((label) {
      return ChipData(
        label: label,
        action: () => navigateToPage(
          context,
          SearchScreen(
            title: title,
            forceSearch: true,
            args: SearchResults(
              type: title,
              sort: "POPULARITY_DESC",
              tags: [
                label
                    .split(" ")
                    .sublist(0, label.split(" ").length - 2)
                    .join(" "),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMalScoreRow(Media mediaData) {
    final malId = mediaData.idMAL;
    if (malId == null || malId <= 0) return const SizedBox.shrink();
    final isAnime = mediaData.anime != null;

    // Trigger fetch if not cached
    MalScoreService().fetchMalScore(malId, isAnime: isAnime);

    final theme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'MAL Score',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.onSurface.withValues(alpha: 0.52),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ValueListenableBuilder<double?>(
              valueListenable: MalScoreService().getScoreNotifier(
                malId,
                initialScore: mediaData.malScore,
              ),
              builder: (context, malScore, _) {
                final display = (malScore != null && malScore > 0)
                    ? '${malScore.toStringAsFixed(1)} / 10'
                    : (malScore == -1.0)
                        ? 'N/A'
                        : '...';
                return Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: theme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnilistScoreRow(Media mediaData) {
    final malId = mediaData.idMAL ?? mediaData.id;
    if (malId <= 0) return const SizedBox.shrink();

    // Trigger batch fetch if not cached
    MalScoreService().fetchAnilistScore(malId);

    final theme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'AniList Score',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.onSurface.withValues(alpha: 0.52),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ValueListenableBuilder<double?>(
              valueListenable: MalScoreService().getAnilistScoreNotifier(malId),
              builder: (context, anilistScore, _) {
                final display = (anilistScore != null && anilistScore > 0)
                    ? '${anilistScore.toStringAsFixed(1)} / 10'
                    : (anilistScore == -1.0)
                        ? 'N/A'
                        : '...';
                return Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: theme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _formatSeason(String? season, int? year) {
    if (season == null || year == null) return null;
    return "$season $year";
  }

  String _formatEpisodeDuration(int? episodeDuration) {
    if (episodeDuration == null) return '';

    final hours = episodeDuration ~/ 60;
    final minutes = episodeDuration % 60;

    final formattedDuration = StringBuffer();

    if (hours > 0) {
      formattedDuration.write('$hours hour');
      if (hours > 1) formattedDuration.write('s');
    }

    if (minutes > 0) {
      if (hours > 0) formattedDuration.write(', ');
      formattedDuration.write('$minutes min');
      if (minutes > 1) formattedDuration.write('s');
    }

    return formattedDuration.toString();
  }
}
