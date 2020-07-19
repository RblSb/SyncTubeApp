import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

class ChatItem {
  final String name;
  final String text;

  ChatItem(this.name, this.text);

  Widget buildTitle(BuildContext context) => Text(name);

  Widget buildSubtitle(BuildContext context) {
    final chat = Provider.of<ChatModel>(context, listen: false);
    if (chat.emotesPattern == null) {
      return Text(text);
    }
    final List<InlineSpan> childs = [];
    const empty = '';
    text.splitMapJoin(
      chat.emotesPattern!,
      onMatch: (m) {
        final emote = chat.emotes.firstWhere(
          (element) => element.name == m.group(1),
        );
        childs.add(WidgetSpan(
          child: Image.network(emote.image),
        ));
        return empty;
      },
      onNonMatch: (n) {
        childs.add(TextSpan(text: n));
        return empty;
      },
    );
    return RichText(
      text: TextSpan(children: childs),
    );
  }
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
