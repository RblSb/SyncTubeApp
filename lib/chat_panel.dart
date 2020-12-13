import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app.dart';
import 'models/chat_panel.dart';
import 'color_scheme.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ChatPanelModel panel = Provider.of<ChatPanelModel>(context);
    const paddingNum = 5.0;
    const btnPadding = EdgeInsets.all(paddingNum);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingNum),
      color: Theme.of(context).chatPanelBackground,
      child: Row(
        children: <Widget>[
          Padding(
            padding: btnPadding,
            child: IconButton(
              onPressed: () => panel.togglePanel(MainTab.playlist),
              tooltip: 'Show playlist',
              icon: Icon(
                Icons.list,
                color: panel.mainTab == MainTab.playlist
                    ? Theme.of(context).buttonColor
                    : Theme.of(context).icon,
                size: 30,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final text = panel.clients.map((c) {
                if (c.isLeader) return '${c.name} (Leader)';
                return c.name;
              }).join(', ');
              Scaffold.of(context).hideCurrentSnackBar();
              Scaffold.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 3),
                  content: GestureDetector(
                    onTap: () => Scaffold.of(context).hideCurrentSnackBar(),
                    child: Text(
                      text,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  backgroundColor: Colors.black45,
                ),
              );
            },
            child: _onlineButton(panel, context),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: paddingNum),
            child: ButtonTheme(
              minWidth: 60,
              height: 30,
              child: leaderButton(panel, context),
            ),
          ),
          Padding(
            padding: btnPadding,
            child: IconButton(
              onPressed: () => panel.togglePanel(MainTab.settings),
              tooltip: 'Show settings',
              icon: Icon(
                Icons.settings,
                color: panel.mainTab == MainTab.settings
                    ? Theme.of(context).buttonColor
                    : Theme.of(context).icon,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget leaderButton(ChatPanelModel panel, BuildContext context) {
    return OutlineButton(
      borderSide: BorderSide(
        color: panel.isLeader()
            ? Theme.of(context).leaderActiveBorder
            : Theme.of(context).cardColor,
      ),
      shape: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        'Leader',
        style:
            panel.isLeader() ? null : TextStyle(color: Theme.of(context).icon),
      ),
      onPressed: panel.requestLeader,
    );
  }

  Widget _onlineButton(ChatPanelModel panel, BuildContext context) {
    return Row(
      children: [
        Text(
          !panel.isConnected
              ? 'Connection...'
              : '${panel.clients.length} online',
          style: TextStyle(color: Theme.of(context).icon),
        ),
        if (panel.hasLeader())
          Icon(
            panel.serverPlay ? Icons.play_arrow : Icons.pause,
            color: Theme.of(context).icon,
          )
      ],
    );
  }
}
