import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube;
import './app.dart';
import './playlist.dart';
import '../subs/ass.dart';
import '../subs/web_vtt.dart';
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
    final prevController = controller;
    controller = VideoPlayerController.network(
      url,
      closedCaptionFile: _loadCaptions(item),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    controller?.addListener(notifyListeners);
    initPlayerFuture = controller?.initialize();
    initPlayerFuture?.whenComplete(() => prevController?.dispose());
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
      final stream = manifest.muxed.withHighestBitrate();
      return stream.url.toString();
    } catch (e) {
      print('getYoutubeVideoUrl for url $url');
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
      response = await http.get(Uri.parse(url));
    } catch (_) {
      print('Subtitles loading error ($url)');
      return AssCaptionFile('');
    }
    if (response.statusCode == 200) {
      final data = utf8.decode(response.bodyBytes);
      if (url.endsWith('.srt')) {
        return SubRipCaptionFile(data);
      } else if (url.endsWith('.vtt')) {
        return WebVttCaptionFile(data);
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
