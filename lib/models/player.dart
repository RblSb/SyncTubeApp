import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../players/abstract_player.dart';
import '../players/raw_player.dart';
import '../players/youtube_player.dart';
import '../wsdata.dart';
import './app.dart';
import './playlist.dart';

class PlayerModel extends ChangeNotifier {
  static String extractVideoId(String url) =>
      YoutubePlayerImpl.extractVideoId(url);

  Future<({double duration, String title})?> getYoutubeInfo(String url) async {
    final yt = YoutubePlayerImpl(app, () {});
    final info = await yt.getYoutubeInfo(url);
    yt.dispose();
    return info;
  }

  AbstractPlayer? player;
  late RawPlayer rawPlayer;
  late List<AbstractPlayer> players;

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

  PlayerModel(this.app, this.playlist) {
    rawPlayer = RawPlayer(app, notifyListeners);
    players = [
      YoutubePlayerImpl(app, notifyListeners),
    ];
  }

  bool isVideoLoaded() {
    return player?.isVideoLoaded() ?? false;
  }

  bool isPlaying() {
    return !(player?.isPaused() ?? true);
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
    return await player?.getPosition() ?? Duration.zero;
  }

  void pause() {
    player?.pause();
  }

  void play() {
    if (app.isInBackground) {
      if (!app.hasBackgroundAudio) return;
    }
    player?.play();
  }

  void seekTo(Duration duration) {
    player?.seekTo(duration);
  }

  Future<double> getPlaybackSpeed() async {
    return await player?.getPlaybackRate() ?? 1.0;
  }

  void setPlaybackSpeed(double rate) {
    player?.setPlaybackRate(rate);
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

  void setPlayer(AbstractPlayer newPlayer) {
    if (player != newPlayer) {
      player?.removeVideo();
    }
    player = newPlayer;
  }

  void setSupportedPlayer(String url, String playerType) {
    AbstractPlayer? foundPlayer;
    for (final p in players) {
      if (p.isSupportedLink(url)) {
        foundPlayer = p;
        break;
      }
    }

    if (foundPlayer != null) {
      setPlayer(foundPlayer);
    } else {
      setPlayer(rawPlayer);
    }
  }

  void loadVideo(int pos) async {
    playlist.setPos(pos);
    final item = playlist.getItem(playlist.pos);
    if (item == null) return;

    if (isIframe()) {
      setPlayer(rawPlayer); // Fallback or handle iframe specifically
      initPlayerFuture = Future.microtask(() => null);
      notifyListeners();
      return;
    }

    setSupportedPlayer(item.url, item.playerType);

    initPlayerFuture = player?.loadVideo(item);
    initPlayerFuture?.whenComplete(() {
      app.send(
        WsData(
          type: 'VideoLoaded',
        ),
      );
      notifyListeners();
    });

    _isFitWidth = false;
    notifyListeners();
  }

  Future<double> getVideoDuration(String url) async {
    AbstractPlayer? targetPlayer;
    for (final p in players) {
      if (p.isSupportedLink(url)) {
        targetPlayer = p;
        break;
      }
    }
    targetPlayer ??= rawPlayer;
    return await targetPlayer.getVideoDuration(url);
  }

  Future<String> getVideoTitle(String url) async {
    AbstractPlayer? targetPlayer;
    for (final p in players) {
      if (p.isSupportedLink(url)) {
        targetPlayer = p;
        break;
      }
    }
    targetPlayer ??= rawPlayer;
    return await targetPlayer.getVideoTitle(url);
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
    final posD = await getPosition();
    final time = posD.inMilliseconds / 1000;
    if (state) {
      app.send(
        WsData(
          type: 'Play',
          play: Pause(time: time),
        ),
      );
    } else {
      app.send(
        WsData(
          type: 'Pause',
          pause: Pause(time: time),
        ),
      );
    }
  }

  @override
  void dispose() {
    print('PlayerModel disposed');
    rawPlayer.dispose();
    for (final p in players) {
      p.dispose();
    }
    super.dispose();
  }
}
