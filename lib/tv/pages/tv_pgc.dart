import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/models_new/fav/fav_pgc/list.dart';
import 'package:PiliPlus/models_new/pgc/pgc_index_result/list.dart';
import 'package:PiliPlus/pages/pgc/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/tv/models/tv_video_data.dart';
import 'package:PiliPlus/tv/pages/tv_pgc_detail.dart';
import 'package:PiliPlus/tv/tv_theme.dart';
import 'package:PiliPlus/tv/widgets/tv_feed_grid.dart';
import 'package:PiliPlus/tv/widgets/tv_data_video_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:get/get.dart';

/// TV 番剧: the existing [PgcController] (bangumi tab) data layer rendered
/// through the shared [TvFeedGrid], with a 我的追番 follow rail (the
/// controller's `followState`, logged-in only) above the 番剧 index grid.
/// Cards open the season's [TvPgcDetailPage] and show 3:4 posters, so both
/// the rail and the grid pack [_posterColumns] cards per row.
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

  @override
  void dispose() {
    Get.delete<PgcController>(tag: _controllerTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final followList = _account.isLogin.value
          ? _controller.followState.value.dataOrNull
          : null;
      final showFollow = followList != null && followList.isNotEmpty;
      return Column(
        children: [
          if (showFollow)
            _TvPgcFollowRow(items: followList, autofocusFirst: true),
          Expanded(
            child: TvFeedGrid<PgcIndexItem>(
              controller: _controller,
              toData: TvVideoData.fromPgcIndex,
              onOpen: (item) => _openDetail(item.seasonId),
              // When the follow rail is present it owns first focus.
              autofocusFirst: !showFollow,
              emptyMessage: '暂无番剧内容',
              columns: _posterColumns,
              coverAspectRatio: _posterAspectRatio,
            ),
          ),
        ],
      );
    });
  }
}

/// 番剧 posters are 3:4, so a row fits more cards than the 16:9 video grids.
const int _posterColumns = 7;
const double _posterAspectRatio = 3 / 4;

/// 我的追番 follow rail: a section header over a horizontal list of poster
/// [TvDataVideoCard]s sized like the grid's. Same focus contract as the 直播 follow rail —
/// Left/Right move within the row (clamped at the ends), Up/Down return
/// `ignored` so the page's directional traversal reaches the tab bar / grid.
class _TvPgcFollowRow extends StatefulWidget {
  const _TvPgcFollowRow({required this.items, this.autofocusFirst = false});

  final List<FavPgcItemModel> items;
  final bool autofocusFirst;

  @override
  State<_TvPgcFollowRow> createState() => _TvPgcFollowRowState();
}

class _TvPgcFollowRowState extends State<_TvPgcFollowRow> {
  final List<FocusNode> _focusNodes = [];

  void _syncFocusNodes() {
    while (_focusNodes.length < widget.items.length) {
      _focusNodes.add(
        FocusNode(debugLabel: 'TvPgcFollow-${_focusNodes.length}'),
      );
    }
    while (_focusNodes.length > widget.items.length) {
      _focusNodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    final key = event.logicalKey;
    final isPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) return KeyEventResult.handled; // clamp at start
      if (isPress) _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index >= widget.items.length - 1) {
        return KeyEventResult.handled; // clamp at end
      }
      if (isPress) _focusNodes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    // Up / Down: let the page's directional traversal reach tabs / grid.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _syncFocusNodes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(
            left: TvTheme.screenPadding,
            top: TvTheme.rowHeaderTopGap,
            bottom: TvTheme.rowHeaderBottomGap,
          ),
          child: Text('我的追番', style: TvTheme.sectionHeader),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Same card width as the grid below, so the two line up.
            final cardWidth =
                (constraints.maxWidth -
                    TvTheme.screenPadding * 2 -
                    TvTheme.gridHSpacing * (_posterColumns - 1)) /
                _posterColumns;
            final cardHeight =
                cardWidth / _posterAspectRatio + TvTheme.cardInfoHeight;
            return SizedBox(
              height: cardHeight + TvTheme.heroRowOverscan * 2,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: TvTheme.screenPadding,
                  vertical: TvTheme.heroRowOverscan,
                ),
                itemCount: widget.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: TvTheme.gridHSpacing),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return SizedBox(
                    width: cardWidth,
                    child: TvDataVideoCard(
                      data: TvVideoData.fromFavPgc(item),
                      autofocus: widget.autofocusFirst && index == 0,
                      focusNode: _focusNodes[index],
                      onKeyEvent: (node, event) => _onKey(index, event),
                      onSelect: () => _openDetail(item.seasonId),
                      coverAspectRatio: _posterAspectRatio,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

void _openDetail(int? seasonId) {
  if (seasonId == null) return;
  Get.to(() => TvPgcDetailPage(seasonId: seasonId));
}
