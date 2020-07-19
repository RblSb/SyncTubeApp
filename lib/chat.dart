import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/chat.dart';
import 'color_scheme.dart';
import 'emotes_tab.dart';

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

  const ChatItem(this.name, this.text);

  Widget buildTitle(BuildContext context) => Text(name);

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
              child: Image.network(link),
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
        var link = match.group(1)! + match.group(2)!;
        link = link.trim();
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
        return tabChar * link.length;
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
  final int pos;
  final InlineSpan obj;
  const _OrderedSpan(this.pos, this.obj);
}

class _ChatState extends State<Chat> {
  final ScrollController chatScroll = ScrollController();
  final textController = TextEditingController();
  final inputFocus = new FocusNode();
  bool showEmotesTab = false;
  bool reopenKeyboard = false;

  void scrollAfterFrame() {
    if (!chatScroll.hasClients) return;
    final scrollAtEnd =
        chatScroll.position.pixels >= chatScroll.position.maxScrollExtent - 10;
    if (!scrollAtEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatScroll.animateTo(
        chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatModel>(context);
    scrollAfterFrame();
    final list = ListView.builder(
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: textController,
                focusNode: inputFocus,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(14),
                  hintText: 'Send a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onTap: () {
                  setState(() => showEmotesTab = false);
                },
                onSubmitted: (String text) {
                  textController.clear();
                  chat.sendMessage(text);
                  SystemChrome.restoreSystemUIOverlays();
                },
              ),
            ),
            IconButton(
              padding: const EdgeInsets.only(left: 10, right: 20),
              onPressed: () {
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
              tooltip: 'Show emotes',
              icon: Icon(
                Icons.mood,
                size: 35,
                color: showEmotesTab
                    ? Theme.of(context).buttonColor
                    : Theme.of(context).iconColor,
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
