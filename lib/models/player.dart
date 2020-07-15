import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube;
import './app.dart';
import './playlist.dart';
import '../ass.dart';
import '../wsdata.dart';

class PlayerModel extends ChangeNotifier {
  VideoPlayerController? controller;
  Future<void>? initPlayerFuture;
  final AppModel app;
  final PlaylistModel playlist;

  bool showControls = false;
  Timer? controlsTimer;

  PlayerModel(this.app, this.playlist);

  bool isVideoLoaded() {
    return controller?.value.initialized ?? false;
  }

  bool isPlaying() {
    return controller?.value.isPlaying ?? false;
  }

  void toggleControls(bool flag) {
    if (showControls == flag) return;
    showControls = flag;
    notifyListeners();
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
    await controller?.play();
  }

  void seekTo(Duration duration) async {
    if (!isVideoLoaded()) return;
    await controller?.seekTo(duration);
  }

  double getDuration() {
    final itemPos = playlist.pos;
    if (itemPos >= playlist.length) return 0;
    final item = playlist.getItem(itemPos);
    return item.duration;
  }

  void loadVideo(int pos) async {
    playlist.setPos(pos);
    if (playlist.pos >= playlist.length) return;
    initPlayerFuture = null;
    final item = playlist.getItem(playlist.pos);
    var url = item.url;
    if (url.contains('youtu')) url = await loadYoutubeVideo(url);
    final prevController = controller;
    controller = VideoPlayerController.network(
      url,
      closedCaptionFile: _loadCaptions(url),
    );
    controller?.addListener(notifyListeners);
    initPlayerFuture = controller?.initialize();
    initPlayerFuture?.whenComplete(() => prevController?.dispose());
    notifyListeners();
  }

  Future<double> getVideoDuration(String url) async {
    if (url.contains('youtu')) url = await loadYoutubeVideo(url);
    final controller = VideoPlayerController.network(url);
    await controller.initialize();
    Duration? duration = controller.value.duration;
    controller.dispose();
    if (duration == null) return 0;
    return duration.inMilliseconds / 1000;
  }

  Future<String> loadYoutubeVideo(String url) async {
    final yt = youtube.YoutubeExplode();
    final manifest = await yt.videos.streamsClient.getManifest(url);
    final stream = manifest.muxed.withHighestBitrate();
    return stream.url.toString();
  }

  Future<String> getVideoTitle(String url) async {
    if (url.contains('youtu')) return getYoutubeVideoTitle(url);

    final matchName = RegExp(r'^(.+)\.(.+)');
    final decodedUrl = Uri.decodeFull(url);
    var title = decodedUrl.substring(decodedUrl.lastIndexOf('/') + 1);
    final isNameMatched = matchName.hasMatch(title);
    if (isNameMatched) title = matchName.stringMatch(title)!;
    else title = 'Raw Video';
    return Future.value(title);
  }

  Future<String> getYoutubeVideoTitle(String url) async {
    final yt = youtube.YoutubeExplode();
    final manifest = await yt.videos.get(url);
    return manifest.title;
  }

  Future<ClosedCaptionFile?> _loadCaptions(String url) async {
    final i = url.lastIndexOf('.mp4');
    if (i == -1) return null;
    url = url.replaceFirst('.mp4', '.ass', i);
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return AssCaptionFile(response.body);
    } else {
      return null;
    }
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
