import 'package:flutter/foundation.dart';
import './app.dart';
import '../wsdata.dart';

class ChatPanelModel extends ChangeNotifier {
  ChatPanelModel(this._app);

  final AppModel _app;
  bool _serverPlay = true;

  bool get serverPlay => _serverPlay;

  MainTab get mainTab => _app.mainTab;

  List<Client> get clients => _app.clients;

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  set isConnected(bool isConnected) {
    if (_isConnected == isConnected) return;
    _isConnected = isConnected;
    notifyListeners();
  }

  bool hasLeader() => _app.hasLeader();

  bool isLeader() => _app.isLeader();

  void requestLeader() => _app.requestLeader();

  void requestLeaderAndPause() async {
    _app.requestLeader();
    if (_app.isLeader()) return;
    _app.player.pause();
    final posD = await _app.player.getPosition();
    final time = posD.inMilliseconds / 1000;
    _app.send(WsData(
      type: 'Pause',
      pause: Pause(time: time),
    ));
  }

  togglePanel(MainTab newTab) => _app.togglePanel(newTab);

  set serverPlay(bool serverPlay) {
    if (_serverPlay == serverPlay) return;
    _serverPlay = serverPlay;
    notifyListeners();
  }
}
