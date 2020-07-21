import 'package:flutter/foundation.dart';
import 'dart:collection';
import './app.dart';
import '../chat.dart';
import '../wsdata.dart';

class ChatModel extends ChangeNotifier {
  ChatModel(this._app);

  final AppModel _app;
  List<ChatItem> _items = [];
  List<Emotes> _emotes = [];
  RegExp? emotesPattern;
  UnmodifiableListView<ChatItem> get items => UnmodifiableListView(_items);
  UnmodifiableListView<Emotes> get emotes => UnmodifiableListView(_emotes);

  void setItems(List<ChatItem> items) {
    _items = items.reversed.toList();
    notifyListeners();
  }

  void addItem(ChatItem item) {
    _items.insert(0, item);
    if (_items.length > 200) _items.removeLast();
    notifyListeners();
  }

  void setEmotes(List<Emotes> emotes) {
    _emotes = emotes;
    emotesPattern = RegExp('(' +
        escapeRegExp(
          emotes.map((e) => e.name).join('\t'),
        ).replaceAll('\t', '|') +
        ')');
    notifyListeners();
  }

  final matchRegExp = RegExp(r'/([.*+?^${}()|[\]\\])');

  String escapeRegExp(String regex) {
    return regex.replaceAllMapped(matchRegExp, (match) {
      return '\\${match.group(1)}';
    });
  }

  void sendMessage(String text) {
    if (text.startsWith('/')) {
      handleCommands(text.substring(1));
    }
    _app.send(WsData(
      type: 'Message',
      message: Message(clientName: '', text: text),
    ));
  }

  final RegExp matchNumbers = RegExp(r'^-?[0-9]+$');

  void handleCommands(String text) {
    switch (text) {
      case 'clear':
        if (_app.isAdmin()) _app.send(WsData(type: 'ClearChat'));
        break;
      default:
    }
    if (matchNumbers.hasMatch(text)) {
      _app.send(WsData(
        type: 'Rewind',
        rewind: Pause(time: int.parse(text).toDouble()),
      ));
    }
  }

  void clearChat() {
    _items.clear();
    notifyListeners();
  }
}
