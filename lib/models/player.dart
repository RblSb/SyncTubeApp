import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../chat.dart';
import '../subs/ass.dart';
import '../subs/raw.dart';
import '../wsdata.dart';
import './app.dart';
import './captions.dart';
import './playlist.dart';

class PlayerModel extends ChangeNotifier {
  late final Player player;
  late final VideoController controller;
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
    player = Player();
    controller = VideoController(player);

    player.stream.completed.listen((completed) {
      if (completed) {
        // sync with server?
      }
    });

    player.stream.position.listen((_) => notifyListeners());
    player.stream.playing.listen((_) => notifyListeners());
    player.stream.buffer.listen((_) => notifyListeners());
    player.stream.rate.listen((_) => notifyListeners());
  }

  bool isVideoLoaded() {
    return player.state.width != null && player.state.height != null;
  }

  bool isPlaying() {
    return player.state.playing;
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
    return player.state.position;
  }

  void pause() async {
    await player.pause();
  }

  void play() async {
    if (app.isInBackground) {
      if (!app.hasBackgroundAudio) return;
    }
    await player.play();
  }

  void seekTo(Duration duration) async {
    await player.seek(duration);
  }

  Future<double> getPlaybackSpeed() async {
    return player.state.rate;
  }

  void setPlaybackSpeed(double rate) async {
    await player.setRate(rate);
    notifyListeners();
    if (!app.isLeader()) return;
    app.send(
      WsData(
        type: 'SetRate',
        setRate: SetRate(rate: rate),
      ),
    );
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
      initPlayerFuture = Future.microtask(() => null);
      notifyListeners();
      return;
    }
    var url = item.url;
    if (url.startsWith('/')) {
      final relativeHost = app.getChannelLink();
      url = '$relativeHost${url}';
    }
    String? audioUrl;
    if (url.contains('youtu')) {
      final ytData = await getYoutubeVideoUrl(url);
      url = ytData.video;
      audioUrl = ytData.audio;
    }
    pause();

    initPlayerFuture = () async {
      await player.open(Media(url));
      if (audioUrl != null) {
        await player.setAudioTrack(AudioTrack.uri(audioUrl));
      }
    }();

    initPlayerFuture?.whenComplete(() {
      _loadCaptions(item)?.then((subs) {
        _currentCaptions = subs;
        notifyListeners();
      });
      app.send(
        WsData(
          type: 'VideoLoaded',
        ),
      );
    });
    // app.chat.addItem(ChatItem('', 'VideoLoaded'))
    _isFitWidth = false;
    notifyListeners();
  }

  LocalClosedCaptionFile? _currentCaptions;

  String fullscreenTooltipText = 'Double-tap or long-tap to toggle fullscreen';
  LocalClosedCaptionFile? get currentCaptions => _currentCaptions;

  Future<double> getVideoDuration(String url) async {
    if (url.contains('youtu')) {
      url = (await getYoutubeVideoUrl(url)).video;
    }
    final tempPlayer = Player();
    Duration? duration;
    try {
      await tempPlayer.open(Media(url), play: false);
      // Wait a bit for duration to be parsed
      await Future.delayed(const Duration(milliseconds: 500));
      duration = tempPlayer.state.duration;
      await tempPlayer.dispose();
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
      return RegExp(
        r'/youtube\.com\/shorts\/([A-z0-9_-]+)',
      ).firstMatch(url)!.group(1)!;
    }
    final r = RegExp(r'v=([A-z0-9_-]+)');
    if (!r.hasMatch(url)) return '';
    return r.firstMatch(url)!.group(1)!;
  }

  Future<({String video, String? audio})> getYoutubeVideoUrl(String url) async {
    final yt = youtube.YoutubeExplode();
    try {
      final id = extractVideoId(url);
      StreamManifest manifest;
      try {
        manifest = await yt.videos.streamsClient.getManifest(
          id,
          ytClients: [YoutubeApiClient.androidVr],
        );
      } catch (e) {
        print(e);
        app.chat.addItem(ChatItem('', e.toString()));
        return (video: '', audio: null);
      }

      final videoStreams = manifest.videoOnly.toList();
      final values = youtube.VideoQuality.values;
      videoStreams.sort((a, b) {
        return values
            .indexOf(a.videoQuality)
            .compareTo(values.indexOf(b.videoQuality));
      });

      // Filter to max 1080p
      final filteredVideo = videoStreams.where((s) {
        return values.indexOf(s.videoQuality) <=
            values.indexOf(youtube.VideoQuality.high1080);
      }).toList();

      final audioStream = manifest.audioOnly.isEmpty
          ? null
          : manifest.audioOnly.withHighestBitrate();

      if (filteredVideo.isNotEmpty && audioStream != null) {
        yt.close();
        return (
          video: filteredVideo.last.url.toString(),
          audio: audioStream.url.toString(),
        );
      }

      // fallback to muxed
      final muxedStreams = manifest.muxed.toList();
      muxedStreams.sort((a, b) {
        return values
            .indexOf(a.videoQuality)
            .compareTo(values.indexOf(b.videoQuality));
      });
      final filteredMuxed = muxedStreams.where((s) {
        return values.indexOf(s.videoQuality) <=
            values.indexOf(youtube.VideoQuality.high1080);
      }).toList();

      yt.close();
      if (filteredMuxed.isNotEmpty) {
        return (video: filteredMuxed.last.url.toString(), audio: null);
      }

      return (video: '', audio: null);
    } catch (e) {
      print('getYoutubeVideoUrl error for url $url');
      print(e);
      yt.close();
      return (video: '', audio: null);
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

  Future<({double duration, String title})?> getYoutubeInfo(String url) async {
    try {
      final videoId = PlayerModel.extractVideoId(url);
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
      final title = (item['snippet'] as Map)['title'] as String? ?? 'Raw Video';
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
    // 99 hours for live streams
    return total == 0 ? 356400.0 : total.toDouble();
  }

  Future<LocalClosedCaptionFile>? _loadCaptions(VideoList item) {
    if (item.url.contains('youtu')) {
      item.subs = item.url;
      return compute(_loadYoutubeCaptionsFuture, item);
    }
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

  static Future<LocalClosedCaptionFile> _loadYoutubeCaptionsFuture(
    VideoList item,
  ) async {
    final subs = await getYoutubeSubtitles(item.url);
    if (subs.captions.isEmpty) item.subs = '';
    return subs;
  }

  static Future<LocalClosedCaptionFile> _loadCaptionsFuture(String url) async {
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
      final normalizedTime = time.replaceAll(',', '.');

      // find last index that has different timing. will be `length - 1` element most of the time
      final lastDifferentTimeI = subs.lastIndexWhere(
        (sub) => sub['time'] != normalizedTime,
      );
      final i = lastDifferentTimeI + 1;

      final text = textLines.join('\n').trim();
      if (i < subs.length) {
        // Merge text with existing subtitle (add at top like in web case)
        subs[i]['text'] = '$text\n${subs[i]['text']}';
      } else {
        // Add new subtitle
        subs.add({
          'counter': lines[0],
          'time': normalizedTime,
          'text': text,
        });
      }
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

  static Future<LocalClosedCaptionFile> getYoutubeSubtitles(String url) async {
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
        final caption = LocalCaption(
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
    final posD = player.state.position;
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
  void dispose() async {
    print('PlayerModel disposed');
    await player.dispose();
    super.dispose();
  }
}
