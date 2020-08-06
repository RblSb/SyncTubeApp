import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/chat.dart';
import 'color_scheme.dart';
import 'emotes_tab.dart';
import 'settings.dart';
import 'wsdata.dart';

class Chat extends StatefulWidget {
  Chat({
    Key? key,
  }) : super(key: key);

  @override
  _ChatState createState() => _ChatState();
}

final _imgPattern =
    RegExp(r"(https?:\/\/[^']*\.)(png|jpg|gif|jpeg|webp)([^' ,]*)");
final _urlPattern = RegExp(r"(^|[^'])(https?:\/\/[^' \t]*)");
final _textPattern = RegExp(r'[^\t]+');

class ChatItem {
  static const tabChar = '\t';
  final String name;
  final String text;
  late String date;

  ChatItem(this.name, this.text, [String? date]) {
    if (date != null) {
      this.date = date;
      return;
    }
    final d = DateTime.now();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    this.date = '$h:$m:$s';
  }

  Widget buildTitle(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ),
        Text(
          date,
          style: TextStyle(
            color: Theme.of(context).timeStamp,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget buildSubtitle(BuildContext context) {
    final chat = Provider.of<ChatModel>(context, listen: false);
    final List<_OrderedSpan> childs = [];
    var text = _parseEmotes(childs, chat, this.text);

    text = text.splitMapJoin(
      _imgPattern,
      onMatch: (match) {
        final link = match.group(1)! + match.group(2)! + match.group(3)!;
        childs.add(_OrderedSpan(
          match.start,
          WidgetSpan(
            child: InkWell(
              child: Image.network(
                link,
                fit: BoxFit.scaleDown,
                height: MediaQuery.of(context).size.height / 4,
              ),
              onTap: () => launch(link),
            ),
          ),
        ));
        return tabChar * link.length;
      },
      onNonMatch: (text) => text,
    );

    text = text.splitMapJoin(
      _urlPattern,
      onMatch: (match) {
        final link = match.group(2)!;
        childs.add(_OrderedSpan(
          match.start,
          TextSpan(
              text: link,
              style: TextStyle(color: Colors.blue),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  if (await canLaunch(link)) launch(link);
                }),
        ));
        return match.group(1)! + tabChar * link.length;
      },
      onNonMatch: (text) => text,
    );

    text.splitMapJoin(
      _textPattern,
      onMatch: (match) {
        childs.add(_OrderedSpan(
          match.start,
          TextSpan(
            text: match.group(0),
          ),
        ));
        return tabChar;
      },
      onNonMatch: (text) => tabChar,
    );

    childs.sort((a, b) => a.pos - b.pos);
    return RichText(
      text: TextSpan(children: childs.map((e) => e.obj).toList()),
    );
  }

  String _parseEmotes(List<_OrderedSpan> childs, ChatModel chat, String text) {
    if (chat.emotesPattern == null) return text;
    return text.splitMapJoin(
      chat.emotesPattern!,
      onMatch: (match) {
        final text = match.group(1)!;
        final emote = chat.emotes.firstWhere(
          (element) => element.name == text,
        );
        childs.add(_OrderedSpan(
          match.start,
          WidgetSpan(
            child: Image.network(emote.image),
          ),
        ));
        return tabChar * text.length;
      },
      onNonMatch: (text) => text,
    );
  }
}

class _OrderedSpan<T> {
  const _OrderedSpan(this.pos, this.obj);
  final int pos;
  final InlineSpan obj;
}

class _ChatState extends State<Chat> {
  final ScrollController chatScroll = ScrollController();
  final textController = TextEditingController();
  final inputFocus = FocusNode();
  final List<int> rewindOptions = [-80, -30, -10, 10, 30, 80];
  bool showEmotesTab = false;
  bool showRewindMenu = false;
  bool reopenKeyboard = false;

  void scrollAfterFrame() {
    // Doesn't works well
    if (!chatScroll.hasClients) return;
    final lastPos = chatScroll.position.pixels;
    final scrollAtEnd = lastPos <= 20;
    if (scrollAtEnd) return;
    final lastMax = chatScroll.position.maxScrollExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final diff = chatScroll.position.maxScrollExtent - lastMax;
      chatScroll.jumpTo(
        lastPos + diff,
        // duration: const Duration(milliseconds: 100),
        // curve: Curves.easeOut,
      );
    });
  }

  String _hintText(ChatModel chat) {
    if (chat.showPasswordField) return 'Enter Password...';
    return chat.isUnknownClient ? 'Your Name' : 'Send a message...';
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatModel>(context);
    scrollAfterFrame();
    final list = ListView.builder(
      reverse: true,
      padding: EdgeInsets.zero,
      controller: chatScroll,
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      itemCount: chat.items.length,
      itemBuilder: (context, index) {
        final item = chat.items[index];
        return ListTile(
          visualDensity: VisualDensity.compact,
          title: item.buildTitle(context),
          subtitle: item.buildSubtitle(context),
        );
      },
    );
    return Column(
      children: [
        Expanded(child: list),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: showRewindMenu ? 1 : 0,
          child: showRewindMenu
              ? SizedBox(
                  height: 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final time in rewindOptions)
                        Expanded(
                          child: FlatButton(
                            padding: EdgeInsets.zero,
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(time.toString(), maxLines: 1),
                            ),
                            onPressed: () {
                              chat.sendMessage('/${time}');
                              setState(() => showRewindMenu = false);
                            },
                          ),
                        ),
                    ],
                  ),
                )
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: TextField(
                inputFormatters: [
                  if (chat.isUnknownClient)
                    FilteringTextInputFormatter.deny(RegExp('[&^<>\'"]')),
                  chat.isUnknownClient
                      ? LengthLimitingTextInputFormatter(chat.maxLoginLength)
                      : LengthLimitingTextInputFormatter(chat.maxMessageLength)
                ],
                textCapitalization: TextCapitalization.sentences,
                controller: textController,
                focusNode: inputFocus,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(14),
                  hintText: _hintText(chat),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onTap: () {
                  setState(() {
                    showRewindMenu = false;
                    showEmotesTab = false;
                  });
                },
                onSubmitted: (String text) async {
                  textController.clear();
                  if (chat.showPasswordField) {
                    chat.sendLogin(Login(
                      clientName: await Settings.getSavedName(),
                      passHash: chat.passwordHash(text),
                      isUnknownClient: null,
                      clients: null,
                    ));
                  } else if (chat.isUnknownClient) {
                    // if (text.length == 0) return;
                    chat.sendLogin(Login(
                      clientName: text,
                      passHash: null,
                      isUnknownClient: null,
                      clients: null,
                    ));
                    final prefs = await SharedPreferences.getInstance();
                    prefs.setString('savedName', text);
                  } else {
                    chat.sendMessage(text);
                  }
                  SystemChrome.restoreSystemUIOverlays();
                },
              ),
            ),
            if (!chat.isUnknownClient)
              GestureDetector(
                onLongPress: () {
                  setState(() => showRewindMenu = !showRewindMenu);
                },
                child: IconButton(
                  padding: const EdgeInsets.only(left: 10, right: 20),
                  onPressed: () {
                    if (showRewindMenu) {
                      setState(() => showRewindMenu = false);
                      return;
                    }
                    setState(() {
                      showEmotesTab = !showEmotesTab;
                      if (showEmotesTab) {
                        reopenKeyboard = inputFocus.hasFocus;
                        inputFocus.unfocus();
                      } else {
                        if (reopenKeyboard && textController.text.isNotEmpty)
                          inputFocus.requestFocus();
                        reopenKeyboard = false;
                      }
                    });
                    SystemChrome.restoreSystemUIOverlays();
                  },
                  // tooltip: 'Show emotes',
                  icon: Icon(
                    showRewindMenu ? Icons.close : Icons.mood,
                    size: 35,
                    color: showEmotesTab
                        ? Theme.of(context).buttonColor
                        : Theme.of(context).icon,
                  ),
                ),
              ),
          ],
        ),
        if (showEmotesTab)
          EmotesTab(
            emotes: chat.emotes,
            input: textController,
          )
      ],
    );
  }
}
