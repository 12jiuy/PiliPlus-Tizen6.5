import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart'
    show BaseEpisodeItem;
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/tv/tv_theme.dart';
import 'package:PiliPlus/tv/widgets/tv_pgc_episode_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;

/// In-player 选集 bar, opened with Down: a bottom overlay with every episode
/// (番剧 episodes or UGC 分P) in one horizontal row, scrolled to and focused
/// on the one now playing. Left/Right move along the row (clamped), OK calls
/// [onSelect], and Back / Up / Down call [onClose].
class TvEpisodeBar extends StatefulWidget {
  const TvEpisodeBar({
    super.key,
    required this.episodes,
    required this.currentCid,
    required this.onSelect,
    required this.onClose,
  });

  final List<BaseEpisodeItem> episodes;
  final int? currentCid;
  final ValueChanged<BaseEpisodeItem> onSelect;
  final VoidCallback onClose;

  @override
  State<TvEpisodeBar> createState() => _TvEpisodeBarState();
}

class _TvEpisodeBarState extends State<TvEpisodeBar> {
  static const double _ds = TvTheme.designScale;
  static const double _step = TvPgcEpisodeTile.width + TvPgcEpisodeTile.gap;

  late final int _current = widget.episodes
      .indexWhere((e) => e.cid == widget.currentCid)
      .clamp(0, widget.episodes.length - 1);

  // Start with the current episode about two tiles in from the left, so it is
  // built (and focusable) on the first frame even in a long series.
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: ((_current - 2) * _step).clamp(0, double.infinity),
  );

  late final List<FocusNode> _nodes = List.generate(
    widget.episodes.length,
    (i) => FocusNode(debugLabel: 'TvEpisodeBar-$i'),
  );

  @override
  void initState() {
    super.initState();
    // Focus the current episode explicitly: `autofocus` is a no-op here,
    // since the player page still holds focus in the same scope.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[_current].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    final key = event.logicalKey;
    final isPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0 && isPress) _nodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _nodes.length - 1 && isPress) {
        _nodes[index + 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final episodes = widget.episodes;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: TvTheme.playerBottomGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 80 * _ds, bottom: 40 * _ds),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: TvTheme.screenPadding),
                child: Text(
                  '选集 · 共${episodes.length}集',
                  style: TvTheme.sectionHeader,
                ),
              ),
              SizedBox(
                height: TvPgcEpisodeTile.height + TvTheme.heroRowOverscan * 2,
                child: ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TvTheme.screenPadding,
                    vertical: TvTheme.heroRowOverscan,
                  ),
                  itemCount: episodes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: TvPgcEpisodeTile.gap),
                  itemBuilder: (context, i) {
                    final ep = episodes[i];
                    return TvPgcEpisodeTile(
                      episode: ep is EpisodeItem ? ep : null,
                      label: ep is EpisodeItem ? null : _partLabel(ep, i),
                      highlighted: i == _current,
                      focusNode: _nodes[i],
                      onKeyEvent: (node, event) => _onKey(i, event),
                      onSelect: () => widget.onSelect(ep),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _partLabel(BaseEpisodeItem ep, int i) {
    if (ep is Part) return ep.part ?? '第${ep.page ?? i + 1}P';
    return ep.title ?? '第${i + 1}集';
  }
}
