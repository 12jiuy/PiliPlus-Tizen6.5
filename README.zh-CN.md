<div align="center">
    <img width="160" height="160" src="assets/images/logo/logo.png">
    <h1>PiliPlus-Tizen</h1>
    <p><b>三星 Tizen 电视上的哔哩哔哩客户端，全程遥控器方向键操作。</b></p>
</div>

![platform](https://img.shields.io/badge/Tizen-6.5%2B-blue)
![flutter](https://img.shields.io/badge/flutter--tizen-3.44-02569B)
![release](https://img.shields.io/github/v/release/12jiuy/PiliPlus-Tizen6.5)
![license](https://img.shields.io/badge/license-GPL--3.0-green)

<p align="center"><a href="README.md">English</a> · <b>简体中文</b></p>

PiliPlus-Tizen 通过 [`flutter-tizen`](https://github.com/flutter-tizen/flutter-tizen) 把 Flutter 客户端 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 搬到三星智能电视上。本项目基于 [jackie099/PiliPlus-Tizen](https://github.com/jackie099/PiliPlus-Tizen)（最初的 Tizen 9 移植），在此之上做了这些事：适配 **Tizen 6.5** 电视，新增番剧板块和自动连播，并重做了播放链路，让拖动进度条更顺畅。

已在 **三星 QN65S95B（Tizen 6.5）** 上测试。安装包按 API 6.5 打包，理论上更新的 Tizen 电视也能安装。

## 安装

1. 从 [Releases](https://github.com/12jiuy/PiliPlus-Tizen6.5/releases) 下载 `.tpk`。
2. 在电视上开启开发者模式：打开「应用」，用遥控器输入 `12345`，打开 Developer mode，Host PC IP 填你电脑的 IP。
3. 用 Apps2Samsung、Tizen Studio 或 `sdb install <文件>.tpk` 安装。

## 功能

**浏览**
- 首页、热门、搜索、动态、用户页，全部可以用方向键操作
- 番剧 tab 和番剧详情页；在海报上按确认会展开选集条，并自动定位到上次看到的那一集

**播放**
- 最高支持 4K 和 HDR 真彩（HDR10）；三星电视解不了的画质（杜比视界、HDR Vivid、8K）不会出现在画质菜单里
- 进度条：左右键移动目标位置，同时显示缩略图预览，按 OK 只跳转一次。播放时停手 1 秒也会自动跳转；暂停时只有按 OK 才跳，并显示加载动画和加载百分比
- 播放中按 ▼ 打开选集 / 分P 条；换集时沿用同一个播放器，画面不会闪烁
- 番剧自动连播：片尾照常播放，同时弹出"接下来"倒计时卡片，不会直接跳过片尾
- 按 ▲ 打开播放选项：画质、音质、解码格式、弹幕、字幕、章节、画面比例、倍速、播放顺序，以及 CDN 线路（附测速）

## 播放是怎么实现的

Tizen 上没有 libmpv，用不了上游的 `media_kit`，所以改用电视自带的 AVPlay 播放器（[`video_player_avplay`](https://github.com/jackie099/plugins)）。但 AVPlay 没法直接播 B 站的视频：视频和音频是分开的两条 DASH 流；B 站 CDN 要求请求带 `Referer`，AVPlay 又不会带。

[`BiliDashProxy`](lib/plugin/pl_player/engine/bili_dash_proxy.dart) 在 `127.0.0.1` 上解决这些问题：

- 根据两条流生成一份 DASH 清单，写明真实的编码格式，让电视解码器能识别
- 把每个分段请求转发给 CDN，加上 `Referer` / `User-Agent`，并原样传递 `Range`
- 运行在独立的 isolate 里。在 Tizen 上，跳转会卡住平台线程，代理放在别的 isolate 里就不会跟着被卡住
- 把每条流的初始化段缓存在内存里，因为 AVPlay 每次跳转都会重新请求它
- 主节点返回 403 / 5xx，或者 3 秒没有响应时，这一次请求改用 B 站给的备用 CDN 地址

电视界面在 [`lib/tv/`](lib/tv/)，复用了上游的控制器和网络层。所有电视专用的改动都用 `PlatformUtils.isTizen` 隔开，其他平台照常编译，不受影响。

## 编译

需要 [`flutter-tizen`](https://github.com/flutter-tizen/flutter-tizen)（Flutter 3.44）、Tizen SDK，以及用于签名的三星证书 profile。

```bash
sdb connect <电视IP>:26101

# 开发调试
flutter-tizen run -d <电视IP>:26101 --dart-define=IS_TIZEN=true

# 打正式包（输出在 build/tizen/tpk/*.tpk）
flutter-tizen build tpk --release --dart-define=IS_TIZEN=true
```

必须加上 `IS_TIZEN=true`，它会启用电视界面和 AVPlay 播放引擎。App 用 Skia 渲染，不要加 `--enable-impeller`。

---

## 声明

此项目仅用于学习与个人测试，请于下载后 24 小时内删除。所用 API 皆从官方网站收集，不提供任何破解内容。

## 致谢

- [jackie099/PiliPlus-Tizen](https://github.com/jackie099/PiliPlus-Tizen)：最初的 Tizen 移植，包括方向键界面和 DASH 代理
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 及其前身 [PiliPalaX](https://github.com/orz12/PiliPalaX)、[pilipala](https://github.com/guozhigq/pilipala)
- [flutter-tizen](https://github.com/flutter-tizen/flutter-tizen) 与 `video_player_avplay`
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)

## 许可证

[GPL-3.0](LICENSE)，沿用 PiliPlus 的许可证。
