import 'package:expandable_widgets/expandable_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../DataClass/Media.dart';
import '../../Services/TrackSyncManager.dart';
import '../../Widgets/CustomBottomDialog.dart';
import '../../Widgets/DropdownMenu.dart';
import '../Anilist/Data/fuzzyData.dart';
import 'Mal.dart';

class MalListEditorDialog extends StatefulWidget {
  final Media media;
  final bool isCompact;

  const MalListEditorDialog({
    super.key,
    required this.media,
    this.isCompact = true,
  });

  @override
  State<MalListEditorDialog> createState() => _MalListEditorDialogState();
}

class _MalListEditorDialogState extends State<MalListEditorDialog> {
  late bool isAnime;
  late String status;
  late TextEditingController progressController;
  late TextEditingController scoreController;
  late String suffixText;
  TextEditingController? noteController;
  TextEditingController? repeatController;
  FuzzyDate? startedAt;
  FuzzyDate? completedAt;

  static String getInitialStatus(String? rawStatus, bool isAnime) {
    if (rawStatus == null || rawStatus.isEmpty) {
      return isAnime ? "PLAN TO WATCH" : "PLAN TO READ";
    }
    final s = rawStatus.toLowerCase().replaceAll(' ', '_');
    if (s == 'watching' || s == 'current') return "WATCHING";
    if (s == 'reading') return "READING";
    if (s == 'plan_to_watch' || s == 'planning') {
      return isAnime ? "PLAN TO WATCH" : "PLAN TO READ";
    }
    if (s == 'plan_to_read') return "PLAN TO READ";
    if (s == 'completed') return "COMPLETED";
    if (s == 'on_hold' || s == 'onhold' || s == 'paused') return "ON HOLD";
    if (s == 'dropped') return "DROPPED";
    if (s == 'repeating' || s == 'rewatching') {
      return isAnime ? "WATCHING" : "READING";
    }
    return isAnime ? "WATCHING" : "READING";
  }

  static String statusToMal(String displayStatus, bool isAnime) {
    switch (displayStatus) {
      case "WATCHING":
        return "watching";
      case "READING":
        return "reading";
      case "PLAN TO WATCH":
        return "plan_to_watch";
      case "PLAN TO READ":
        return "plan_to_read";
      case "COMPLETED":
        return "completed";
      case "ON HOLD":
        return "on_hold";
      case "DROPPED":
        return "dropped";
      default:
        return isAnime ? "watching" : "reading";
    }
  }

  @override
  void initState() {
    super.initState();
    final media = widget.media;
    isAnime = media.anime != null ||
        (media.format != 'manga' && media.format != 'novel');
    status = getInitialStatus(media.userStatus, isAnime);
    progressController =
        TextEditingController(text: media.userProgress?.toString() ?? '??');
    scoreController = TextEditingController(
      text: media.userScore != null && media.userScore! > 0
          ? (media.userScore! / 10).toString()
          : "??",
    );
    if (!widget.isCompact) {
      noteController = TextEditingController(text: media.notes ?? "");
      repeatController =
          TextEditingController(text: media.userRepeat.toString());
      startedAt = media.userStartedAt;
      completedAt = media.userCompletedAt;
    }
    suffixText =
        "/ ${media.anime != null ? (media.anime!.nextAiringEpisode != null && media.anime!.nextAiringEpisode != -1 ? media.anime!.nextAiringEpisode : media.anime!.totalEpisodes ?? "??") : media.manga?.totalChapters ?? "??"}";
  }

  @override
  void dispose() {
    progressController.dispose();
    scoreController.dispose();
    noteController?.dispose();
    repeatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 18,
      fontWeight: FontWeight.w800,
    );
    const suffixStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    const fieldPadding = EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0);
    var theme = Theme.of(context).colorScheme;

    return CustomBottomDialog(
      title: "List Editor",
      viewList: [
        Padding(
          padding: fieldPadding,
          child: Column(
            children: [
              _buildStatusDropdown(),
              const SizedBox(height: 16),
              _buildProgressField(labelStyle, suffixStyle),
              const SizedBox(height: 8),
              _buildScoreField(labelStyle, suffixStyle),
              const SizedBox(height: 8),
              if (!widget.isCompact) ...[
                _buildDatePickerRow(suffixStyle),
                const SizedBox(height: 8),
                Expandable(
                  backgroundColor: theme.surface,
                  boxShadow: const [],
                  arrowWidget:
                      const Icon(Icons.keyboard_arrow_up_rounded, size: 25.0),
                  firstChild: const Text('Other', style: suffixStyle),
                  secondChild: _buildOtherWidget(labelStyle, suffixStyle),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
      positiveText: 'Save',
      positiveCallback: _onSave,
      negativeText: 'Delete',
      negativeCallback: _onDelete,
    );
  }

  Widget _buildStatusDropdown() {
    final options = Mal.getStatusList(isAnime);
    return buildDropdownMenu(
      padding: const EdgeInsets.all(0),
      borderRadius: 16,
      prefixIcon: Icons.playlist_play_rounded,
      options: options,
      hintText: status,
      labelText: "STATUS",
      currentValue: status,
      onChanged: (value) {
        setState(() {
          status = value;
        });
      },
    );
  }

  Widget _buildProgressField(TextStyle labelStyle, TextStyle suffixStyle) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: progressController,
            keyboardType: TextInputType.number,
            style: labelStyle,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "PROGRESS",
              labelStyle: labelStyle,
              suffixText: suffixText,
              suffixStyle: suffixStyle,
              prefixIcon: const Icon(Icons.add_circle_outline_rounded),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            final current = int.tryParse(progressController.text) ?? 0;
            setState(() {
              progressController.text = (current + 1).toString();
            });
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "+1",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreField(TextStyle labelStyle, TextStyle suffixStyle) {
    return TextField(
      controller: scoreController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: labelStyle,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*(\.\d?)?$')),
      ],
      decoration: InputDecoration(
        labelText: "SCORE",
        labelStyle: labelStyle,
        suffixText: "/ 10",
        suffixStyle: suffixStyle,
        prefixIcon: const Icon(Icons.star_rounded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildDatePickerRow(TextStyle suffixStyle) {
    return Row(
      children: [
        Expanded(
          child: _buildDatePicker(
            "Started at",
            suffixStyle,
            startedAt,
            (picked) {
              setState(
                () => startedAt = FuzzyDate(
                  year: picked.year,
                  month: picked.month,
                  day: picked.day,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDatePicker(
            "Completed at",
            suffixStyle,
            completedAt,
            (picked) {
              setState(
                () => completedAt = FuzzyDate(
                  year: picked.year,
                  month: picked.month,
                  day: picked.day,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    String label,
    TextStyle labelStyle,
    FuzzyDate? date,
    Function(DateTime) onDatePicked,
  ) {
    final formatted = date?.getFormattedDate() ?? "";
    return InkWell(
      onTap: () async {
        final initialDate = (date != null && date.year != null)
            ? DateTime(date.year!, date.month ?? 1, date.day ?? 1)
            : DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) onDatePicked(picked);
      },
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: labelStyle,
          prefixIcon: const Icon(Icons.date_range, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
        ),
        child: Text(
          formatted.isNotEmpty ? formatted : "",
          style: labelStyle,
        ),
      ),
    );
  }

  Widget _buildOtherWidget(TextStyle labelStyle, TextStyle suffixStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: repeatController,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          style: labelStyle,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: isAnime ? "Total Rewatches" : "Total Rereads",
            labelStyle: labelStyle,
            suffixStyle: suffixStyle,
            prefixIcon: const Icon(Icons.redo_rounded),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: noteController,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: labelStyle,
          decoration: InputDecoration(
            labelText: "Note",
            labelStyle: labelStyle,
            prefixIcon: const Icon(Icons.edit_note_rounded),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    final score = double.tryParse(scoreController.text);
    final progress = int.tryParse(progressController.text);

    widget.media
      ..userStatus = statusToMal(status, isAnime)
      ..userProgress = progress
      ..userScore = score != null ? (score * 10).toInt().clamp(0, 100) : null;

    if (!widget.isCompact) {
      widget.media
        ..notes = noteController?.text
        ..userStartedAt = startedAt
        ..userCompletedAt = completedAt
        ..userRepeat = int.tryParse(repeatController?.text ?? "0") ?? 0;
    }

    Get.back();
    await TrackSyncManager.instance.syncEditList(
      media: widget.media,
      fromMal: true,
    );
  }

  Future<void> _onDelete() async {
    Get.back();
    await TrackSyncManager.instance.syncDeleteFromList(
      media: widget.media,
      fromMal: true,
    );
  }
}
