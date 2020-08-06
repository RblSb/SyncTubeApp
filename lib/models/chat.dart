import 'package:flutter/foundation.dart';
import 'dart:collection';
import './app.dart';
import '../chat.dart';
import '../wsdata.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ChatModel extends ChangeNotifier {
  ChatModel(this._app);

  final AppModel _app;
  var _isUnknownClient = true;

  get isUnknownClient => _isUnknownClient;

  int get maxLoginLength => _app.config?.maxLoginLength ?? -1;

  int get maxMessageLength => _app.config?.maxMessageLength ?? -1;

  set isUnknownClient(isUnknownClient) {
    if (_isUnknownClient == isUnknownClient) return;
    _isUnknownClient = isUnknownClient;
    notifyListeners();
  }

  var _showPasswordField = false;

  get showPasswordField => _showPasswordField;

  set showPasswordField(showPasswordField) {
    if (_showPasswordField == showPasswordField) return;
    _showPasswordField = showPasswordField;
    notifyListeners();
  }

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

  void sendLogin(Login login) {
    _app.send(WsData(
      type: 'Login',
      login: login,
    ));
  }

  String passwordHash(String password) {
    final salt = _app.config?.salt ?? '';
    List<int> bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
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
