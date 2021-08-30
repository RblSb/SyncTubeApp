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
      if (handleCommands(text.substring(1))) return;
    }
    _app.send(WsData(
      type: 'Message',
      message: Message(clientName: '', text: text),
    ));
  }

  bool handleCommands(String command) {
    final args = command.trim().split(' ');
    command = args.removeAt(0);
    switch (command) {
      case 'ban':
        mergeRedundantArgs(args, 0, 2);
        final name = elementAt(args, 0) ?? '';
        final time = parseSimpleDate(elementAt(args, 1));
        if (time <= 0) return true;
        _app.send(WsData(
          type: 'BanClient',
          banClient: BanClient(
            name: name,
            time: time,
          ),
        ));
        return true;
      case 'unban':
      case 'removeBan':
        mergeRedundantArgs(args, 0, 1);
        final name = elementAt(args, 0) ?? '';
        _app.send(WsData(
          type: 'BanClient',
          banClient: BanClient(
            name: name,
            time: 0,
          ),
        ));
        return true;
      case 'kick':
        mergeRedundantArgs(args, 0, 1);
        final name = elementAt(args, 0) ?? '';
        _app.send(WsData(
          type: 'KickClient',
          kickClient: KickClient(
            name: name,
          ),
        ));
        return true;
      case 'clear':
        if (_app.isAdmin())
          _app.send(WsData(type: 'ClearChat'));
        else
          clearChat();
        return true;
      case 'fb':
      case 'flashback':
        _app.send(WsData(type: 'Flashback'));
        return false;
      default:
    }
    if (matchSimpleDate.hasMatch(command)) {
      _app.send(WsData(
        type: 'Rewind',
        rewind: Pause(time: parseSimpleDate(command).toDouble()),
      ));
    }
    return false;
  }

  T? elementAt<T>(List<T> arr, int pos) {
    if (pos < arr.length) return arr[pos];
    return null;
  }

  final matchSimpleDate =
      RegExp(r'^-?([0-9]+d)?([0-9]+h)?([0-9]+m)?([0-9]+s?)?$');

  int parseSimpleDate(String? text) {
    if (text == null) return 0;
    if (!matchSimpleDate.hasMatch(text)) return 0;
    List<String> matches = [];
    final match = matchSimpleDate.firstMatch(text);
    final length = match!.groupCount + 1;
    for (var i = 1; i < length; i++) {
      final group = match.group(i);
      if (group == null) continue;
      matches.add(group);
    }
    var seconds = 0;
    for (final block in matches) {
      seconds += _parseSimpleDateBlock(block);
    }
    if (text.startsWith('-')) seconds = -seconds;
    return seconds;
  }

  int _parseSimpleDateBlock(String block) {
    if (block.endsWith('s'))
      return _time(block);
    else if (block.endsWith('m'))
      return _time(block) * 60;
    else if (block.endsWith('h'))
      return _time(block) * 60 * 60;
    else if (block.endsWith('d')) return _time(block) * 60 * 60 * 24;
    return int.parse(block);
  }

  int _time(String block) {
    return int.parse(block.substring(0, block.length - 1));
  }

  void mergeRedundantArgs(List<String> args, int pos, int newLength) {
    final count = args.length - (newLength - 1);
    if (count < 2) return;
    args.insert(pos, args.sublist(pos, pos + count).join(" "));
    args.removeRange(pos + 1, pos + count + 1);
  }

  void clearChat() {
    _items.clear();
    notifyListeners();
  }
}
