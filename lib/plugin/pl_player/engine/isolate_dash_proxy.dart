import 'dart:async';
import 'dart:isolate';

import 'package:PiliPlus/plugin/pl_player/engine/abstract_media_player.dart';
import 'package:PiliPlus/plugin/pl_player/engine/bili_dash_proxy.dart';

/// Runs a [BiliDashProxy] on its own isolate.
///
/// On Tizen the plugins' platform calls run on the UI thread, and AVPlay's
/// `Seek()` blocks it until the engine's in-flight segment read is done —
/// reads this proxy serves. On the main isolate the proxy was stalled by that
/// very call, so a seek waited out a ~6s timeout (freezing the whole app) and
/// could fail playback. Here it keeps serving while the UI thread is blocked,
/// and media bytes no longer pass through the UI isolate at all.
class IsolateDashProxy implements DashProxy {
  Future<SendPort>? _port;

  Future<SendPort> _spawn() async {
    final ready = ReceivePort();
    await Isolate.spawn(_main, ready.sendPort, debugName: 'BiliDashProxy');
    final port = await ready.first as SendPort;
    ready.close();
    return port;
  }

  /// Runs `proxy.<method>` on the proxy isolate and returns its result.
  Future<String> _call(
    FutureOr<String> Function(BiliDashProxy proxy) method,
  ) async {
    final port = await (_port ??= _spawn());
    final reply = ReceivePort();
    port.send((method, reply.sendPort));
    final result = await reply.first;
    reply.close();
    if (result is String) return result;
    final (Object error, String stack) = result as (Object, String);
    Error.throwWithStackTrace(error, StackTrace.fromString(stack));
  }

  static Future<void> _main(SendPort ready) async {
    final proxy = BiliDashProxy();
    await proxy.start();
    final requests = ReceivePort();
    ready.send(requests.sendPort);
    await for (final message in requests) {
      final (
        FutureOr<String> Function(BiliDashProxy) method,
        SendPort reply,
      ) = message as (FutureOr<String> Function(BiliDashProxy), SendPort);
      try {
        reply.send(await method(proxy));
      } catch (e, s) {
        reply.send((e, s.toString()));
      }
    }
  }

  @override
  Future<String> urlFor(
    MediaSource source, {
    String? referer,
    String? userAgent,
    DashStreamMeta? videoMeta,
    DashStreamMeta? audioMeta,
    Duration? duration,
  }) => _call(
    (proxy) => proxy.urlFor(
      source,
      referer: referer,
      userAgent: userAgent,
      videoMeta: videoMeta,
      audioMeta: audioMeta,
      duration: duration,
    ),
  );

  @override
  Future<String> urlForLiveProgressive(
    String m3u8Url, {
    String? referer,
    String? userAgent,
  }) => _call(
    (proxy) => proxy.urlForLiveProgressive(
      m3u8Url,
      referer: referer,
      userAgent: userAgent,
    ),
  );
}
