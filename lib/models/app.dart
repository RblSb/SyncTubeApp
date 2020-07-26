import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../settings.dart';
import './chat.dart';
import './player.dart';
import './playlist.dart';
import './chat_panel.dart';

import '../chat.dart';
import '../wsdata.dart';

enum MainTab {
  chat,
  playlist,
  settings,
}

class AppModel extends ChangeNotifier {
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

  int synchThreshold = 2;
  int _prefferedOrientation = 0;
  bool _isChatVisible = true;
  bool _hasSystemUi = false;
  Config? config;

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

  AppModel(this.wsUrl) {
    print('AppModel created');
    playlist = PlaylistModel(this);
    player = PlayerModel(this, playlist);
    chat = ChatModel(this);
    chatPanel = ChatPanelModel(this);
    connect();
  }

  void connect() {
    _channel = IOWebSocketChannel.connect(wsUrl);
    _wsSubscription = _channel.stream.listen(onMessage, onDone: () {
      chatPanel.isConnected = false;
      player.pause();
      reconnect();
    }, onError: (error) {});
  }

  void reconnect() {
    if (chatPanel.isConnected) return;
    _wsSubscription.cancel();
    _reconnectionTimer = Timer(const Duration(seconds: 3), () {
      print('Try to reconnect...');
      connect();
    });
  }

  void send(WsData data) {
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
        final type = data.connected!;
        config = type.config;
        _getTimeTimer?.cancel();
        _getTimeTimer =
            Timer.periodic(Duration(seconds: synchThreshold), (Timer timer) {
          if (playlist.isEmpty()) return;
          send(WsData(type: 'GetTime'));
        });
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
        player.loadVideo(playlist.pos);
        chat.setEmotes(type.config.emotes);
        chatPanel.notifyListeners();
        if (chat.isUnknownClient) tryAutologin();
        break;
      case 'Disconnected': // server-only
        break;
      case 'Login':
        final type = data.login!;
        clients = type.clients!;
        Client? newPersonal =
            clients.firstWhere((client) => client.name == type.clientName);
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
        Settings.resetNameAndHash();
        break;
      case 'Logout':
        final type = data.logout!;
        clients = type.clients;
        _personal = Client(name: type.clientName, group: 0);
        chat.isUnknownClient = true;
        chat.showPasswordField = false;
        Settings.resetNameAndHash();
        break;
      case 'Message':
        final type = data.message!;
        chat.addItem(ChatItem(type.clientName, type.text));
        if (!isChatVisible) player.showMessageIcon = true;
        break;
      case 'ServerMessage':
        final type = data.serverMessage!;
        chat.addItem(ChatItem(type.textId, ''));
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
        final isCurrent = playlist.getItem(playlist.pos).url == type.url;
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
        final ms = (type.time * 1000).round();
        player.seekTo(
          Duration(milliseconds: ms),
        );
        player.play();
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
      case 'SetRate': // not yet available in library
        break;
      case 'Rewind':
        if (!player.isVideoLoaded()) return;
        final type = data.rewind!;
        final ms = (type.time * 1000).round();
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
    final arr = await Settings.getSavedNameAndHash();
    if (arr[0] == '') return;
    chat.sendLogin(Login(
      clientName: arr[0],
      passHash: arr[1] == '' ? null : arr[1],
      isUnknownClient: null,
      clients: null,
    ));
  }

  void onTimeGet(GetTime type) async {
    if (!player.isVideoLoaded()) return;
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
    final ms = (newTime * 1000).round();
    player.seekTo(
      Duration(milliseconds: ms),
    );
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
    player.play();
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
    if (!data.item.url.startsWith('http')) {
      data.item.url = 'http://${data.item.url}';
    }
    final url = data.item.url;
    // final duration = await player.getVideoDuration(url);
    final futures = await Future.wait([
      player.getVideoDuration(url),
      player.getVideoTitle(url),
    ]);
    final duration = futures[0] as double;
    if (duration == 0) {
      chat.addItem(ChatItem('Failed to add video.', ''));
      return;
    }
    final title = futures[1] as String;
    data.item.duration = duration;
    data.item.title = title;
    send(WsData(
      type: 'AddVideo',
      addVideo: data,
    ));
  }

  @override
  void dispose() {
    print('AppModel disposed');
    player.dispose();
    playlist.dispose();
    _getTimeTimer?.cancel();
    _reconnectionTimer?.cancel();
    _wsSubscription.cancel();
    _channel.sink.close(status.goingAway);
    super.dispose();
  }
}
