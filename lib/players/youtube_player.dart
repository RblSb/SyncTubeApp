import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/app.dart';
import '../wsdata.dart';
import 'abstract_player.dart';

class YoutubePlayerImpl extends AbstractPlayer {
  YoutubePlayerController? _controller;
  StreamSubscription? _subscription;
  final AppModel app;
  final Function() onNotify;

  YoutubePlayerImpl(this.app, this.onNotify);

  @override
  String getPlayerType() => 'YoutubeType';

  @override
  bool isSupportedLink(String url) {
    return url.contains('youtu.be/') ||
        url.contains('youtube.com/watch') ||
        url.contains('youtube.com/embed/') ||
        url.contains('youtube.com/shorts/');
  }

  PlayerState? _lastState;

  @override
  Future<void> loadVideo(VideoList item) async {
    final videoId = extractVideoId(item.url);

    if (_controller != null) {
      dispose();
      _controller = null;
    }
    if (_controller == null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        // autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          mute: false,
          origin: "https://www.youtube-nocookie.com",
        ),
      );
      _subscription = _controller!.videoStateStream.listen((state) {
        final newState = _controller!.value.playerState;
        if (newState == PlayerState.playing ||
            newState == PlayerState.paused ||
            newState == PlayerState.buffering ||
            newState == PlayerState.ended) {
          _lastState = newState;
        }
        onNotify();
      });
      _controller!.cueVideoById(videoId: videoId);
    } else {
      _controller!.cueVideoById(videoId: videoId);
    }
    _lastState = PlayerState.cued;
    onNotify();
  }

  @override
  void removeVideo() {
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
    _lastState = null;
  }

  @override
  bool isVideoLoaded() => _controller != null;

  @override
  void play() {
    _lastState = PlayerState.playing;
    _controller?.playVideo();
    onNotify();
  }

  @override
  void pause() {
    _lastState = PlayerState.paused;
    _controller?.pauseVideo();
    onNotify();
  }

  @override
  bool isPaused() {
    final state = _lastState ?? _controller?.value.playerState;
    if (state == PlayerState.playing || state == PlayerState.buffering) {
      return false;
    }
    if (state == PlayerState.paused || state == PlayerState.ended) {
      return true;
    }
    // For transitional states (cued, unstarted, unknown), trust the room state
    // if we don't have a clear manual intent.
    if (_lastState == PlayerState.playing) return false;
    if (_lastState == PlayerState.paused) return true;

    return !app.chatPanel.serverPlay;
  }

  @override
  Future<Duration> getPosition() async {
    if (_controller == null) return Duration.zero;
    final seconds = await _controller!.currentTime;
    return Duration(milliseconds: (seconds * 1000).toInt());
  }

  @override
  void seekTo(Duration duration) {
    _controller?.seekTo(
      seconds: duration.inMilliseconds / 1000,
      allowSeekAhead: true,
    );
  }

  @override
  Future<double> getPlaybackRate() async {
    return 1.0;
  }

  @override
  void setPlaybackRate(double rate) {
    _controller?.setPlaybackRate(rate);
  }

  @override
  void setVolume(double volume) {
    _controller?.setVolume((volume * 100).toInt());
  }

  @override
  double get aspectRatio => 16 / 9;

  @override
  String get captionText => '';

  @override
  Future<double> getVideoDuration(String url) async {
    final info = await getYoutubeInfo(url);
    return info?.duration ?? 0;
  }

  @override
  Future<String> getVideoTitle(String url) async {
    final info = await getYoutubeInfo(url);
    return info?.title ?? 'Youtube Video';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return Container();
    return YoutubePlayer(
      controller: _controller!,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller?.close();
  }

  static String extractVideoId(String url) {
    if (url.contains('youtu.be/')) {
      final match = RegExp(r'youtu.be\/([A-z0-9_-]+)').firstMatch(url);
      if (match != null && match.groupCount >= 1) return match.group(1)!;
    }
    if (url.contains('youtube.com/embed/')) {
      final match = RegExp(r'embed\/([A-z0-9_-]+)').firstMatch(url);
      if (match != null && match.groupCount >= 1) return match.group(1)!;
    }
    if (url.contains('youtube.com/shorts/')) {
      final match = RegExp(r'\/shorts\/([A-z0-9_-]+)').firstMatch(url);
      if (match != null && match.groupCount >= 1) return match.group(1)!;
    }
    final r = RegExp(r'[?&]v=([A-z0-9_-]+)');
    final match = r.firstMatch(url);
    if (match != null && match.groupCount >= 1) return match.group(1)!;
    return '';
  }

  Future<({double duration, String title})?> getYoutubeInfo(String url) async {
    try {
      final videoId = extractVideoId(url);
      if (videoId.isEmpty) return null;

      final apiKey = app.config!.youtubeApiKey;
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/youtube/v3/videos'
          '?part=snippet,contentDetails'
          '&fields=items(snippet/title,contentDetails/duration)'
          '&id=$videoId'
          '&key=$apiKey',
        ),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final item = items.first as Map<String, dynamic>;
      final title =
          (item['snippet'] as Map)['title'] as String? ?? 'Youtube Video';
      final duration = _convertYoutubeDuration(
        (item['contentDetails'] as Map)['duration'] as String? ?? '',
      );

      return (duration: duration, title: title);
    } catch (_) {
      return null;
    }
  }

  double _convertYoutubeDuration(String duration) {
    final hoursMatch = RegExp(r'(\d+)H').firstMatch(duration);
    final minutesMatch = RegExp(r'(\d+)M').firstMatch(duration);
    final secondsMatch = RegExp(r'(\d+)S').firstMatch(duration);

    final hours = hoursMatch != null ? int.parse(hoursMatch.group(1)!) : 0;
    final minutes = minutesMatch != null
        ? int.parse(minutesMatch.group(1)!)
        : 0;
    final seconds = secondsMatch != null
        ? int.parse(secondsMatch.group(1)!)
        : 0;

    final total = hours * 3600 + minutes * 60 + seconds;
    return total == 0 ? 356400.0 : total.toDouble();
  }
}
