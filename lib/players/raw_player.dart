import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../models/app.dart';
import '../subs/ass.dart';
import '../subs/raw.dart';
import '../wsdata.dart';
import 'abstract_player.dart';

class RawPlayer extends AbstractPlayer {
  VideoPlayerController? controller;
  final AppModel app;
  final Function() onNotify;

  RawPlayer(this.app, this.onNotify);

  @override
  String getPlayerType() => 'RawType';

  @override
  bool isSupportedLink(String url) {
    return false;
  }

  @override
  Future<void> loadVideo(VideoList item) async {
    var url = item.url;
    if (url.startsWith('/')) {
      final relativeHost = app.getChannelLink();
      url = '$relativeHost${url}';
    }

    final prevController = controller;
    controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: true,
      ),
    );
    controller!.addListener(onNotify);
    await controller!.initialize();
    prevController?.dispose();

    final captions = await _loadCaptions(item);
    if (captions != null) {
      await controller!.setClosedCaptionFile(Future.value(captions));
    }
  }

  @override
  void removeVideo() {
    controller?.dispose();
    controller = null;
  }

  @override
  bool isVideoLoaded() => controller?.value.isInitialized ?? false;

  @override
  void play() => controller?.play();

  @override
  void pause() => controller?.pause();

  @override
  bool isPaused() => !(controller?.value.isPlaying ?? false);

  @override
  Future<Duration> getPosition() async {
    return await controller?.position ?? Duration.zero;
  }

  @override
  void seekTo(Duration duration) => controller?.seekTo(duration);

  @override
  Future<double> getPlaybackRate() async =>
      controller?.value.playbackSpeed ?? 1.0;

  @override
  void setPlaybackRate(double rate) => controller?.setPlaybackSpeed(rate);

  @override
  void setVolume(double volume) => controller?.setVolume(volume);

  @override
  double get aspectRatio => controller?.value.aspectRatio ?? 16 / 9;

  @override
  String get captionText => controller?.value.caption.text ?? '';

  @override
  Future<double> getVideoDuration(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds / 1000;
      await controller.dispose();
      return duration;
    } catch (e) {
      print(e);
      return 0;
    }
  }

  @override
  Future<String> getVideoTitle(String url) async {
    final matchName = RegExp(r'^(.+)\.(.+)');
    final decodedUrl = Uri.decodeFull(url);
    var title = decodedUrl.substring(decodedUrl.lastIndexOf('/') + 1);
    final isNameMatched = matchName.hasMatch(title);
    if (isNameMatched)
      title = matchName.stringMatch(title)!;
    else
      title = 'Raw Video';
    return title;
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null) return Container();
    return VideoPlayer(controller!);
  }

  @override
  void dispose() {
    controller?.removeListener(onNotify);
    controller?.dispose();
  }

  Future<ClosedCaptionFile?> _loadCaptions(VideoList item) async {
    var subsUrl = item.subs ?? '';
    if (subsUrl.isEmpty) return null;
    if (subsUrl.startsWith('/')) {
      final relativeHost = app.getChannelLink();
      subsUrl = '$relativeHost${subsUrl}';
    }
    if (!subsUrl.startsWith('http')) {
      subsUrl = 'http://$subsUrl';
    }
    return compute(_loadCaptionsFuture, subsUrl);
  }

  static Future<ClosedCaptionFile> _loadCaptionsFuture(String url) async {
    http.Response response;
    try {
      response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
    } catch (_) {
      return RawCaptionFile([]);
    }
    if (response.statusCode == 200) {
      var data = utf8.decode(response.bodyBytes);
      if (url.endsWith('.srt')) {
        data = _parseSrt(data);
        return WebVTTCaptionFile(data);
      } else if (url.endsWith('.vtt')) {
        return WebVTTCaptionFile(data);
      } else {
        return AssCaptionFile(data);
      }
    } else {
      return RawCaptionFile([]);
    }
  }

  static String _parseSrt(String text) {
    final subs = <Map<String, String>>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final blocks = _getSrtBlocks(lines);
    final badTimeReg = RegExp(r'(,[\d]+)');

    for (final lines in blocks) {
      if (lines.length < 3) continue;
      final textLines = lines.getRange(2, lines.length).toList();
      final time = lines[1].replaceAllMapped(badTimeReg, (match) {
        final ms = match.group(1)!;
        return ms.length < 4 ? ms.padRight(4, '0') : ms;
      });
      final normalizedTime = time.replaceAll(',', '.');

      final text = textLines.join('\n').trim();
      subs.add({
        'counter': lines[0],
        'time': normalizedTime,
        'text': text,
      });
    }

    var data = 'WEBVTT\n\n';
    for (final sub in subs) {
      data += '${sub['counter']}\n';
      data += '${sub['time']}\n';
      data += '${sub['text']}\n\n';
    }
    return data;
  }

  static List<List<String>> _getSrtBlocks(List<String> lines) {
    final blocks = <List<String>>[];
    final isNumLineReg = RegExp(r'^(\d+)$');
    var block = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (blocks.isEmpty && line.isEmpty) continue;
      final prevLine = i > 0 ? lines[i - 1] : '';
      final nextLine = i < lines.length - 1 ? lines[i + 1] : '';
      if (prevLine.isEmpty &&
          isNumLineReg.hasMatch(line) &&
          nextLine.contains('-->')) {
        if (block.isNotEmpty) {
          blocks.add(block);
          block = [];
        }
      }
      block.add(line);
    }
    if (block.isNotEmpty) blocks.add(block);
    return blocks;
  }
}
