import 'dart:async';
import 'package:flutter/material.dart';
import '../../../DataClass/Media.dart';

class MediaCountdownPill extends StatefulWidget {
  final Media mediaInfo;

  const MediaCountdownPill({super.key, required this.mediaInfo});

  @override
  State<MediaCountdownPill> createState() => _MediaCountdownPillState();
}

class _MediaCountdownPillState extends State<MediaCountdownPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MediaCountdownPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaInfo.airingAtTimestamp != widget.mediaInfo.airingAtTimestamp ||
        oldWidget.mediaInfo.timeUntilAiring != widget.mediaInfo.timeUntilAiring) {
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    final remaining = _getRemainingSeconds();
    if (remaining != null && remaining > 0) {
      final interval = remaining > 3600
          ? const Duration(seconds: 30)
          : const Duration(seconds: 1);
      _timer = Timer.periodic(interval, (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int? _getRemainingSeconds() {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int? targetSec = widget.mediaInfo.airingAtTimestamp;

    if (targetSec == null &&
        widget.mediaInfo.timeUntilAiring != null &&
        widget.mediaInfo.timeUntilAiring! > 0) {
      final timeVal = widget.mediaInfo.timeUntilAiring!;
      final deltaSec = timeVal > 100000000 ? (timeVal ~/ 1000) : timeVal;
      targetSec = nowSec + deltaSec;
      widget.mediaInfo.airingAtTimestamp = targetSec;
    }

    if (targetSec == null) return null;
    final diff = targetSec - nowSec;
    return diff > 0 ? diff : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaInfo.cameFromContinue != true &&
        widget.mediaInfo.cameFromHome != true) {
      return const SizedBox.shrink();
    }

    final diffSec = _getRemainingSeconds();
    if (diffSec == null || diffSec <= 0) {
      return const SizedBox.shrink();
    }

    final days = diffSec ~/ 86400;
    final hours = (diffSec % 86400) ~/ 3600;
    final minutes = (diffSec % 3600) ~/ 60;
    final seconds = diffSec % 60;

    String epText;
    if (widget.mediaInfo.relation != null &&
        widget.mediaInfo.relation!.trim().isNotEmpty) {
      epText = widget.mediaInfo.relation!.replaceAll('_', ' ');
    } else if (widget.mediaInfo.anime?.nextAiringEpisode != null) {
      epText = 'Ep ${(widget.mediaInfo.anime!.nextAiringEpisode! + 1)}';
    } else {
      epText = 'Airing';
    }

    String countdownText;
    if (days > 0) {
      countdownText = '$epText • ${days}d ${hours}h';
    } else if (hours > 0) {
      countdownText = '$epText • ${hours}h ${minutes}m';
    } else {
      countdownText = '$epText • ${minutes}m ${seconds}s';
    }

    return Positioned(
      top: 6,
      left: 6,
      right: 6,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
          decoration: BoxDecoration(
            color: const Color(0xB30F0F13), // Saikou bg_countdown_pill #b30f0f13
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: const Color(0x26FFFFFF), // Saikou stroke #26ffffff
              width: 1.0,
            ),
          ),
          child: Text(
            countdownText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.0,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
