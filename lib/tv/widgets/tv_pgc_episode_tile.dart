import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/tv/focus/tv_focusable.dart';
import 'package:PiliPlus/tv/tv_theme.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/material.dart';

/// Index of the last-watched episode of [info], or null when nothing was
/// watched (or the episode is not in the main list).
int? tvPgcLastIndex(PgcInfoModel? info) {
  final lastEpId = info?.userStatus?.progress?.lastEpId;
  final episodes = info?.episodes;
  if (lastEpId == null || episodes == null) return null;
  final i = episodes.indexWhere((e) => e.epId == lastEpId);
  return i < 0 ? null : i;
}

/// `第3话` for numbered episodes, otherwise the raw title (e.g. `PV`).
String tvPgcEpLabel(EpisodeItem episode) {
  final title = episode.title ?? '';
  return int.tryParse(title) != null ? '第$title话' : title;
}

/// Plays [episode] of [info] the same way [PageUtils.viewPgc] does; completes
/// when the player page is popped.
Future<void> tvPlayPgcEpisode(PgcInfoModel info, EpisodeItem episode) async {
  await PageUtils.toVideoPage(
    videoType: VideoType.pgc,
    bvid: episode.bvid!,
    cid: episode.cid!,
    seasonId: info.seasonId,
    epId: episode.epId,
    pgcType: info.type,
    cover: episode.cover,
    extraArguments: {'pgcItem': info},
  );
}

/// A focusable episode tile (`第3话` + badge over the episode's long title);
/// a [highlighted] one (last watched / now playing) gets a
/// [TvTheme.brandPink] outline and label. With [label] and no [episode] it is
/// a plain one-line tile (the 更多 tile, UGC 分P).
class TvPgcEpisodeTile extends StatelessWidget {
  const TvPgcEpisodeTile({
    super.key,
    this.episode,
    this.label,
    required this.onSelect,
    this.highlighted = false,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
  }) : assert(episode != null || label != null);

  static const double width = 200 * TvTheme.designScale;
  static const double height = 92 * TvTheme.designScale;
  static const double gap = 16 * TvTheme.designScale;
  static const BorderRadius radius = BorderRadius.all(
    Radius.circular(12 * TvTheme.designScale),
  );

  final EpisodeItem? episode;
  final String? label;
  final VoidCallback onSelect;
  final bool highlighted;
  final bool autofocus;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final episode = this.episode;
    final badge = episode?.badge;
    final longTitle = episode?.longTitle;
    return TvFocusable(
      borderRadius: radius,
      focusScale: TvTheme.focusScaleSmall,
      dimWhenUnfocused: false,
      autofocus: autofocus,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      onSelect: onSelect,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(
          horizontal: 16 * TvTheme.designScale,
          vertical: 12 * TvTheme.designScale,
        ),
        alignment: episode == null ? Alignment.center : null,
        decoration: BoxDecoration(
          color: TvTheme.surface,
          borderRadius: radius,
          border: highlighted
              ? Border.all(
                  color: TvTheme.brandPink,
                  width: 2 * TvTheme.designScale,
                )
              : null,
        ),
        child: episode == null
            ? Text(
                label!,
                style: TvTheme.buttonLabel.copyWith(
                  color: highlighted ? TvTheme.brandPink : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tvPgcEpLabel(episode),
                          style: TvTheme.buttonLabel.copyWith(
                            color: highlighted ? TvTheme.brandPink : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null && badge.isNotEmpty) ...[
                        const SizedBox(width: 8 * TvTheme.designScale),
                        Text(
                          badge,
                          style: TvTheme.cardMeta.copyWith(
                            color: TvTheme.brandPink,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (longTitle != null && longTitle.isNotEmpty)
                    Text(
                      longTitle,
                      style: TvTheme.cardMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
      ),
    );
  }
}
