import 'package:meta/meta.dart';

class WsData {
  String type;
  Connected connected;
  Login login;
  Logout logout;
  Message message;
  ServerMessage serverMessage;
  UpdateClients updateClients;
  AddVideo addVideo;
  RemoveVideo removeVideo;
  RemoveVideo skipVideo;
  Pause pause;
  Pause play;
  GetTime getTime;
  Pause setTime;
  SetRate setRate;
  Pause rewind;
  SetLeader setLeader;
  PlayItem playItem;
  PlayItem setNextItem;
  PlayItem toggleItemType;
  UpdatePlaylist updatePlaylist;
  TogglePlaylistLock togglePlaylistLock;

  WsData(
      {@required this.type,
      this.connected,
      this.login,
      this.logout,
      this.message,
      this.serverMessage,
      this.updateClients,
      this.addVideo,
      this.removeVideo,
      this.skipVideo,
      this.pause,
      this.play,
      this.getTime,
      this.setTime,
      this.setRate,
      this.rewind,
      this.setLeader,
      this.playItem,
      this.setNextItem,
      this.toggleItemType,
      this.updatePlaylist,
      this.togglePlaylistLock});

  WsData.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    connected = json['connected'] != null
        ? new Connected.fromJson(json['connected'])
        : null;
    login = json['login'] != null ? new Login.fromJson(json['login']) : null;
    logout =
        json['logout'] != null ? new Logout.fromJson(json['logout']) : null;
    message =
        json['message'] != null ? new Message.fromJson(json['message']) : null;
    serverMessage = json['serverMessage'] != null
        ? new ServerMessage.fromJson(json['serverMessage'])
        : null;
    updateClients = json['updateClients'] != null
        ? new UpdateClients.fromJson(json['updateClients'])
        : null;
    addVideo = json['addVideo'] != null
        ? new AddVideo.fromJson(json['addVideo'])
        : null;
    removeVideo = json['removeVideo'] != null
        ? new RemoveVideo.fromJson(json['removeVideo'])
        : null;
    skipVideo = json['skipVideo'] != null
        ? new RemoveVideo.fromJson(json['skipVideo'])
        : null;
    pause = json['pause'] != null ? new Pause.fromJson(json['pause']) : null;
    play = json['play'] != null ? new Pause.fromJson(json['play']) : null;
    getTime =
        json['getTime'] != null ? new GetTime.fromJson(json['getTime']) : null;
    setTime =
        json['setTime'] != null ? new Pause.fromJson(json['setTime']) : null;
    setRate =
        json['setRate'] != null ? new SetRate.fromJson(json['setRate']) : null;
    rewind = json['rewind'] != null ? new Pause.fromJson(json['rewind']) : null;
    setLeader = json['setLeader'] != null
        ? new SetLeader.fromJson(json['setLeader'])
        : null;
    playItem = json['playItem'] != null
        ? new PlayItem.fromJson(json['playItem'])
        : null;
    setNextItem = json['setNextItem'] != null
        ? new PlayItem.fromJson(json['setNextItem'])
        : null;
    toggleItemType = json['toggleItemType'] != null
        ? new PlayItem.fromJson(json['toggleItemType'])
        : null;
    updatePlaylist = json['updatePlaylist'] != null
        ? new UpdatePlaylist.fromJson(json['updatePlaylist'])
        : null;
    togglePlaylistLock = json['togglePlaylistLock'] != null
        ? new TogglePlaylistLock.fromJson(json['togglePlaylistLock'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['type'] = this.type;
    if (this.connected != null) {
      data['connected'] = this.connected.toJson();
    }
    if (this.login != null) {
      data['login'] = this.login.toJson();
    }
    if (this.logout != null) {
      data['logout'] = this.logout.toJson();
    }
    if (this.message != null) {
      data['message'] = this.message.toJson();
    }
    if (this.serverMessage != null) {
      data['serverMessage'] = this.serverMessage.toJson();
    }
    if (this.updateClients != null) {
      data['updateClients'] = this.updateClients.toJson();
    }
    if (this.addVideo != null) {
      data['addVideo'] = this.addVideo.toJson();
    }
    if (this.removeVideo != null) {
      data['removeVideo'] = this.removeVideo.toJson();
    }
    if (this.skipVideo != null) {
      data['skipVideo'] = this.skipVideo.toJson();
    }
    if (this.pause != null) {
      data['pause'] = this.pause.toJson();
    }
    if (this.play != null) {
      data['play'] = this.play.toJson();
    }
    if (this.getTime != null) {
      data['getTime'] = this.getTime.toJson();
    }
    if (this.setTime != null) {
      data['setTime'] = this.setTime.toJson();
    }
    if (this.setRate != null) {
      data['setRate'] = this.setRate.toJson();
    }
    if (this.rewind != null) {
      data['rewind'] = this.rewind.toJson();
    }
    if (this.setLeader != null) {
      data['setLeader'] = this.setLeader.toJson();
    }
    if (this.playItem != null) {
      data['playItem'] = this.playItem.toJson();
    }
    if (this.setNextItem != null) {
      data['setNextItem'] = this.setNextItem.toJson();
    }
    if (this.toggleItemType != null) {
      data['toggleItemType'] = this.toggleItemType.toJson();
    }
    if (this.updatePlaylist != null) {
      data['updatePlaylist'] = this.updatePlaylist.toJson();
    }
    if (this.togglePlaylistLock != null) {
      data['togglePlaylistLock'] = this.togglePlaylistLock.toJson();
    }
    return data;
  }
}

class Connected {
  Config config;
  List<History> history;
  List<Client> clients;
  bool isUnknownClient;
  String clientName;
  List<VideoList> videoList;
  bool isPlaylistOpen;
  int itemPos;
  String globalIp;

  Connected(
      {this.config,
      this.history,
      this.clients,
      this.isUnknownClient,
      this.clientName,
      this.videoList,
      this.isPlaylistOpen,
      this.itemPos,
      this.globalIp});

  Connected.fromJson(Map<String, dynamic> json) {
    config =
        json['config'] != null ? new Config.fromJson(json['config']) : null;
    if (json['history'] != null) {
      history = new List<History>();
      json['history'].forEach((v) {
        history.add(new History.fromJson(v));
      });
    }
    if (json['clients'] != null) {
      clients = new List<Client>();
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
    }
    isUnknownClient = json['isUnknownClient'];
    clientName = json['clientName'];
    if (json['videoList'] != null) {
      videoList = new List<VideoList>();
      json['videoList'].forEach((v) {
        videoList.add(new VideoList.fromJson(v));
      });
    }
    isPlaylistOpen = json['isPlaylistOpen'];
    itemPos = json['itemPos'];
    globalIp = json['globalIp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.config != null) {
      data['config'] = this.config.toJson();
    }
    if (this.history != null) {
      data['history'] = this.history.map((v) => v.toJson()).toList();
    }
    if (this.clients != null) {
      data['clients'] = this.clients.map((v) => v.toJson()).toList();
    }
    data['isUnknownClient'] = this.isUnknownClient;
    data['clientName'] = this.clientName;
    if (this.videoList != null) {
      data['videoList'] = this.videoList.map((v) => v.toJson()).toList();
    }
    data['isPlaylistOpen'] = this.isPlaylistOpen;
    data['itemPos'] = this.itemPos;
    data['globalIp'] = this.globalIp;
    return data;
  }
}

class Config {
  int port;
  String channelName;
  int maxLoginLength;
  int maxMessageLength;
  int serverChatHistory;
  int totalVideoLimit;
  int userVideoLimit;
  bool localAdmins;
  String templateUrl;
  String youtubeApiKey;
  Permissions permissions;
  List<Emotes> emotes;
  List<Filters> filters;
  bool isVerbose;
  String salt;

  Config(
      {this.port,
      this.channelName,
      this.maxLoginLength,
      this.maxMessageLength,
      this.serverChatHistory,
      this.totalVideoLimit,
      this.userVideoLimit,
      this.localAdmins,
      this.templateUrl,
      this.youtubeApiKey,
      this.permissions,
      this.emotes,
      this.filters,
      this.isVerbose,
      this.salt});

  Config.fromJson(Map<String, dynamic> json) {
    port = json['port'];
    channelName = json['channelName'];
    maxLoginLength = json['maxLoginLength'];
    maxMessageLength = json['maxMessageLength'];
    serverChatHistory = json['serverChatHistory'];
    totalVideoLimit = json['totalVideoLimit'];
    userVideoLimit = json['userVideoLimit'];
    localAdmins = json['localAdmins'];
    templateUrl = json['templateUrl'];
    youtubeApiKey = json['youtubeApiKey'];
    permissions = json['permissions'] != null
        ? new Permissions.fromJson(json['permissions'])
        : null;
    if (json['emotes'] != null) {
      emotes = new List<Emotes>();
      json['emotes'].forEach((v) {
        emotes.add(new Emotes.fromJson(v));
      });
    }
    if (json['filters'] != null) {
      filters = new List<Filters>();
      json['filters'].forEach((v) {
        filters.add(new Filters.fromJson(v));
      });
    }
    isVerbose = json['isVerbose'];
    salt = json['salt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['port'] = this.port;
    data['channelName'] = this.channelName;
    data['maxLoginLength'] = this.maxLoginLength;
    data['maxMessageLength'] = this.maxMessageLength;
    data['serverChatHistory'] = this.serverChatHistory;
    data['totalVideoLimit'] = this.totalVideoLimit;
    data['userVideoLimit'] = this.userVideoLimit;
    data['localAdmins'] = this.localAdmins;
    data['templateUrl'] = this.templateUrl;
    data['youtubeApiKey'] = this.youtubeApiKey;
    if (this.permissions != null) {
      data['permissions'] = this.permissions.toJson();
    }
    if (this.emotes != null) {
      data['emotes'] = this.emotes.map((v) => v.toJson()).toList();
    }
    if (this.filters != null) {
      data['filters'] = this.filters.map((v) => v.toJson()).toList();
    }
    data['isVerbose'] = this.isVerbose;
    data['salt'] = this.salt;
    return data;
  }
}

class Permissions {
  List<String> guest;
  List<String> user;
  List<String> leader;
  List<String> admin;

  Permissions({this.guest, this.user, this.leader, this.admin});

  Permissions.fromJson(Map<String, dynamic> json) {
    if (json['guest'] != null) {
      guest = new List<String>();
      json['guest'].forEach((v) {
        guest.add(v);
      });
    }
    if (json['user'] != null) {
      user = new List<String>();
      json['user'].forEach((v) {
        user.add(v);
      });
    }
    if (json['leader'] != null) {
      leader = new List<String>();
      json['leader'].forEach((v) {
        leader.add(v);
      });
    }
    if (json['admin'] != null) {
      admin = new List<String>();
      json['admin'].forEach((v) {
        admin.add(v);
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.guest != null) {
      data['guest'] = this.guest;
    }
    if (this.user != null) {
      data['user'] = this.user;
    }
    if (this.leader != null) {
      data['leader'] = this.leader;
    }
    if (this.admin != null) {
      data['admin'] = this.admin;
    }
    return data;
  }
}

class Emotes {
  String name;
  String image;

  Emotes({this.name, this.image});

  Emotes.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['image'] = this.image;
    return data;
  }
}

class Filters {
  String name;
  String regex;
  String flags;
  String replace;

  Filters({this.name, this.regex, this.flags, this.replace});

  Filters.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    regex = json['regex'];
    flags = json['flags'];
    replace = json['replace'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['regex'] = this.regex;
    data['flags'] = this.flags;
    data['replace'] = this.replace;
    return data;
  }
}

class History {
  String text;
  String name;
  String time;

  History({this.text, this.name, this.time});

  History.fromJson(Map<String, dynamic> json) {
    text = json['text'];
    name = json['name'];
    time = json['time'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['text'] = this.text;
    data['name'] = this.name;
    data['time'] = this.time;
    return data;
  }
}

class Client {
  String name;
  int group;

  Client({this.name, this.group});

  Client.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    group = json['group'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['group'] = this.group;
    return data;
  }
}

class VideoList {
  String url;
  String title;
  String author;
  double duration;
  bool isTemp;
  bool isIframe;

  VideoList(
      {this.url,
      this.title,
      this.author,
      this.duration,
      this.isTemp,
      this.isIframe});

  VideoList.fromJson(Map<String, dynamic> json) {
    url = json['url'];
    title = json['title'];
    author = json['author'];
    duration = json['duration'].toDouble();
    isTemp = json['isTemp'];
    isIframe = json['isIframe'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['url'] = this.url;
    data['title'] = this.title;
    data['author'] = this.author;
    data['duration'] = this.duration;
    data['isTemp'] = this.isTemp;
    data['isIframe'] = this.isIframe;
    return data;
  }
}

class Login {
  String clientName;
  String passHash;
  List<Client> clients;
  bool isUnknownClient;

  Login({this.clientName, this.passHash, this.clients, this.isUnknownClient});

  Login.fromJson(Map<String, dynamic> json) {
    clientName = json['clientName'];
    passHash = json['passHash'];
    if (json['clients'] != null) {
      clients = new List<Client>();
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
    }
    isUnknownClient = json['isUnknownClient'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['clientName'] = this.clientName;
    data['passHash'] = this.passHash;
    if (this.clients != null) {
      data['clients'] = this.clients.map((v) => v.toJson()).toList();
    }
    data['isUnknownClient'] = this.isUnknownClient;
    return data;
  }
}

class Logout {
  String oldClientName;
  String clientName;
  List<Client> clients;

  Logout({this.oldClientName, this.clientName, this.clients});

  Logout.fromJson(Map<String, dynamic> json) {
    oldClientName = json['oldClientName'];
    clientName = json['clientName'];
    if (json['clients'] != null) {
      clients = new List<Client>();
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['oldClientName'] = this.oldClientName;
    data['clientName'] = this.clientName;
    if (this.clients != null) {
      data['clients'] = this.clients.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Message {
  String clientName;
  String text;

  Message({this.clientName, this.text});

  Message.fromJson(Map<String, dynamic> json) {
    clientName = json['clientName'];
    text = json['text'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['clientName'] = this.clientName;
    data['text'] = this.text;
    return data;
  }
}

class ServerMessage {
  String textId;

  ServerMessage({this.textId});

  ServerMessage.fromJson(Map<String, dynamic> json) {
    textId = json['textId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['textId'] = this.textId;
    return data;
  }
}

class UpdateClients {
  List<Client> clients;

  UpdateClients({this.clients});

  UpdateClients.fromJson(Map<String, dynamic> json) {
    if (json['clients'] != null) {
      clients = new List<Client>();
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.clients != null) {
      data['clients'] = this.clients.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class AddVideo {
  VideoList item;
  bool atEnd;

  AddVideo({this.item, this.atEnd});

  AddVideo.fromJson(Map<String, dynamic> json) {
    item = json['item'] != null ? new VideoList.fromJson(json['item']) : null;
    atEnd = json['atEnd'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.item != null) {
      data['item'] = this.item.toJson();
    }
    data['atEnd'] = this.atEnd;
    return data;
  }
}

class RemoveVideo {
  String url;

  RemoveVideo({this.url});

  RemoveVideo.fromJson(Map<String, dynamic> json) {
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['url'] = this.url;
    return data;
  }
}

class Pause {
  double time;

  Pause({this.time});

  Pause.fromJson(Map<String, dynamic> json) {
    time = json['time'].toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['time'] = this.time;
    return data;
  }
}

class GetTime {
  double time;
  bool paused;
  int rate;

  GetTime({this.time, this.paused, this.rate});

  GetTime.fromJson(Map<String, dynamic> json) {
    time = json['time'].toDouble();
    paused = json['paused'];
    rate = json['rate'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['time'] = this.time;
    data['paused'] = this.paused;
    data['rate'] = this.rate;
    return data;
  }
}

class SetRate {
  int rate;

  SetRate({this.rate});

  SetRate.fromJson(Map<String, dynamic> json) {
    rate = json['rate'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['rate'] = this.rate;
    return data;
  }
}

class SetLeader {
  String clientName;

  SetLeader({this.clientName});

  SetLeader.fromJson(Map<String, dynamic> json) {
    clientName = json['clientName'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['clientName'] = this.clientName;
    return data;
  }
}

class PlayItem {
  int pos;

  PlayItem({this.pos});

  PlayItem.fromJson(Map<String, dynamic> json) {
    pos = json['pos'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['pos'] = this.pos;
    return data;
  }
}

class UpdatePlaylist {
  List<VideoList> videoList;

  UpdatePlaylist({this.videoList});

  UpdatePlaylist.fromJson(Map<String, dynamic> json) {
    if (json['videoList'] != null) {
      videoList = new List<VideoList>();
      json['videoList'].forEach((v) {
        videoList.add(new VideoList.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.videoList != null) {
      data['videoList'] = this.videoList.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class TogglePlaylistLock {
  bool isOpen;

  TogglePlaylistLock({this.isOpen});

  TogglePlaylistLock.fromJson(Map<String, dynamic> json) {
    isOpen = json['isOpen'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['isOpen'] = this.isOpen;
    return data;
  }
}
