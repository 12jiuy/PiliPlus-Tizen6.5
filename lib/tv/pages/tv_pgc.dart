import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/pages/pgc/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/tv/models/tv_video_data.dart';
import 'package:PiliPlus/tv/pages/tv_pgc_detail.dart';
import 'package:PiliPlus/tv/tv_theme.dart';
import 'package:PiliPlus/tv/widgets/tv_data_video_card.dart';
import 'package:PiliPlus/tv/widgets/tv_feed_grid.dart';
import 'package:PiliPlus/tv/widgets/tv_pgc_episode_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:get/get.dart';

/// 番剧 posters are 3:4, so a row fits more cards than the 16:9 video grids.
const int _posterColumns = 7;
const double _posterAspectRatio = 3 / 4;

/// How many episodes the inline strip shows before its 更多 tile.
const int _stripEpisodes = 12;

/// Which poster has its episode strip open: one in the 我的追番 rail, or one
/// in the grid (by item index).
typedef _Expanded = ({bool inRail, int index, int seasonId});

/// TV 番剧: the existing [PgcController] (bangumi tab) data layer as a
/// 我的追番 rail (the controller's `followState`, logged-in only) over the
/// 番剧 index grid, all with 3:4 posters.
///
/// OK on a poster opens an inline episode strip under its row, focused on the
/// last-watched episode and ending in a 更多 tile that opens the season's
/// [TvPgcDetailPage]; OK on the same poster again, or Back inside the strip,
/// closes it. Because the strip sits between grid rows, this page lays the
/// grid out itself (rows in a [CustomScrollView]) instead of using
/// [TvFeedGrid], and moves focus explicitly around the strip.
class TvPgc extends StatefulWidget {
  const TvPgc({super.key});

  @override
  State<TvPgc> createState() => _TvPgcState();
}

class _TvPgcState extends State<TvPgc> {
  static const _controllerTag = 'tv-pgc';
  final AccountService _account = Get.find<AccountService>();
  final PgcController _controller = Get.put(
    PgcController(tabType: HomeTabType.bangumi),
    tag: _controllerTag,
  );

  final List<FocusNode> _railNodes = [];
  final List<FocusNode> _gridNodes = [];

  /// The strip tile that receives focus when entering the strip (the
  /// last-watched episode, else the first one).
  final FocusNode _stripEntryNode = FocusNode(debugLabel: 'TvPgcStrip-entry');

  _Expanded? _expanded;
  LoadingState<PgcInfoModel>? _info;

  /// Guards against a slow pgcInfo response for a strip that was since
  /// closed or moved to another poster.
  int _request = 0;

  @override
  void dispose() {
    for (final node in [..._railNodes, ..._gridNodes, _stripEntryNode]) {
      node.dispose();
    }
    Get.delete<PgcController>(tag: _controllerTag);
    super.dispose();
  }

  static void _syncNodes(List<FocusNode> nodes, int count, String label) {
    while (nodes.length < count) {
      nodes.add(FocusNode(debugLabel: '$label-${nodes.length}'));
    }
    while (nodes.length > count) {
      nodes.removeLast().dispose();
    }
  }

  // --------------------------------------------------------------- strip --

  Future<void> _toggleStrip(bool inRail, int index, int? seasonId) async {
    if (seasonId == null) return;
    final current = _expanded;
    if (current != null &&
        current.inRail == inRail &&
        current.index == index) {
      _closeStrip();
      return;
    }
    setState(() {
      _expanded = (inRail: inRail, index: index, seasonId: seasonId);
      _info = null;
    });
    await _loadInfo(focusEntry: true);
  }

  Future<void> _loadInfo({bool focusEntry = false}) async {
    final expanded = _expanded;
    if (expanded == null) return;
    final request = ++_request;
    final res = await SearchHttp.pgcInfo(seasonId: expanded.seasonId);
    if (!mounted || request != _request) return;
    setState(() => _info = res);
    if (focusEntry && res is Success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _stripEntryNode.context != null) {
          _stripEntryNode.requestFocus();
        }
      });
    }
  }

  void _closeStrip() {
    final expanded = _expanded;
    if (expanded == null) return;
    _request++;
    setState(() {
      _expanded = null;
      _info = null;
    });
    _posterNode(expanded)?.requestFocus();
  }

  FocusNode? _posterNode(_Expanded expanded) {
    final nodes = expanded.inRail ? _railNodes : _gridNodes;
    return expanded.index < nodes.length ? nodes[expanded.index] : null;
  }

  bool get _stripReady =>
      _info is Success && _stripEntryNode.context != null;

  Future<void> _play(PgcInfoModel info, int episodeIndex) async {
    await tvPlayPgcEpisode(info, info.episodes![episodeIndex]);
    // Refresh so the strip's 上次看到 marker follows the new progress.
    if (mounted) _loadInfo();
  }

  void _openDetail(int seasonId) {
    Get.to(() => TvPgcDetailPage(seasonId: seasonId));
  }

  // ----------------------------------------------------------------- keys --

  KeyEventResult _onRailKey(int index, KeyEvent event) {
    final key = event.logicalKey;
    final isPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0 && isPress) _railNodes[index - 1].requestFocus();
      return KeyEventResult.handled; // clamp at start
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _railNodes.length - 1 && isPress) {
        _railNodes[index + 1].requestFocus();
      }
      return KeyEventResult.handled; // clamp at end
    }
    if (key == LogicalKeyboardKey.arrowDown &&
        _expanded?.inRail == true &&
        _stripReady) {
      if (isPress) _stripEntryNode.requestFocus();
      return KeyEventResult.handled;
    }
    // Up / Down: let the page's directional traversal reach tabs / grid.
    return KeyEventResult.ignored;
  }

  KeyEventResult _onGridKey(int index, KeyEvent event) {
    final key = event.logicalKey;
    final isPress = event is KeyDownEvent || event is KeyRepeatEvent;
    final row = index ~/ _posterColumns;
    final expanded = _expanded;
    final expandedRow = expanded != null && !expanded.inRail
        ? expanded.index ~/ _posterColumns
        : null;
    FocusNode? target;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_stripReady &&
          ((expandedRow != null && expandedRow == row - 1) ||
              (row == 0 && expanded?.inRail == true))) {
        target = _stripEntryNode;
      } else if (index - _posterColumns >= 0) {
        target = _gridNodes[index - _posterColumns];
      } else {
        return KeyEventResult.ignored; // up to the rail / tab bar
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (_stripReady && expandedRow == row) {
        target = _stripEntryNode;
      } else if (index + _posterColumns < _gridNodes.length) {
        target = _gridNodes[index + _posterColumns];
      } else if (row < (_gridNodes.length - 1) ~/ _posterColumns) {
        target = _gridNodes.last; // into the shorter last row
      } else {
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (index % _posterColumns == 0) return KeyEventResult.ignored;
      target = _gridNodes[index - 1];
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (index % _posterColumns == _posterColumns - 1 ||
          index + 1 >= _gridNodes.length) {
        return KeyEventResult.handled;
      }
      target = _gridNodes[index + 1];
    } else {
      return KeyEventResult.ignored;
    }

    if (isPress) target.requestFocus();
    return KeyEventResult.handled;
  }

  /// Up/Down/Back out of the strip; Left/Right are handled by the strip.
  KeyEventResult _onStripExit(KeyEvent event) {
    final key = event.logicalKey;
    final isPress = event is KeyDownEvent || event is KeyRepeatEvent;
    final expanded = _expanded;
    if (expanded == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) _closeStrip();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (isPress) _posterNode(expanded)?.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (expanded.inRail) {
        if (_gridNodes.isNotEmpty && isPress) _gridNodes.first.requestFocus();
      } else {
        final below = expanded.index + _posterColumns;
        if (below < _gridNodes.length) {
          if (isPress) _gridNodes[below].requestFocus();
        } else {
          final nextRowStart =
              (expanded.index ~/ _posterColumns + 1) * _posterColumns;
          if (nextRowStart < _gridNodes.length && isPress) {
            _gridNodes.last.requestFocus();
          }
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            (constraints.maxWidth -
                TvTheme.screenPadding * 2 -
                TvTheme.gridHSpacing * (_posterColumns - 1)) /
            _posterColumns;
        final cardHeight =
            cardWidth / _posterAspectRatio + TvTheme.cardInfoHeight;
        return Obx(() {
          final followList = _account.isLogin.value
              ? _controller.followState.value.dataOrNull
              : null;
          final showFollow = followList != null && followList.isNotEmpty;
          final gridState = _controller.loadingState.value;
          _syncNodes(_railNodes, showFollow ? followList.length : 0, 'Rail');
          final expanded = _expanded;
          return CustomScrollView(
            controller: _controller.scrollController,
            scrollCacheExtent: ScrollCacheExtent.pixels(cardHeight * 2),
            slivers: [
              if (showFollow) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: TvTheme.screenPadding,
                      top: TvTheme.rowHeaderTopGap,
                      bottom: TvTheme.rowHeaderBottomGap,
                    ),
                    child: Text('我的追番', style: TvTheme.sectionHeader),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: cardHeight + TvTheme.heroRowOverscan * 2,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: TvTheme.screenPadding,
                        vertical: TvTheme.heroRowOverscan,
                      ),
                      itemCount: followList.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: TvTheme.gridHSpacing),
                      itemBuilder: (context, index) {
                        final item = followList[index];
                        return SizedBox(
                          width: cardWidth,
                          child: TvDataVideoCard(
                            data: TvVideoData.fromFavPgc(item),
                            autofocus: index == 0,
                            focusNode: _railNodes[index],
                            onKeyEvent: (node, event) =>
                                _onRailKey(index, event),
                            onSelect: () =>
                                _toggleStrip(true, index, item.seasonId),
                            coverAspectRatio: _posterAspectRatio,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (expanded?.inRail == true)
                  SliverToBoxAdapter(child: _buildStrip(expanded!)),
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: TvTheme.gridTopPadding),
              ),
              ..._buildGrid(
                gridState,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                autofocusFirst: !showFollow,
              ),
            ],
          );
        });
      },
    );
  }

  List<Widget> _buildGrid(
    LoadingState<List<PgcIndexItem>?> state, {
    required double cardWidth,
    required double cardHeight,
    required bool autofocusFirst,
  }) {
    switch (state) {
      case Loading():
        _syncNodes(_gridNodes, 0, 'Grid');
        return const [SliverFillRemaining(child: TvLoadingView())];
      case Error(:final errMsg):
        _syncNodes(_gridNodes, 0, 'Grid');
        return [
          SliverFillRemaining(
            child: TvStatusView(
              message: errMsg ?? '加载失败',
              onRetry: _controller.onReload,
            ),
          ),
        ];
      case Success(:final response):
        final items = response ?? const <PgcIndexItem>[];
        _syncNodes(_gridNodes, items.length, 'Grid');
        if (items.isEmpty) {
          return [
            SliverFillRemaining(
              child: TvStatusView(
                message: '暂无番剧内容',
                onRetry: _controller.onReload,
              ),
            ),
          ];
        }
        final rows = (items.length + _posterColumns - 1) ~/ _posterColumns;
        final expanded = _expanded;
        return [
          SliverPadding(
            padding: const EdgeInsets.only(
              bottom: TvTheme.gridBottomPadding,
            ),
            sliver: SliverList.builder(
              itemCount: rows,
              itemBuilder: (context, row) {
                // Fetch the next page when the last rows come into build
                // range (queryData is re-entrancy-guarded by isLoading).
                if (row >= rows - 2) _controller.onLoadMore();
                final start = row * _posterColumns;
                final end = (start + _posterColumns).clamp(0, items.length);
                final hasStrip =
                    expanded != null &&
                    !expanded.inRail &&
                    expanded.index ~/ _posterColumns == row;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TvTheme.screenPadding,
                        0,
                        TvTheme.screenPadding,
                        TvTheme.gridVSpacing,
                      ),
                      child: Row(
                        children: [
                          for (var i = start; i < end; i++) ...[
                            if (i > start)
                              const SizedBox(width: TvTheme.gridHSpacing),
                            SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: TvDataVideoCard(
                                data: TvVideoData.fromPgcIndex(items[i]),
                                autofocus: autofocusFirst && i == 0,
                                focusNode: _gridNodes[i],
                                onKeyEvent: (node, event) =>
                                    _onGridKey(i, event),
                                onSelect: () => _toggleStrip(
                                  false,
                                  i,
                                  items[i].seasonId,
                                ),
                                coverAspectRatio: _posterAspectRatio,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasStrip) _buildStrip(expanded),
                  ],
                );
              },
            ),
          ),
        ];
    }
  }

  Widget _buildStrip(_Expanded expanded) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TvTheme.gridVSpacing),
      child: _TvPgcEpisodeStrip(
        key: ValueKey(expanded),
        info: _info,
        entryNode: _stripEntryNode,
        onExitKey: _onStripExit,
        onPlay: _play,
        onMore: () => _openDetail(expanded.seasonId),
      ),
    );
  }
}

/// The inline episode strip: a header line and a horizontal row of up to
/// [_stripEpisodes] episodes starting two before the last-watched one, which
/// owns [entryNode], then a 更多 tile. Left/Right move along the row (clamped);
/// every other key goes to [onExitKey].
class _TvPgcEpisodeStrip extends StatefulWidget {
  const _TvPgcEpisodeStrip({
    super.key,
    required this.info,
    required this.entryNode,
    required this.onExitKey,
    required this.onPlay,
    required this.onMore,
  });

  final LoadingState<PgcInfoModel>? info;
  final FocusNode entryNode;
  final KeyEventResult Function(KeyEvent event) onExitKey;
  final void Function(PgcInfoModel info, int episodeIndex) onPlay;
  final VoidCallback onMore;

  @override
  State<_TvPgcEpisodeStrip> createState() => _TvPgcEpisodeStripState();
}

class _TvPgcEpisodeStripState extends State<_TvPgcEpisodeStrip> {
  static const double _height =
      TvPgcEpisodeTile.height + TvTheme.heroRowOverscan * 2;

  final List<FocusNode> _ownNodes = [];

  @override
  void dispose() {
    for (final node in _ownNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// One node per tile; the entry tile uses the parent's [entryNode].
  List<FocusNode> _nodes(int count, int entry) {
    while (_ownNodes.length < count) {
      _ownNodes.add(FocusNode(debugLabel: 'TvPgcStrip-${_ownNodes.length}'));
    }
    return [
      for (var i = 0; i < count; i++)
        i == entry ? widget.entryNode : _ownNodes[i],
    ];
  }

  KeyEventResult _onKey(List<FocusNode> nodes, int index, KeyEvent event) {
    final key = event.logicalKey;
    final isPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0 && isPress) nodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < nodes.length - 1 && isPress) nodes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    return widget.onExitKey(event);
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return switch (info) {
      null || Loading() => const SizedBox(
        height: _height,
        child: TvLoadingView(),
      ),
      Error(:final errMsg) => SizedBox(
        height: _height,
        child: Center(
          child: Text(errMsg ?? '加载失败', style: TvTheme.cardMeta),
        ),
      ),
      Success(:final response) => _buildRow(response),
    };
  }

  Widget _buildRow(PgcInfoModel info) {
    final episodes = info.episodes ?? const [];
    final last = tvPgcLastIndex(info);
    final focusIndex = last ?? 0;
    final start = (focusIndex - 2).clamp(
      0,
      (episodes.length - _stripEpisodes).clamp(0, episodes.length),
    );
    final end = (start + _stripEpisodes).clamp(0, episodes.length);
    // Tiles: episodes [start, end) then 更多; entry = the focus episode, or
    // 更多 when the season has no playable episodes.
    final count = end - start + 1;
    final entry = episodes.isEmpty ? count - 1 : focusIndex - start;
    final nodes = _nodes(count, entry);
    final meta = [
      ?info.title,
      if (episodes.isNotEmpty) '共${episodes.length}集',
      ?info.newEp?.desc,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: TvTheme.screenPadding),
          child: Text(meta, style: TvTheme.cardMeta),
        ),
        SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TvTheme.screenPadding,
              vertical: TvTheme.heroRowOverscan,
            ),
            itemCount: count,
            separatorBuilder: (_, _) =>
                const SizedBox(width: TvPgcEpisodeTile.gap),
            itemBuilder: (context, i) {
              if (i == count - 1) {
                return TvPgcEpisodeTile(
                  label: '更多 ›',
                  focusNode: nodes[i],
                  onKeyEvent: (node, event) => _onKey(nodes, i, event),
                  onSelect: widget.onMore,
                );
              }
              final index = start + i;
              return TvPgcEpisodeTile(
                episode: episodes[index],
                highlighted: index == last,
                focusNode: nodes[i],
                onKeyEvent: (node, event) => _onKey(nodes, i, event),
                onSelect: () => widget.onPlay(info, index),
              );
            },
          ),
        ),
      ],
    );
  }
}
