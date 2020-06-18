import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import './chat.dart';
import './player.dart';
import './playlist.dart';

import '../chat.dart';
import '../wsdata.dart';

enum MainTab {
  chat,
  playlist,
  settings,
}

class AppModel extends ChangeNotifier {
  IOWebSocketChannel channel;
  StreamSubscription<dynamic> wsSubscription;
  Stream broadcastStream;
  PlaylistModel playlist;
  PlayerModel player;
  ChatModel chat;
  MainTab mainTab = MainTab.chat;

  List<Client> clients = [];
  String clientName = '';
  bool isUnknownClient = true;
  bool isLeader = false;

  Timer getTimeTimer;

  int synchThreshold = 2;

  int _prefferedOrientation = 0;

  AppModel(String url) {
    print('AppModel created');
    channel = IOWebSocketChannel.connect(url);
    wsSubscription = channel.stream.listen(onMessage);
    playlist = PlaylistModel(this);
    player = PlayerModel(this, playlist);
    chat = ChatModel(this);
  }

  void send(WsData data) {
    channel.sink.add(jsonEncode(data));
  }

  void onMessage(dynamic json) {
    final data = WsData.fromJson(jsonDecode(json));
    switch (data.type) {
      case 'Connected':
        final type = data.connected;
        getTimeTimer?.cancel();
        getTimeTimer =
            Timer.periodic(Duration(seconds: synchThreshold), (Timer timer) {
          if (playlist.isEmpty()) return;
          send(WsData(type: 'GetTime'));
        });
        playlist.setPos(type.itemPos);
        playlist.update(type.videoList);
        clients = type.clients;
        isUnknownClient = type.isUnknownClient;
        clientName = type.clientName;
        chat.setItems(
            type.history.map((e) => ChatItem(e.name, e.text)).toList());
        playlist.setPlaylistLock(type.isPlaylistOpen);
        player.loadVideo(playlist.pos);
        chat.setEmotes(type.config.emotes);
        notifyListeners();
        break;
      case 'Disconnected': // server-only
        break;
      case 'Login':
        break;
      case 'PasswordRequest':
        break;
      case 'LoginError':
        break;
      case 'Logout':
        break;
      case 'Message':
        final type = data.message;
        chat.addItem(ChatItem(type.clientName, type.text));
        break;
      case 'ServerMessage':
        final type = data.serverMessage;
        chat.addItem(ChatItem(type.textId, ''));
        break;
      case 'UpdateClients':
        final type = data.updateClients;
        clients = type.clients;
        notifyListeners();
        break;
      case 'AddVideo':
        final type = data.addVideo;
        playlist.addItem(type.item, type.atEnd);
        if (playlist.length == 1) player.loadVideo(0);
        break;
      case 'RemoveVideo':
        final type = data.removeVideo;
        final index = playlist.indexWhere((item) => item.url == type.url);
        if (index == -1) return;
        final isCurrent = playlist.getItem(playlist.pos).url == type.url;
        playlist.removeItem(index);
        if (isCurrent && playlist.length > 0) player.loadVideo(playlist.pos);

        if (!player.isVideoLoaded()) return;
        if (playlist.isEmpty()) player.pause();
        break;
      case 'SkipVideo':
        final type = data.skipVideo;
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
        if (!player.isVideoLoaded()) return;
        if (isLeader) return;
        final type = data.pause;
        final ms = (type.time * 1000).round();
        player.pause();
        player.seekTo(
          Duration(milliseconds: ms),
        );
        break;
      case 'Play':
        if (!player.isVideoLoaded()) return;
        if (isLeader) return;
        final type = data.play;
        final ms = (type.time * 1000).round();
        player.seekTo(
          Duration(milliseconds: ms),
        );
        player.play();
        break;
      case 'GetTime':
        final type = data.getTime;
        if (type.paused == null) type.paused = false;
        onTimeGet(type);
        break;
      case 'SetTime':
        if (isLeader) return;
        final type = data.setTime;
        onTimeSet(type);
        break;
      case 'SetRate': // not yet available in library
        break;
      case 'Rewind':
        if (!player.isVideoLoaded()) return;
        final type = data.rewind;
        final ms = (type.time * 1000).round();
        player.seekTo(
          Duration(milliseconds: ms),
        );
        break;
      case 'SetLeader':
        final type = data.setLeader;
        isLeader = type.clientName == clientName;
        notifyListeners();
        break;
      case 'PlayItem':
        final type = data.playItem;
        player.loadVideo(type.pos);
        break;
      case 'SetNextItem':
        final type = data.setNextItem;
        playlist.setNextItem(type.pos);
        break;
      case 'ToggleItemType':
        final type = data.toggleItemType;
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
        final type = data.updatePlaylist;
        playlist.update(type.videoList);
        break;
      case 'TogglePlaylistLock':
        final type = data.togglePlaylistLock;
        playlist.setPlaylistLock(type.isOpen);
        break;
      default:
        print('Event ${data.type} not implemented');
    }
  }

  void onTimeGet(GetTime type) async {
    if (!player.isVideoLoaded()) return;
    final posD = await player.getPosition();
    final newTime = type.time;
    final time = posD.inMilliseconds / 1000;
    if (isLeader) {
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
    if (player.controller.value.isPlaying && type.paused) player.pause();
    if (!player.controller.value.isPlaying && !type.paused) player.play();
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
    final name = isLeader ? '' : clientName;
    send(WsData(
      type: 'SetLeader',
      setLeader: SetLeader(clientName: name),
    ));
  }

  void togglePanel(MainTab newTab) {
    if (mainTab == MainTab.chat) {
      mainTab = newTab;
    } else {
      mainTab = MainTab.chat;
    }
    notifyListeners();
  }

  void inBackground() {
    if (player.isVideoLoaded()) player.play();
  }

  void setPrefferedOrientation(int state) {
    _prefferedOrientation = state;
    notifyListeners();
  }

  String prefferedOrientationType() {
    switch (_prefferedOrientation) {
      case 0:
        return 'Auto';
      case 1:
        return 'Landscape';
      case 2:
        return 'Portrait';
      default:
        return 'Unknown';
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
    getTimeTimer?.cancel();
    wsSubscription.cancel();
    channel.sink.close(status.goingAway);
    super.dispose();
  }
}
