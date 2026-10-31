import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/engine/abstract_media_player.dart';
import 'package:PiliPlus/plugin/pl_player/engine/bili_dash_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

// Hits the real Bilibili API/CDN: a stock libdash sends no Referer, so the
// manifest's BaseURLs must point at the loopback relay, and the relay must turn
// a Range request into a 206 from the CDN (which 403s without the Referer).
void main() {
  test('manifest BaseURLs go through the Referer-injecting relay', () async {
    const String ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    final HttpClient http = HttpClient();
    final HttpClientRequest api = await http.getUrl(Uri.parse(
        'https://api.bilibili.com/x/player/playurl'
        '?bvid=BV1GJ411x7h7&cid=137649199&fnval=16&qn=32'));
    api.headers
      ..set(HttpHeaders.userAgentHeader, ua)
      ..set(HttpHeaders.refererHeader, 'https://www.bilibili.com');
    final Map<String, dynamic> dash = (jsonDecode(
            await (await api.close()).transform(utf8.decoder).join())
        as Map<String, dynamic>)['data']['dash'] as Map<String, dynamic>;
    final String videoUrl = (dash['video'] as List).first['baseUrl'] as String;
    final String audioUrl = (dash['audio'] as List).first['baseUrl'] as String;

    final BiliDashProxy proxy = BiliDashProxy();
    final String mpdUrl = await proxy.urlFor(
      MediaSource(videoUri: videoUrl, audioUri: audioUrl),
      userAgent: ua,
    );
    final HttpClientResponse mpdRes =
        await (await http.getUrl(Uri.parse(mpdUrl))).close();
    final String mpd = await mpdRes.transform(utf8.decoder).join();
    expect(mpdRes.statusCode, HttpStatus.ok);

    final List<String> baseUrls = RegExp(r'<BaseURL>([^<]*)</BaseURL>')
        .allMatches(mpd)
        .map((RegExpMatch m) => m.group(1)!.replaceAll('&amp;', '&'))
        .toList();
    expect(baseUrls, hasLength(2));
    for (final String u in baseUrls) {
      expect(u, startsWith('http://127.0.0.1:${proxy.port}/seg/'));
      final HttpClientRequest seg = await http.getUrl(Uri.parse(u));
      seg.headers.set(HttpHeaders.rangeHeader, 'bytes=0-999');
      final HttpClientResponse segRes = await seg.close();
      final int len = await segRes.fold<int>(0, (int n, List<int> b) => n + b.length);
      expect(segRes.statusCode, HttpStatus.partialContent);
      expect(len, 1000);
    }

    await proxy.stop();
    http.close(force: true);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
