import 'dart:async';
import 'dart:convert';

import 'package:SyncTube/subs/raw.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube;
import './app.dart';
import './playlist.dart';
import '../subs/ass.dart';
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
    return await controller?.value.playbackSpeed ?? 1.0;
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
    return item.isIframe;
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
    if (item.isIframe) {
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
    if (url.contains('youtu')) url = await getYoutubeVideoUrl(url);
    pause();
    final prevController = controller;
    controller = VideoPlayerController.network(
      url,
      // closedCaptionFile: _loadCaptions(item),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: true,
      ),
    );
    controller?.setClosedCaptionFile(_loadCaptions(item));
    controller?.addListener(notifyListeners);
    initPlayerFuture = controller?.initialize();
    initPlayerFuture?.whenComplete(() => prevController?.dispose());
    initPlayerFuture?.whenComplete(() {
      app.send(WsData(
        type: 'VideoLoaded',
      ));
    });
    // app.chat.addItem(ChatItem("", "VideoLoaded"))
    _isFitWidth = false;
    notifyListeners();
  }

  Future<double> getVideoDuration(String url) async {
    if (url.contains('youtu')) url = await getYoutubeVideoUrl(url);
    final controller = VideoPlayerController.network(url);
    Duration? duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
      controller.dispose();
    } catch (e) {}
    if (duration == null) return 0;
    return duration.inMilliseconds / 1000;
  }

  String extractVideoId(String url) {
    if (url.contains('youtu.be/')) {
      return RegExp(r'youtu.be\/([A-z0-9_-]+)').firstMatch(url)!.group(1)!;
    }
    if (url.contains('youtube.com/embed/')) {
      return RegExp(r'embed\/([A-z0-9_-]+)').firstMatch(url)!.group(1)!;
    }
    final r = RegExp(r'v=([A-z0-9_-]+)');
    if (!r.hasMatch(url)) return '';
    return r.firstMatch(url)!.group(1)!;
  }

  Future<String> getYoutubeVideoUrl(String url) async {
    final yt = youtube.YoutubeExplode();
    try {
      final id = extractVideoId(url);
      final manifest = await yt.videos.streamsClient.getManifest(id);
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
      print('getYoutubeVideoUrl for url $url');
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
      return manifest.title;
    } catch (e) {
      return 'Youtube Video';
    }
  }

  Future<ClosedCaptionFile> getYoutubeSubtitles(String url) async {
    // TODO check later
    final yt = youtube.YoutubeExplode();
    try {
      final id = extractVideoId(url);
      final manifest = await yt.videos.closedCaptions.getManifest(id);
      final en = manifest.getByLanguage("en");
      final info = en.first;
      final track = await yt.videos.closedCaptions.get(info);
      final items = track.captions.asMap().entries.map((element) {
        final i = element.key;
        final e = element.value;
        return Caption(
            number: i, start: e.offset, end: e.duration, text: e.text);
      }).toList();
      print(items);
      return RawCaptionFile(items);
    } catch (e) {
      return RawCaptionFile([]);
    }
  }

  Future<ClosedCaptionFile>? _loadCaptions(VideoList item) {
    var subsUrl = item.subs ?? '';
    if (subsUrl.isEmpty) return null;
    // if (subsUrl == '') {
    //   if (item.duration < 60 * 5) return null;
    //   final i = item.url.lastIndexOf('.mp4');
    //   if (i == -1) return null;
    //   subsUrl = item.url.replaceFirst('.mp4', '.ass', i);
    // }
    return _loadCaptionsFuture(subsUrl);
  }

  Future<ClosedCaptionFile>? _loadCaptionsFuture(String url) async {
    Response response;
    try {
      response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 5));
    } catch (_) {
      print('Subtitles loading error ($url)');
      return AssCaptionFile('');
    }
    if (response.statusCode == 200) {
      final data = utf8.decode(response.bodyBytes);
      if (url.endsWith('.srt')) {
        return SubRipCaptionFile(data);
      } else if (url.endsWith('.vtt')) {
        return WebVTTCaptionFile(data);
      } else {
        return AssCaptionFile(data);
      }
    } else {
      return AssCaptionFile('');
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
