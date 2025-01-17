import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../chat.dart';
import './app.dart';
import './playlist.dart';
import '../subs/ass.dart';
import '../subs/raw.dart';
import '../wsdata.dart';

class PlayerModel extends ChangeNotifier {
  VideoPlayerController? controller;
  Future<void>? initPlayerFuture;
  final AppModel app;
  final PlaylistModel playlist;

  bool showControls = false;
  Timer? controlsTimer;

  bool _showMessageIcon = false;
  bool get showMessageIcon => _showMessageIcon;

  set showMessageIcon(bool showMessageIcon) {
    if (_showMessageIcon == showMessageIcon) return;
    _showMessageIcon = showMessageIcon;
    notifyListeners();
  }

  bool _isFitWidth = false;
  bool get isFitWidth => _isFitWidth;

  set isFitWidth(bool isFitWidth) {
    if (_isFitWidth == isFitWidth) return;
    _isFitWidth = isFitWidth;
    notifyListeners();
  }

  PlayerModel(this.app, this.playlist);

  bool isVideoLoaded() {
    return controller?.value.isInitialized ?? false;
  }

  bool isPlaying() {
    return controller?.value.isPlaying ?? false;
  }

  void toggleControls(bool flag) {
    if (showControls == flag) return;
    showControls = flag;
    notifyListeners();
  }

  void hideControlsWithDelay() {
    if (!showControls) return;
    controlsTimer?.cancel();
    controlsTimer = Timer(
      const Duration(milliseconds: 2500),
      () => toggleControls(false),
    );
  }

  void cancelControlsHide() {
    if (!showControls) return;
    controlsTimer?.cancel();
  }

  Future<Duration> getPosition() async {
    if (!isVideoLoaded()) return Duration();
    final posD = await controller?.position;
    if (posD == null) return Duration();
    return posD;
  }

  void pause() async {
    if (!isVideoLoaded()) return;
    await controller?.pause();
  }

  void play() async {
    if (!isVideoLoaded()) return;
    if (app.isInBackground) {
      if (!app.hasBackgroundAudio) return;
    }
    await controller?.play();
  }

  void seekTo(Duration duration) async {
    if (!isVideoLoaded()) return;
    await controller?.seekTo(duration);
  }

  Future<double> getPlaybackSpeed() async {
    if (!isVideoLoaded()) return 1.0;
    return controller?.value.playbackSpeed ?? 1.0;
  }

  void setPlaybackSpeed(double rate) async {
    if (!isVideoLoaded()) return;
    await controller?.setPlaybackSpeed(rate);
  }

  double getDuration() {
    final item = playlist.getItem(playlist.pos);
    if (item == null) return 0;
    return item.duration;
  }

  bool isIframe() {
    final item = playlist.getItem(playlist.pos);
    if (item == null) return false;
    return item.playerType == "IframeType";
  }

  String getCurrentItemTitle() {
    final item = playlist.getItem(playlist.pos);
    if (item == null) return '';
    return item.title;
  }

  void loadVideo(int pos) async {
    playlist.setPos(pos);
    initPlayerFuture = null;
    final item = playlist.getItem(playlist.pos);
    if (item == null) return;
    if (isIframe()) {
      final old = controller;
      controller = null;
      initPlayerFuture = Future.microtask(() => null);
      notifyListeners();
      initPlayerFuture?.whenComplete(() {
        Future.delayed(const Duration(seconds: 1), () => old?.dispose());
      });
      return;
    }
    var url = item.url;
    if (url.startsWith('/')) {
      final relativeHost = app.getChannelLink();
      url = '$relativeHost${url}';
    }
    if (url.contains('youtu')) url = await getYoutubeVideoUrl(url);
    pause();
    final prevController = controller;
    controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      // closedCaptionFile: _loadCaptions(item),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: true,
      ),
    );
    controller?.addListener(notifyListeners);
    initPlayerFuture = controller?.initialize();
    initPlayerFuture?.whenComplete(() {
      prevController?.dispose();
      controller?.setClosedCaptionFile(_loadCaptions(item)).whenComplete(() {
        notifyListeners();
      });
      app.send(WsData(
        type: 'VideoLoaded',
      ));
    });
    // app.chat.addItem(ChatItem('', 'VideoLoaded'))
    _isFitWidth = false;
    notifyListeners();
  }

  Future<double> getVideoDuration(String url) async {
    if (url.contains('youtu')) url = await getYoutubeVideoUrl(url);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    Duration? duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
      controller.dispose();
    } catch (e) {
      print(e.toString());
    }
    if (duration == null) return 0;
    return duration.inMilliseconds / 1000;
  }

  static String extractVideoId(String url) {
    if (url.contains('youtu.be/')) {
      return RegExp(r'youtu.be\/([A-z0-9_-]+)').firstMatch(url)!.group(1)!;
    }
    if (url.contains('youtube.com/embed/')) {
      return RegExp(r'embed\/([A-z0-9_-]+)').firstMatch(url)!.group(1)!;
    }
    if (url.contains('youtube.com/shorts/')) {
      return RegExp(r'/youtube\.com\/shorts\/([A-z0-9_-]+)')
          .firstMatch(url)!
          .group(1)!;
    }
    final r = RegExp(r'v=([A-z0-9_-]+)');
    if (!r.hasMatch(url)) return '';
    return r.firstMatch(url)!.group(1)!;
  }

  Future<String> getYoutubeVideoUrl(String url) async {
    final yt = youtube.YoutubeExplode();
    try {
      final id = extractVideoId(url);
      StreamManifest manifest;
      try {
        manifest = await yt.videos.streamsClient
            .getManifest(id, ytClients: [YoutubeApiClient.androidVr]);
      } catch (e) {
        print(e);
        app.chat.addItem(ChatItem('', e.toString()));
        return '';
      }
      yt.close();
      // final stream = manifest.muxed.withHighestBitrate();
      final qualities = manifest.muxed.getAllVideoQualities().toList();
      final values = youtube.VideoQuality.values;
      qualities.sort((a, b) {
        return values.indexOf(a).compareTo(values.indexOf(b));
      });
      while (values.indexOf(qualities.last) >
          values.indexOf(youtube.VideoQuality.high1080)) {
        qualities.removeLast();
      }
      // print(qualities);
      final stream = manifest.muxed.firstWhere((element) {
        return element.videoQuality == qualities.last;
      });
      final streamUrl = stream.url.toString();
      return streamUrl;
    } catch (e) {
      print('getYoutubeVideoUrl error for url $url');
      print(e);
      yt.close();
      return '';
    }
  }

  Future<String> getVideoTitle(String url) async {
    if (url.contains('youtu')) return getYoutubeVideoTitle(url);

    final matchName = RegExp(r'^(.+)\.(.+)');
    final decodedUrl = Uri.decodeFull(url);
    var title = decodedUrl.substring(decodedUrl.lastIndexOf('/') + 1);
    final isNameMatched = matchName.hasMatch(title);
    if (isNameMatched)
      title = matchName.stringMatch(title)!;
    else
      title = 'Raw Video';
    return Future.value(title);
  }

  Future<String> getYoutubeVideoTitle(String url) async {
    final yt = youtube.YoutubeExplode();
    try {
      final id = extractVideoId(url);
      final manifest = await yt.videos.get(id);
      yt.close();
      return manifest.title;
    } catch (e) {
      yt.close();
      return 'Youtube Video';
    }
  }

  Future<ClosedCaptionFile>? _loadCaptions(VideoList item) {
    if (item.url.contains('youtu')) {
      item.subs = item.url;
      return compute(_loadYoutubeCaptionsFuture, item);
    }
    var subsUrl = item.subs ?? '';
    if (subsUrl.isEmpty) return null;
    if (!subsUrl.startsWith('http')) {
      subsUrl = 'http://$subsUrl';
    }
    // if (subsUrl == '') {
    //   if (item.duration < 60 * 5) return null;
    //   final i = item.url.lastIndexOf('.mp4');
    //   if (i == -1) return null;
    //   subsUrl = item.url.replaceFirst('.mp4', '.ass', i);
    // }
    return compute(_loadCaptionsFuture, subsUrl);
  }

  static Future<ClosedCaptionFile> _loadYoutubeCaptionsFuture(
      VideoList item) async {
    final subs = await getYoutubeSubtitles(item.url);
    if (subs.captions.isEmpty) item.subs = '';
    return subs;
  }

  static Future<ClosedCaptionFile> _loadCaptionsFuture(String url) async {
    Response response;
    try {
      response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
    } catch (_) {
      print('Subtitles loading error ($url)');
      return RawCaptionFile([]);
    }
    if (response.statusCode == 200) {
      var data = utf8.decode(response.bodyBytes);
      if (url.endsWith('.srt')) {
        data = parseSrt(data);
        return WebVTTCaptionFile(data);
        // return SubRipCaptionFile(data);
      } else if (url.endsWith('.vtt')) {
        return WebVTTCaptionFile(data);
      } else {
        return AssCaptionFile(data);
      }
    } else {
      return RawCaptionFile([]);
    }
  }

  static String parseSrt(String text) {
    final subs = <Map<String, String>>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final blocks = getSrtBlocks(lines);
    final badTimeReg = RegExp(r'(,[\d]+)');
    for (final lines in blocks) {
      if (lines.length < 3) continue;
      final textLines = lines.getRange(2, lines.length).toList();
      final time = lines[1].replaceAllMapped(badTimeReg, (match) {
        final ms = match.group(1)!;
        return ms.length < 4 ? ms.padRight(4, '0') : ms;
      });
      subs.add({
        'counter': lines[0],
        'time': time.replaceAll(',', '.'),
        'text': textLines.join('\n').trim(),
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

  static List<List<String>> getSrtBlocks(List<String> lines) {
    final blocks = <List<String>>[];
    final isNumLineReg = RegExp(r'^(\d+)$');
    // [id, time, firstTextLine, ... lastTextLine]
    var block = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (blocks.isEmpty && line.isEmpty) continue;
      final prevLine = i > 0 ? lines[i - 1] : '';
      final nextLine = i < lines.length - 1 ? lines[i + 1] : '';
      // block id line
      if (prevLine.isEmpty &&
          isNumLineReg.hasMatch(line) &&
          nextLine.contains('-->')) {
        // push previously collected block and start new one
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

  static Future<ClosedCaptionFile> getYoutubeSubtitles(String url) async {
    final yt = youtube.YoutubeExplode();
    try {
      final id = extractVideoId(url);
      final manifest = await yt.videos.closedCaptions.getManifest(id);
      final en = manifest.getByLanguage('en', autoGenerated: false);
      if (en.isEmpty) {
        yt.close();
        return RawCaptionFile([]);
      }
      final info = en.first;
      youtube.ClosedCaptionTrack track;
      try {
        track = await yt.videos.closedCaptions.get(info);
      } catch (e) {
        yt.close();
        return RawCaptionFile([]);
      }
      var i = 0;
      final items = track.captions.map((e) {
        final caption = Caption(
          number: i,
          start: e.offset,
          end: e.offset + e.duration,
          text: e.text,
        );
        i++;
        return caption;
      }).toList();
      yt.close();
      return RawCaptionFile(items);
    } catch (e) {
      yt.close();
      return RawCaptionFile([]);
    }
  }

  bool hasCaptions() {
    final item = playlist.getItem(playlist.pos);
    final subs = item?.subs;
    return subs != null && subs.isNotEmpty;
  }

  void userSetPlayerState(bool state) {
    state ? play() : pause();
    sendPlayerState(state);
  }

  void sendPlayerState(bool state) async {
    if (!isVideoLoaded()) return;
    if (!app.isLeader()) return;
    final posD = await controller?.position ?? Duration();
    final time = posD.inMilliseconds / 1000;
    if (state) {
      app.send(WsData(
        type: 'Play',
        play: Pause(time: time),
      ));
    } else {
      app.send(WsData(
        type: 'Pause',
        pause: Pause(time: time),
      ));
    }
  }

  @override
  void dispose() async {
    print('PlayerModel disposed');
    await controller?.dispose();
    controller = null;
    super.dispose();
  }
}
