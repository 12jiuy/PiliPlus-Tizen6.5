import 'package:flutter/material.dart';
import 'package:video_player_avplay/video_player.dart';

/// Covers a freshly created AVPlay [controller]'s video Hole with black until
/// the player is actually putting frames on its overlay. A new player's
/// display ROI only takes effect once it renders, so revealing the Hole on
/// `isInitialized` would briefly show the screen behind the app. "Rendering"
/// is taken as: playing, and the position has advanced past where playback
/// started (which also skips over a start-position seek).
/// Key it by [controller] so each player starts covered.
class TizenRevealCover extends StatefulWidget {
  const TizenRevealCover({
    super.key,
    required this.controller,
    required this.child,
  });

  final VideoPlayerController controller;
  final Widget child;

  @override
  State<TizenRevealCover> createState() => _TizenRevealCoverState();
}

class _TizenRevealCoverState extends State<TizenRevealCover> {
  bool _revealed = false;

  /// Position when playback was first seen running.
  Duration? _playStart;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onValue);
  }

  void _onValue() {
    final value = widget.controller.value;
    if (!value.isInitialized || !value.isPlaying) return;
    final start = _playStart ??= value.position;
    if (value.position > start) {
      widget.controller.removeListener(_onValue);
      setState(() => _revealed = true);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_revealed) const ColoredBox(color: Colors.black),
      ],
    );
  }
}
