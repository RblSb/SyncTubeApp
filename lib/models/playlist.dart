import 'package:flutter/foundation.dart';

import '../wsdata.dart';
import 'app.dart';

class PlaylistModel extends ChangeNotifier {
  PlaylistModel(this._app);

  final AppModel _app;
  List<VideoList> _videoList = [];
  final Map<String, double> _progress = {};
  int _pos = 0;
  // ignore: unused_field
  bool _isOpen = true;
  int get length => _videoList.length;
  int get pos => _pos;

  double itemProgress(String url) => _progress[url] ?? 0;

  void sendPlayItem(int pos) {
    _app.send(
      WsData(
        type: 'PlayItem',
        playItem: PlayItem(pos: pos),
      ),
    );
  }

  void sendSetNextItem(int pos) {
    _app.send(
      WsData(
        type: 'SetNextItem',
        setNextItem: PlayItem(pos: pos),
      ),
    );
  }

  void sendToggleItemType(int pos) {
    _app.send(
      WsData(
        type: 'ToggleItemType',
        toggleItemType: PlayItem(pos: pos),
      ),
    );
  }

  void sendRemoveItem(String url) {
    _app.send(
      WsData(
        type: 'RemoveVideo',
        removeVideo: RemoveVideo(url: url),
      ),
    );
  }

  void setPos(int pos) {
    _pos = pos;
    notifyListeners();
  }

  VideoList? getItem(int pos) {
    if (pos >= length) return null;
    return _videoList[pos];
  }

  int indexWhere(bool Function(VideoList) test) {
    return _videoList.indexWhere(test);
  }

  void addItem(VideoList item, bool atEnd) {
    if (atEnd) {
      _videoList.add(item);
    } else {
      _safeInsert(_pos + 1, item);
    }
    notifyListeners();
  }

  void update(List<VideoList> items) {
    _videoList = items;
    notifyListeners();
  }

  void clear() {
    _pos = 0;
    _progress.clear();
    update([]);
  }

  bool isEmpty() {
    return _videoList.isEmpty;
  }

  void removeItem(int index) {
    _progress.remove(_videoList[index].url);
    if (index < _pos) _pos--;
    _videoList.remove(_videoList[index]);
    if (_pos >= _videoList.length) _pos = 0;
    notifyListeners();
  }

  void removeItemByUrl(String url) {
    final index = indexWhere((item) => item.url == url);
    if (index == -1) return;
    removeItem(index);
  }

  void setItemProgress(String url, double ratio) {
    if (indexWhere((item) => item.url == url) == -1) return;
    _progress[url] = ratio;
    notifyListeners();
  }

  void completeItem(String url) {
    final index = indexWhere((item) => item.url == url);
    if (index == -1) return;
    final item = _videoList[index];
    if (item.isIncomplete != true) return;
    final wasPlayable = item.isPlayable();
    item.isIncomplete = false;
    _progress.remove(url);
    notifyListeners();
    if (index == _pos && !wasPlayable) _app.player.loadVideo(index);
  }

  void skipItem() {
    final item = _videoList[_pos];
    if (!item.isTemp) {
      _pos++;
    } else {
      _progress.remove(item.url);
      _videoList.remove(item);
    }
    if (_pos >= _videoList.length) _pos = 0;
    notifyListeners();
  }

  void setNextItem(int itemPos) {
    final next = _videoList[itemPos];
    _videoList.remove(next);
    if (itemPos < _pos) _pos--;
    _safeInsert(_pos + 1, next);
    notifyListeners();
  }

  void _safeInsert(int pos, VideoList item) {
    if (pos < _videoList.length) {
      _videoList.insert(pos, item);
    } else {
      _videoList.add(item);
    }
  }

  void toggleItemType(int pos) {
    _videoList[pos].isTemp = !_videoList[pos].isTemp;
    notifyListeners();
  }

  void setPlaylistLock(bool state) {
    _isOpen = state;
    notifyListeners();
  }
}
