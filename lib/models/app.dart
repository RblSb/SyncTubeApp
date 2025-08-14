import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as youtube;

import '../chat.dart';
import '../settings.dart';
import '../wsdata.dart';
import './chat.dart';
import './chat_panel.dart';
import './player.dart';
import './playlist.dart';

enum MainTab {
  chat,
  playlist,
  settings,
}

class AppModel extends ChangeNotifier {
  String get personalName => _personal.name;
  String wsUrl;
  late IOWebSocketChannel _channel;
  late StreamSubscription<dynamic> _wsSubscription;
  late PlaylistModel playlist;
  late PlayerModel player;
  late ChatModel chat;
  late ChatPanelModel chatPanel;
  MainTab mainTab = MainTab.chat;

  Client _personal = Client(name: 'Unknown', group: 0);
  List<Client> clients = [];

  Timer? _getTimeTimer;
  Timer? _reconnectionTimer;
  Timer? _disconnectNotificationTimer;

  int synchThreshold = 2;
  int _prefferedOrientation = 0;
  bool _isChatVisible = true;
  bool _showSubtitles = true;
  bool _hasSystemUi = false;
  bool _hasBackgroundAudio = true;
  bool isInBackground = false;
  Config? config;
  List<String> playersCacheSupport = [];

  bool get hasBackgroundAudio => _hasBackgroundAudio;

  set hasBackgroundAudio(bool hasBackgroundAudio) {
    if (_hasBackgroundAudio == hasBackgroundAudio) return;
    _hasBackgroundAudio = hasBackgroundAudio;
    notifyListeners();
  }

  bool get hasSystemUi => _hasSystemUi;

  set hasSystemUi(bool hasSystemUi) {
    _hasSystemUi = hasSystemUi;
    notifyListeners();
  }

  bool get isChatVisible => _isChatVisible;

  set isChatVisible(bool isChatVisible) {
    if (_isChatVisible == isChatVisible) return;
    _isChatVisible = isChatVisible;
    if (player.showMessageIcon) {
      player.showMessageIcon = false;
    }
    notifyListeners();
  }

  bool get showSubtitles => _showSubtitles;

  set showSubtitles(bool showSubtitles) {
    if (_showSubtitles == showSubtitles) return;
    _showSubtitles = showSubtitles;
    player.notifyListeners();
  }

  AppModel(this.wsUrl) {
    print('AppModel created');
    playlist = PlaylistModel(this);
    player = PlayerModel(this, playlist);
    chat = ChatModel(this);
    chatPanel = ChatPanelModel(this);
    connect();
    if (Settings.isTV) isChatVisible = false;
  }

  void connect() async {
    final prefs = await SharedPreferencesAsync();
    final uuid = await prefs.getString('uuid');
    var url = wsUrl;
    if (uuid != null) url += '?uuid=$uuid';
    _channel = IOWebSocketChannel.connect(url);
    _wsSubscription = _channel.stream.listen(onMessage, onDone: () {
      chatPanel.isConnected = false;
      _disconnectNotificationTimer ??= Timer(const Duration(seconds: 5), () {
        if (chatPanel.isConnected) return;
        player.pause();
      });
      reconnect();
    }, onError: (error) {
      print(error);
    });
  }

  void reconnect() {
    if (chatPanel.isConnected) return;
    _wsSubscription.cancel();
    _reconnectionTimer = Timer(const Duration(seconds: 1), () {
      print('Try to reconnect...');
      connect();
    });
  }

  String getChannelLink() {
    final uri = Uri.parse(wsUrl);
    final protocol = uri.scheme == 'wss' ? 'https' : 'http';
    return '$protocol://${uri.host}' + (uri.hasPort ? ':${uri.port}' : '');
  }

  void send(WsData data) {
    if (!chatPanel.isConnected) return;
    _channel.sink.add(jsonEncode(data));
  }

  bool isAdmin() => _personal.isAdmin;

  bool isLeader() => _personal.isLeader;

  bool hasLeader() {
    for (final client in clients) {
      if (client.isLeader) return true;
    }
    return false;
  }

  void onMessage(dynamic json) {
    final data = WsData.fromJson(jsonDecode(json));
    switch (data.type) {
      case 'Connected':
        chatPanel.isConnected = true;
        _disconnectNotificationTimer?.cancel();
        _disconnectNotificationTimer = null;
        final type = data.connected!;
        saveUUID(type.uuid);
        config = type.config;
        playersCacheSupport = type.playersCacheSupport;
        WsData.version = config?.cacheStorageLimitGiB == null ? 1 : 2;
        print('Server version: ${WsData.version}');
        _getTimeTimer?.cancel();
        _getTimeTimer =
            Timer.periodic(Duration(seconds: synchThreshold), (Timer timer) {
          if (playlist.isEmpty()) return;
          send(WsData(type: 'GetTime'));
        });
        final prevActiveUrl = playlist.getItem(playlist.pos)?.url ?? '';
        playlist.setPos(type.itemPos);
        playlist.update(type.videoList);
        clients = type.clients;
        chat.isUnknownClient = type.isUnknownClient;
        _personal =
            clients.firstWhere((client) => client.name == type.clientName);
        chat.setItems(
          type.history.map((e) => ChatItem(e.name, e.text, e.time)).toList(),
        );
        playlist.setPlaylistLock(type.isPlaylistOpen);
        final activeUrl = playlist.getItem(playlist.pos)?.url ?? '';
        if (prevActiveUrl != activeUrl) {
          player.loadVideo(playlist.pos);
        }
        chat.setEmotes(type.config.emotes, getChannelLink());
        chatPanel.notifyListeners();
        if (chat.isUnknownClient) tryAutologin();
        break;
      case 'Disconnected': // server-only
        break;
      case 'Login':
        final type = data.login!;
        clients = type.clients!;
        Client? newPersonal = clients
            .firstWhereOrNull((client) => client.name == type.clientName);
        if (newPersonal == null) return;
        _personal = newPersonal;
        chatPanel.notifyListeners();
        chat.isUnknownClient = false;
        chat.showPasswordField = false;
        break;
      case 'PasswordRequest':
        chat.showPasswordField = true;
        break;
      case 'LoginError':
        chat.isUnknownClient = true;
        chat.showPasswordField = false;
        Settings.resetChannelPreferences(wsUrl);
        break;
      case 'Logout':
        final type = data.logout!;
        clients = type.clients;
        _personal = Client(name: type.clientName, group: 0);
        chat.isUnknownClient = true;
        chat.showPasswordField = false;
        Settings.resetChannelPreferences(wsUrl);
        notifyListeners();
        break;
      case 'Message':
        final type = data.message!;
        chat.addItem(ChatItem(type.clientName, type.text));
        if (!isChatVisible && !Settings.isTV) player.showMessageIcon = true;
        break;
      case 'ServerMessage':
        final type = data.serverMessage!;
        var text = type.textId;
        switch (type.textId) {
          case 'usernameError':
            text =
                "Username length must be from 1 to ${config!.maxLoginLength} characters and don't repeat another's. Characters &^<>'\" are not allowed.";
            break;
          case 'passwordMatchError':
            text = 'Wrong password.';
            break;
          case 'accessError':
            text = 'Access Error.';
            break;
          case 'totalVideoLimitError':
            text = 'Playlist video limit has been reached.';
            break;
          case 'userVideoLimitError':
            text = 'Playlist video limit per user has been reached.';
            break;
          case 'videoAlreadyExistsError':
            text = 'The video already exists in playlist.';
            break;
          case 'addVideoError':
            text = 'Failed to add video.';
            break;
        }
        chat.addItem(ChatItem('', text));
        if (!isChatVisible && !Settings.isTV) player.showMessageIcon = true;
        break;
      case 'Progress':
        final type = data.progress!;
        if (type.type == 'Canceled') {
          chat.removeProgressItem();
          return;
        }
        final percent = type.ratio * 100;
        var text = '${type.type}...';
        if (percent != 0) text += ' ${percent.toStringAsFixed(1)}%';
        chat.addItem(ChatItem.fromProgress('', text));
        if (type.ratio == 1) {
          Future.delayed(
            const Duration(seconds: 1),
            () => chat.removeProgressItem(),
          );
        }
        break;
      case 'UpdateClients':
        final type = data.updateClients!;
        clients = type.clients;
        _personal =
            type.clients.firstWhere((client) => client.name == _personal.name);
        chatPanel.notifyListeners();
        break;
      case 'AddVideo':
        final type = data.addVideo!;
        playlist.addItem(type.item, type.atEnd);
        if (playlist.length == 1) player.loadVideo(0);
        break;
      case 'RemoveVideo':
        final type = data.removeVideo!;
        final index = playlist.indexWhere((item) => item.url == type.url);
        if (index == -1) return;
        final isCurrent = playlist.getItem(playlist.pos)!.url == type.url;
        playlist.removeItem(index);
        if (isCurrent && playlist.length > 0) player.loadVideo(playlist.pos);

        if (!player.isVideoLoaded()) return;
        if (playlist.isEmpty()) {
          player.pause();
          chatPanel.serverPlay = true;
        }
        break;
      case 'SkipVideo':
        final type = data.skipVideo!;
        final url = type.url;
        final index = playlist.indexWhere((item) => item.url == url);
        if (index == -1) return;
        playlist.skipItem();
        if (playlist.length == 0) return;
        player.loadVideo(playlist.pos);
        if (!player.isVideoLoaded()) return;
        if (playlist.isEmpty()) player.pause();
        break;
      case 'VideoLoaded':
        if (!player.isVideoLoaded()) return;
        player.seekTo(
          Duration(milliseconds: 0),
        );
        player.play();
        break;
      case 'Pause':
        chatPanel.serverPlay = false;
        if (!player.isVideoLoaded()) return;
        if (_personal.isLeader) return;
        final type = data.pause!;
        final ms = (type.time * 1000).round();
        player.pause();
        player.seekTo(
          Duration(milliseconds: ms),
        );
        break;
      case 'Play':
        chatPanel.serverPlay = true;
        if (!player.isVideoLoaded()) return;
        if (_personal.isLeader) return;
        final type = data.play!;
        onPlay(type);
        break;
      case 'GetTime':
        final type = data.getTime!;
        onTimeGet(type);
        break;
      case 'SetTime':
        if (_personal.isLeader) return;
        final type = data.setTime!;
        onTimeSet(type);
        break;
      case 'SetRate':
        if (_personal.isLeader) return;
        player.setPlaybackSpeed(data.setRate?.rate ?? 1);
        break;
      case 'Rewind':
        if (!player.isVideoLoaded()) return;
        final type = data.rewind!;
        final ms = (type.time * 1000 + 500).round();
        player.seekTo(
          Duration(milliseconds: ms),
        );
        break;
      case 'SetLeader':
        final type = data.setLeader!;
        for (final client in clients) {
          client.isLeader = client.name == type.clientName;
        }
        chatPanel.notifyListeners();
        break;
      case 'PlayItem':
        final type = data.playItem!;
        player.loadVideo(type.pos);
        break;
      case 'SetNextItem':
        final type = data.setNextItem!;
        playlist.setNextItem(type.pos);
        break;
      case 'ToggleItemType':
        final type = data.toggleItemType!;
        playlist.toggleItemType(type.pos);
        break;
      case 'ClearChat':
        chat.clearChat();
        break;
      case 'ClearPlaylist':
        playlist.clear();
        if (playlist.isEmpty()) player.pause();
        break;
      case 'ShufflePlaylist': // server-only
        break;
      case 'UpdatePlaylist':
        final type = data.updatePlaylist!;
        playlist.update(type.videoList);
        break;
      case 'TogglePlaylistLock':
        final type = data.togglePlaylistLock!;
        playlist.setPlaylistLock(type.isOpen);
        break;
      default:
        print('Event ${data.type} not implemented');
    }
  }

  void tryAutologin() async {
    final prefs = await Settings.getChannelPreferences(wsUrl);
    if (prefs.login == '') return;
    chat.sendLogin(Login(
      clientName: prefs.login,
      passHash: prefs.hash == '' ? null : prefs.hash,
      isUnknownClient: null,
      clients: null,
    ));
  }

  void onTimeGet(GetTime type) async {
    if (!player.isVideoLoaded()) return;

    final rateFuture = player.getPlaybackSpeed();
    rateFuture.then((rate) {
      if (rate != type.rate) {
        player.setPlaybackSpeed(type.rate);
      }
    });

    final posD = await player.getPosition();
    final newTime = type.time;
    final time = posD.inMilliseconds / 1000;
    if (_personal.isLeader) {
      // if video is loading on leader
      // move other clients back in time
      if ((time - newTime).abs() < synchThreshold) return;
      send(WsData(
        type: 'SetTime',
        setTime: Pause(time: time),
      ));
      return;
    }
    final duration = player.getDuration();
    if (duration <= time + synchThreshold) return;
    if (player.isPlaying() && type.paused) player.pause();
    if (!player.isPlaying() && !type.paused) player.play();
    chatPanel.serverPlay = !type.paused;
    if ((time - newTime).abs() < synchThreshold) return;
    var ms = (newTime * 1000).round();
    if (!type.paused) ms += 500;
    player.seekTo(
      Duration(milliseconds: ms),
    );
  }

  void onPlay(Pause type) async {
    final newTime = type.time;
    final posD = await player.getPosition();
    final time = posD.inMilliseconds / 1000;
    if ((time - newTime).abs() >= synchThreshold) {
      final ms = (newTime * 1000).round();
      player.seekTo(
        Duration(milliseconds: ms),
      );
    }
    player.play();
  }

  void onTimeSet(Pause type) async {
    final posD = await player.getPosition();
    final newTime = type.time;
    final time = posD.inMilliseconds / 1000;
    if ((time - newTime).abs() < synchThreshold) return;
    final ms = (type.time * 1000).round();
    player.seekTo(
      Duration(milliseconds: ms),
    );
  }

  void requestLeader() {
    final name = _personal.isLeader ? '' : _personal.name;
    send(WsData(
      type: 'SetLeader',
      setLeader: SetLeader(clientName: name),
    ));
    chatPanel.notifyListeners();
  }

  void togglePanel(MainTab newTab) {
    if (mainTab == newTab) {
      mainTab = MainTab.chat;
    } else {
      mainTab = newTab;
    }
    notifyListeners();
    chatPanel.notifyListeners();
  }

  void inBackground() {
    isInBackground = true;
    if (playlist.isEmpty()) return;
    if (!hasBackgroundAudio) player.pause();
  }

  void inForeground() {
    isInBackground = false;
  }

  void setPrefferedOrientation(int state) {
    _prefferedOrientation = state;
    notifyListeners();
  }

  String prefferedOrientationType() {
    switch (_prefferedOrientation) {
      case 0:
        return 'Auto';
      default:
        return 'Landscape';
    }
  }

  void sendVideoItem(AddVideo data) async {
    if (data.item.url.startsWith('/')) {
      final relativeHost = getChannelLink();
      data.item.url = '$relativeHost${data.item.url}';
    }
    if (!data.item.url.startsWith('http')) {
      data.item.url = 'http://${data.item.url}';
    }
    final url = data.item.url;
    if (url.contains('youtube.com/playlist')) {
      sendYoutubePlaylist(data);
      return;
    }
    double duration = 0;
    String title = "";
    var getRawData = true;
    if (url.contains('youtu')) {
      final info = await player.getYoutubeInfo(url);
      if (info != null) {
        duration = info.duration;
        title = info.title;
        getRawData = false;
      }
    }

    if (getRawData) {
      final List<Object> futures = await Future.wait([
        player.getVideoDuration(url),
        player.getVideoTitle(url),
      ]);
      duration = futures[0] as double;
      if (duration == 0) {
        chat.addItem(ChatItem('Failed to add video.', ''));
        return;
      }
      title = futures[1] as String;
    }

    data.item.duration = duration;
    data.item.title = title;
    send(WsData(
      type: 'AddVideo',
      addVideo: data,
    ));
  }

  void sendYoutubePlaylist(AddVideo data) async {
    final yt = youtube.YoutubeExplode();
    final playlist =
        await yt.playlists.getVideos(data.item.url).take(50).toList();
    yt.close();
    final items = data.atEnd ? playlist : sortItemsForQueueNext(playlist);
    for (final video in items) {
      if (video.duration == null) continue;
      data.item.duration = video.duration!.inMilliseconds / 1000;
      data.item.title = video.title;
      data.item.url = video.url;
      send(WsData(
        type: 'AddVideo',
        addVideo: data,
      ));
    }
  }

  List<T> sortItemsForQueueNext<T>(List<T> items) {
    if (items.isEmpty) return items;
    // except first item when list empty
    T? first;
    if (player.playlist.isEmpty()) first = items.removeAt(0);
    items = items.reversed.toList();
    if (first != null) items.insert(0, first);
    return items;
  }

  @override
  void dispose() {
    print('AppModel disposed');
    player.dispose();
    playlist.dispose();
    _getTimeTimer?.cancel();
    _reconnectionTimer?.cancel();
    _wsSubscription.cancel();
    _channel.sink.close(status.normalClosure);
    super.dispose();
  }

  Future<void> saveUUID(String uuid) async {
    final prefs = await SharedPreferencesAsync();
    await prefs.setString('uuid', uuid);
  }
}
