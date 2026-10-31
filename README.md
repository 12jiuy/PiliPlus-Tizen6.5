<div align="center">
    <img width="160" height="160" src="assets/images/logo/logo.png">
    <h1>PiliPlus-Tizen</h1>
    <p><b>A Bilibili client for Samsung Tizen TVs, driven by the remote's D-pad.</b></p>
</div>

![platform](https://img.shields.io/badge/Tizen-6.5%2B-blue)
![flutter](https://img.shields.io/badge/flutter--tizen-3.44-02569B)
![release](https://img.shields.io/github/v/release/12jiuy/PiliPlus-Tizen6.5)
![license](https://img.shields.io/badge/license-GPL--3.0-green)

<p align="center"><b>English</b> · <a href="README.zh-CN.md">简体中文</a></p>

PiliPlus-Tizen brings the [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) Flutter client to Samsung smart TVs through [`flutter-tizen`](https://github.com/flutter-tizen/flutter-tizen). It builds on [jackie099/PiliPlus-Tizen](https://github.com/jackie099/PiliPlus-Tizen), the original Tizen 9 port, and extends it to **Tizen 6.5** TVs, with a 番剧 (anime/drama) section, continuous playback, and a reworked playback pipeline for smoother seeking.

Tested on a **Samsung QN65S95B (Tizen 6.5)**. The package targets API 6.5, so it should also install on newer Tizen TVs.

## Install

1. Download the `.tpk` from [Releases](https://github.com/12jiuy/PiliPlus-Tizen6.5/releases).
2. Enable developer mode on the TV (Apps → enter `12345` → Developer mode On, Host PC IP = your computer).
3. Install it with Apps2Samsung, Tizen Studio, or `sdb install <file>.tpk`.

## Features

**Browsing**
- Home, trending, search, dynamics and user pages, all navigable with the D-pad
- 番剧 tab and season pages; a poster opens an inline episode row that starts at the episode you last watched

**Playback**
- Up to 4K and HDR 真彩 (HDR10); the quality menu hides what Samsung TVs cannot decode (Dolby Vision, HDR Vivid, 8K)
- Scrubber: Left/Right move a target with a thumbnail preview, and a single seek is committed on OK. While playing it also commits after a second of inactivity; while paused only OK commits, and a loading indicator shows the load's progress
- Press Down in the player for the episode / 分P bar; switching episodes keeps the same player, so the picture doesn't flash
- 番剧 auto-advance: when the ending starts, it keeps playing with an "Up next" countdown card instead of being skipped
- Options panel (Up): quality, audio, decoder, danmaku, subtitles, chapters, aspect ratio, speed, play order, CDN line with speed test

## How playback works

Tizen has no libmpv, so upstream's `media_kit` engine is replaced by the TV's native AVPlay player ([`video_player_avplay`](https://github.com/jackie099/plugins)). AVPlay can't play Bilibili's streams directly: video and audio come as separate DASH files, and the CDN rejects requests without a `Referer` header, which AVPlay does not send.

[`BiliDashProxy`](lib/plugin/pl_player/engine/bili_dash_proxy.dart) bridges that gap on `127.0.0.1`:

- Generates a DASH manifest for the two streams, with their real codecs, so the TV decoder accepts them
- Relays every segment request to the CDN with `Referer` / `User-Agent` added and `Range` passed through
- Runs on its own isolate, so a seek (which blocks the platform thread on Tizen) never waits on the proxy
- Keeps each stream's init segment in memory, since AVPlay re-requests it after every seek
- Retries a request on Bilibili's backup CDN URL when the primary answers 403 / 5xx or doesn't respond within 3 s

The TV UI lives in [`lib/tv/`](lib/tv/). It reuses upstream's controllers and networking, and every TV-specific change is gated behind `PlatformUtils.isTizen`, so the other platforms build as before.

## Build

Requires [`flutter-tizen`](https://github.com/flutter-tizen/flutter-tizen) (Flutter 3.44), the Tizen SDK, and a Samsung certificate profile for signing.

```bash
sdb connect <TV_IP>:26101

# development
flutter-tizen run -d <TV_IP>:26101 --dart-define=IS_TIZEN=true

# release package (build/tizen/tpk/*.tpk)
flutter-tizen build tpk --release --dart-define=IS_TIZEN=true
```

`IS_TIZEN=true` is required: it switches on the TV UI and the AVPlay engine. The app renders with Skia, so don't pass `--enable-impeller`.

---

## Disclaimer

This project is for learning and personal testing only. Please delete it within 24 hours of downloading. All APIs are collected from Bilibili's official website; no cracked content is provided.

## Credits

- [jackie099/PiliPlus-Tizen](https://github.com/jackie099/PiliPlus-Tizen): the original Tizen port, its D-pad UI and the DASH proxy
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) and its lineage, [PiliPalaX](https://github.com/orz12/PiliPalaX) and [pilipala](https://github.com/guozhigq/pilipala)
- [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) and `video_player_avplay`
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)

## License

[GPL-3.0](LICENSE), inherited from PiliPlus.
