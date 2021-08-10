// https://github.com/RblSb/SyncTube/blob/master/src/Types.hx

class WsData {
  late String type;
  Connected? connected;
  Login? login;
  Logout? logout;
  Message? message;
  ServerMessage? serverMessage;
  UpdateClients? updateClients;
  AddVideo? addVideo;
  RemoveVideo? removeVideo;
  RemoveVideo? skipVideo;
  Pause? pause;
  Pause? play;
  GetTime? getTime;
  Pause? setTime;
  SetRate? setRate;
  Pause? rewind;
  SetLeader? setLeader;
  PlayItem? playItem;
  PlayItem? setNextItem;
  PlayItem? toggleItemType;
  UpdatePlaylist? updatePlaylist;
  TogglePlaylistLock? togglePlaylistLock;

  WsData(
      {required this.type,
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
      data['connected'] = this.connected?.toJson();
    }
    if (this.login != null) {
      data['login'] = this.login?.toJson();
    }
    if (this.logout != null) {
      data['logout'] = this.logout?.toJson();
    }
    if (this.message != null) {
      data['message'] = this.message?.toJson();
    }
    if (this.serverMessage != null) {
      data['serverMessage'] = this.serverMessage?.toJson();
    }
    if (this.updateClients != null) {
      data['updateClients'] = this.updateClients?.toJson();
    }
    if (this.addVideo != null) {
      data['addVideo'] = this.addVideo?.toJson();
    }
    if (this.removeVideo != null) {
      data['removeVideo'] = this.removeVideo?.toJson();
    }
    if (this.skipVideo != null) {
      data['skipVideo'] = this.skipVideo?.toJson();
    }
    if (this.pause != null) {
      data['pause'] = this.pause?.toJson();
    }
    if (this.play != null) {
      data['play'] = this.play?.toJson();
    }
    if (this.getTime != null) {
      data['getTime'] = this.getTime?.toJson();
    }
    if (this.setTime != null) {
      data['setTime'] = this.setTime?.toJson();
    }
    if (this.setRate != null) {
      data['setRate'] = this.setRate?.toJson();
    }
    if (this.rewind != null) {
      data['rewind'] = this.rewind?.toJson();
    }
    if (this.setLeader != null) {
      data['setLeader'] = this.setLeader?.toJson();
    }
    if (this.playItem != null) {
      data['playItem'] = this.playItem?.toJson();
    }
    if (this.setNextItem != null) {
      data['setNextItem'] = this.setNextItem?.toJson();
    }
    if (this.toggleItemType != null) {
      data['toggleItemType'] = this.toggleItemType?.toJson();
    }
    if (this.updatePlaylist != null) {
      data['updatePlaylist'] = this.updatePlaylist?.toJson();
    }
    if (this.togglePlaylistLock != null) {
      data['togglePlaylistLock'] = this.togglePlaylistLock?.toJson();
    }
    return data;
  }
}

class Connected {
  late Config config;
  late List<History> history;
  late List<Client> clients;
  late bool isUnknownClient;
  late String clientName;
  late List<VideoList> videoList;
  late bool isPlaylistOpen;
  late int itemPos;
  late String globalIp;

  Connected(
      {required this.config,
      required this.history,
      required this.clients,
      required this.isUnknownClient,
      required this.clientName,
      required this.videoList,
      required this.isPlaylistOpen,
      required this.itemPos,
      required this.globalIp});

  Connected.fromJson(Map<String, dynamic> json) {
    config = new Config.fromJson(json['config']);
    if (json['history'] != null) {
      history = [];
      json['history'].forEach((v) {
        history.add(new History.fromJson(v));
      });
    }
    if (json['clients'] != null) {
      clients = [];
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
    }
    isUnknownClient = json['isUnknownClient'];
    clientName = json['clientName'];
    if (json['videoList'] != null) {
      videoList = [];
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
    data['config'] = this.config.toJson();
    data['history'] = this.history.map((v) => v.toJson()).toList();
    data['clients'] = this.clients.map((v) => v.toJson()).toList();
    data['isUnknownClient'] = this.isUnknownClient;
    data['clientName'] = this.clientName;
    data['videoList'] = this.videoList.map((v) => v.toJson()).toList();
    data['isPlaylistOpen'] = this.isPlaylistOpen;
    data['itemPos'] = this.itemPos;
    data['globalIp'] = this.globalIp;
    return data;
  }
}

class Config {
  late int port;
  late String channelName;
  late int maxLoginLength;
  late int maxMessageLength;
  late int serverChatHistory;
  late int totalVideoLimit;
  late int userVideoLimit;
  late bool localAdmins;
  late String templateUrl;
  late String youtubeApiKey;
  late Permissions? permissions;
  late List<Emotes> emotes;
  late List<Filters> filters;
  late bool? isVerbose;
  late String? salt;

  Config(
      {required this.port,
      required this.channelName,
      required this.maxLoginLength,
      required this.maxMessageLength,
      required this.serverChatHistory,
      required this.totalVideoLimit,
      required this.userVideoLimit,
      required this.localAdmins,
      required this.templateUrl,
      required this.youtubeApiKey,
      required this.permissions,
      required this.emotes,
      required this.filters,
      required this.isVerbose,
      required this.salt});

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
      emotes = [];
      json['emotes'].forEach((v) {
        emotes.add(new Emotes.fromJson(v));
      });
    }
    if (json['filters'] != null) {
      filters = [];
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
      data['permissions'] = this.permissions?.toJson();
    }
    data['emotes'] = this.emotes.map((v) => v.toJson()).toList();

    data['filters'] = this.filters.map((v) => v.toJson()).toList();

    data['isVerbose'] = this.isVerbose;
    data['salt'] = this.salt;
    return data;
  }
}

class Permissions {
  late List<String> guest;
  late List<String> user;
  late List<String> leader;
  late List<String> admin;

  Permissions({
    required this.guest,
    required this.user,
    required this.leader,
    required this.admin,
  });

  Permissions.fromJson(Map<String, dynamic> json) {
    if (json['guest'] != null) {
      guest = [];
      json['guest'].forEach((v) {
        guest.add(v);
      });
    }
    if (json['user'] != null) {
      user = [];
      json['user'].forEach((v) {
        user.add(v);
      });
    }
    if (json['leader'] != null) {
      leader = [];
      json['leader'].forEach((v) {
        leader.add(v);
      });
    }
    if (json['admin'] != null) {
      admin = [];
      json['admin'].forEach((v) {
        admin.add(v);
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['guest'] = this.guest;
    data['user'] = this.user;
    data['leader'] = this.leader;
    data['admin'] = this.admin;
    return data;
  }
}

class Emotes {
  late String name;
  late String image;

  Emotes({required this.name, required this.image});

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
  late String name;
  late String regex;
  late String flags;
  late String replace;

  Filters(
      {required this.name,
      required this.regex,
      required this.flags,
      required this.replace});

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
  late String text;
  late String name;
  late String time;

  History({required this.text, required this.name, required this.time});

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
  late String name;
  late int group;

  Client({required this.name, required this.group});

  Client.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    group = json['group'];
  }

  bool get isBanned => group & 1 != 0;
  bool get isUser => group & 2 != 0;
  bool get isLeader => group & 4 != 0;
  bool get isAdmin => group & 8 != 0;

  set isLeader(bool flag) {
    if (flag) {
      group |= 4;
    } else {
      group &= -1 - 4;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['group'] = this.group;
    return data;
  }
}

class VideoList {
  late String url;
  late String title;
  late String author;
  late double duration;
  late String? subs;
  late bool isTemp;
  late bool isIframe;

  VideoList(
      {required this.url,
      required this.title,
      required this.author,
      required this.duration,
      this.subs,
      required this.isTemp,
      required this.isIframe});

  VideoList.fromJson(Map<String, dynamic> json) {
    url = json['url'];
    title = json['title'];
    author = json['author'];
    duration = json['duration'].toDouble();
    subs = json['subs'];
    isTemp = json['isTemp'];
    isIframe = json['isIframe'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['url'] = this.url;
    data['title'] = this.title;
    data['author'] = this.author;
    data['duration'] = this.duration;
    data['subs'] = this.subs;
    data['isTemp'] = this.isTemp;
    data['isIframe'] = this.isIframe;
    return data;
  }
}

class Login {
  late String clientName;
  late String? passHash;
  late List<Client>? clients;
  late bool? isUnknownClient;

  Login(
      {required this.clientName,
      required this.passHash,
      required this.clients,
      required this.isUnknownClient});

  Login.fromJson(Map<String, dynamic> json) {
    clientName = json['clientName'];
    passHash = json['passHash'];
    if (json['clients'] != null) {
      List<Client> clients = [];
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
      this.clients = clients;
    }
    isUnknownClient = json['isUnknownClient'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['clientName'] = this.clientName;
    data['passHash'] = this.passHash;
    data['clients'] = this.clients?.map((v) => v.toJson()).toList();
    data['isUnknownClient'] = this.isUnknownClient;
    return data;
  }
}

class Logout {
  late String oldClientName;
  late String clientName;
  late List<Client> clients;

  Logout(
      {required this.oldClientName,
      required this.clientName,
      required this.clients});

  Logout.fromJson(Map<String, dynamic> json) {
    oldClientName = json['oldClientName'];
    clientName = json['clientName'];
    if (json['clients'] != null) {
      clients = [];
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['oldClientName'] = this.oldClientName;
    data['clientName'] = this.clientName;
    data['clients'] = this.clients.map((v) => v.toJson()).toList();
    return data;
  }
}

class Message {
  late String clientName;
  late String text;

  Message({required this.clientName, required this.text});

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
  late String textId;

  ServerMessage({required this.textId});

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
  late List<Client> clients;

  UpdateClients({required this.clients});

  UpdateClients.fromJson(Map<String, dynamic> json) {
    if (json['clients'] != null) {
      clients = [];
      json['clients'].forEach((v) {
        clients.add(new Client.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['clients'] = this.clients.map((v) => v.toJson()).toList();
    return data;
  }
}

class AddVideo {
  late VideoList item;
  late bool atEnd;

  AddVideo({required this.item, required this.atEnd});

  AddVideo.fromJson(Map<String, dynamic> json) {
    item = new VideoList.fromJson(json['item']);
    atEnd = json['atEnd'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['item'] = this.item.toJson();
    data['atEnd'] = this.atEnd;
    return data;
  }
}

class RemoveVideo {
  late String url;

  RemoveVideo({required this.url});

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
  late double time;

  Pause({required this.time});

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
  late double time;
  late bool paused;
  late double rate;

  GetTime({required this.time, required this.paused, required this.rate});

  GetTime.fromJson(Map<String, dynamic> json) {
    time = json['time'].toDouble();
    paused = json['paused'] ?? false;
    rate = json['rate'] ?? 1;
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
  late double rate;

  SetRate({required this.rate});

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
  late String clientName;

  SetLeader({required this.clientName});

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
  late int pos;

  PlayItem({required this.pos});

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
  late List<VideoList> videoList;

  UpdatePlaylist({required this.videoList});

  UpdatePlaylist.fromJson(Map<String, dynamic> json) {
    if (json['videoList'] != null) {
      videoList = [];
      json['videoList'].forEach((v) {
        videoList.add(new VideoList.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['videoList'] = this.videoList.map((v) => v.toJson()).toList();
    return data;
  }
}

class TogglePlaylistLock {
  late bool isOpen;

  TogglePlaylistLock({required this.isOpen});

  TogglePlaylistLock.fromJson(Map<String, dynamic> json) {
    isOpen = json['isOpen'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['isOpen'] = this.isOpen;
    return data;
  }
}
