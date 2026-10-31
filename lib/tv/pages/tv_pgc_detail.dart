import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/tv/focus/tv_focusable.dart';
import 'package:PiliPlus/tv/tv_theme.dart';
import 'package:PiliPlus/tv/widgets/tv_feed_grid.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:flutter/material.dart';

/// TV 番剧 detail: poster + info header, a 继续观看 button, and the season's
/// episodes as a D-pad grid (paged into [_rangeSize]-episode ranges for long
/// series). Picking an episode plays it the same way [PageUtils.viewPgc] does;
/// returning from the player re-fetches the season so the 上次看到 marker and
/// the button follow the new watch progress.
class TvPgcDetailPage extends StatefulWidget {
  const TvPgcDetailPage({super.key, required this.seasonId});

  final int seasonId;

  @override
  State<TvPgcDetailPage> createState() => _TvPgcDetailPageState();
}

class _TvPgcDetailPageState extends State<TvPgcDetailPage> {
  static const double _ds = TvTheme.designScale;
  static const int _rangeSize = 50;
  static const double _posterWidth = 280 * _ds;
  static const double _tileWidth = 200 * _ds;
  static const double _tileHeight = 92 * _ds;
  static const double _tileGap = 16 * _ds;
  static const BorderRadius _tileRadius = BorderRadius.all(
    Radius.circular(12 * _ds),
  );

  LoadingState<PgcInfoModel> _state = LoadingState<PgcInfoModel>.loading();

  /// Index of the episode range shown in the grid.
  int _range = 0;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    final res = await SearchHttp.pgcInfo(seasonId: widget.seasonId);
    if (!mounted) return;
    setState(() {
      _state = res;
      if (initial) {
        final last = _lastIndex(res.dataOrNull);
        if (last != null) _range = last ~/ _rangeSize;
      }
    });
  }

  List<EpisodeItem> _episodes(PgcInfoModel? info) => info?.episodes ?? const [];

  /// Index of the last-watched episode, or null when nothing was watched.
  int? _lastIndex(PgcInfoModel? info) {
    final lastEpId = info?.userStatus?.progress?.lastEpId;
    if (lastEpId == null) return null;
    final i = _episodes(info).indexWhere((e) => e.epId == lastEpId);
    return i < 0 ? null : i;
  }

  Future<void> _play(PgcInfoModel info, EpisodeItem episode) async {
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
    if (mounted) _load();
  }

  /// `第3话` for numbered episodes, otherwise the raw title (e.g. `PV`).
  static String _epLabel(EpisodeItem episode) {
    final title = episode.title ?? '';
    return int.tryParse(title) != null ? '第$title话' : title;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeUtils.darkTheme,
      child: Scaffold(
        backgroundColor: TvTheme.background,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: TvTheme.backgroundGradient),
          child: switch (_state) {
            Loading() => const TvLoadingView(),
            Success(:final response) => _buildContent(response),
            Error(:final errMsg) => TvStatusView(
              message: errMsg ?? '加载失败',
              onRetry: () {
                setState(() => _state = LoadingState<PgcInfoModel>.loading());
                _load(initial: true);
              },
            ),
          },
        ),
      ),
    );
  }

  Widget _buildContent(PgcInfoModel info) {
    final episodes = _episodes(info);
    final last = _lastIndex(info);
    final rangeCount = (episodes.length + _rangeSize - 1) ~/ _rangeSize;
    final start = _range * _rangeSize;
    final end = (start + _rangeSize).clamp(0, episodes.length);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TvTheme.screenPadding,
        48 * _ds,
        TvTheme.screenPadding,
        TvTheme.gridBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(info, episodes, last),
          const SizedBox(height: 40 * _ds),
          Text('选集 · 共${episodes.length}集', style: TvTheme.sectionHeader),
          const SizedBox(height: 16 * _ds),
          if (rangeCount > 1) ...[
            Wrap(
              spacing: _tileGap,
              runSpacing: _tileGap,
              children: [
                for (var r = 0; r < rangeCount; r++)
                  _buildRangeChip(
                    r,
                    '${r * _rangeSize + 1}-'
                    '${((r + 1) * _rangeSize).clamp(0, episodes.length)}',
                  ),
              ],
            ),
            const SizedBox(height: 24 * _ds),
          ],
          if (episodes.isEmpty)
            const Text('暂无可播放的剧集', style: TvTheme.cardMeta)
          else
            Wrap(
              spacing: _tileGap,
              runSpacing: _tileGap,
              children: [
                for (var i = start; i < end; i++)
                  _buildEpisodeTile(info, episodes[i], isLast: i == last),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    PgcInfoModel info,
    List<EpisodeItem> episodes,
    int? last,
  ) {
    final meta = [
      if (info.rating?.score case final score? when score > 0) '$score分',
      ?info.areas?.firstOrNull?.name,
      ?info.newEp?.desc,
    ].join(' · ');
    final resume = last != null ? episodes[last] : episodes.firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NetworkImgLayer(
          src: info.cover,
          width: _posterWidth,
          height: _posterWidth * 4 / 3,
          borderRadius: TvTheme.cardRadius,
        ),
        const SizedBox(width: 48 * _ds),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.title ?? '',
                style: TvTheme.heroTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 12 * _ds),
                Text(meta, style: TvTheme.cardMeta),
              ],
              if (info.evaluate?.isNotEmpty == true) ...[
                const SizedBox(height: 20 * _ds),
                Text(
                  info.evaluate!,
                  style: TvTheme.cardMeta,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (resume != null) ...[
                const SizedBox(height: 32 * _ds),
                TvFocusable(
                  autofocus: true,
                  borderRadius: _tileRadius,
                  focusScale: TvTheme.focusScaleSmall,
                  dimWhenUnfocused: false,
                  onSelect: () => _play(info, resume),
                  child: Container(
                    padding: TvTheme.buttonPadding,
                    decoration: const BoxDecoration(
                      color: Color(0x59FB7299),
                      borderRadius: _tileRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: TvTheme.buttonIconSize,
                          color: TvTheme.textPrimary,
                        ),
                        const SizedBox(width: TvTheme.buttonIconGap),
                        Text(
                          last != null
                              ? '继续观看 ${_epLabel(resume)}'
                              : '开始观看',
                          style: TvTheme.buttonLabel,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeChip(int range, String label) {
    final selected = range == _range;
    return TvFocusable(
      borderRadius: _tileRadius,
      focusScale: TvTheme.focusScaleSmall,
      dimWhenUnfocused: false,
      onSelect: () => setState(() => _range = range),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24 * _ds,
          vertical: 12 * _ds,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0x59FB7299) : TvTheme.surface,
          borderRadius: _tileRadius,
        ),
        child: Text(label, style: TvTheme.buttonLabel),
      ),
    );
  }

  Widget _buildEpisodeTile(
    PgcInfoModel info,
    EpisodeItem episode, {
    required bool isLast,
  }) {
    final badge = episode.badge;
    return TvFocusable(
      borderRadius: _tileRadius,
      focusScale: TvTheme.focusScaleSmall,
      dimWhenUnfocused: false,
      onSelect: () => _play(info, episode),
      child: Container(
        width: _tileWidth,
        height: _tileHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: 16 * _ds,
          vertical: 12 * _ds,
        ),
        decoration: BoxDecoration(
          color: TvTheme.surface,
          borderRadius: _tileRadius,
          border: isLast
              ? Border.all(color: TvTheme.brandPink, width: 2 * _ds)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _epLabel(episode),
                    style: TvTheme.buttonLabel.copyWith(
                      color: isLast ? TvTheme.brandPink : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null && badge.isNotEmpty) ...[
                  const SizedBox(width: 8 * _ds),
                  Text(
                    badge,
                    style: TvTheme.cardMeta.copyWith(color: TvTheme.brandPink),
                  ),
                ],
              ],
            ),
            if (episode.longTitle?.isNotEmpty == true)
              Text(
                episode.longTitle!,
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
