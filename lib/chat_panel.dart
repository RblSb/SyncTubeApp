import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'color_scheme.dart';
import 'models/app.dart';
import 'models/chat_panel.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<ChatPanelModel>();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double parentW = constraints.maxWidth;
        return Container(
          // padding: EdgeInsets.symmetric(horizontal: paddingNum),
          color: Theme.of(context).chatPanelBackground,
          child: Row(
            children: [
              const Spacer(flex: 3),
              IconButton(
                onPressed: () => panel.togglePanel(MainTab.playlist),
                tooltip: 'Show playlist',
                icon: Icon(
                  Icons.list,
                  color: panel.mainTab == MainTab.playlist
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).icon,
                  size: 30,
                ),
              ),
              const Spacer(flex: 2),
              Flexible(
                flex: 100,
                child: _onlineButton(panel, context),
              ),
              leaderButton(panel, context, parentW),
              const Spacer(flex: 5),
              IconButton(
                onPressed: () => panel.togglePanel(MainTab.settings),
                tooltip: 'Show settings',
                icon: Icon(
                  Icons.settings,
                  color: panel.mainTab == MainTab.settings
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).icon,
                  size: 30,
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        );
      },
    );
  }

  static void showUsersSnackBar(BuildContext context) {
    final panel = context.read<ChatPanelModel>();
    final text = panel.clients
        .map((c) {
          if (c.isLeader) return '${c.name} (Leader)';
          return c.name;
        })
        .join(', ');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          child: Text(
            text,
            style: TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: Colors.black45,
      ),
    );
  }

  Widget leaderButton(
    ChatPanelModel panel,
    BuildContext context,
    double parentW,
  ) {
    final btnPadding = parentW > 270 ? 18.0 : 16.0;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: Size(60, 34),
        padding: EdgeInsets.symmetric(horizontal: btnPadding),
        side: BorderSide(
          color: panel.isLeader()
              ? Theme.of(context).leaderActiveBorder
              : Theme.of(context).cardColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: Text(
        'Leader',
        style: panel.isLeader()
            ? null
            : TextStyle(color: Theme.of(context).icon),
      ),
      onPressed: panel.requestLeader,
      onLongPress: panel.requestLeaderAndPause,
    );
  }

  Widget _onlineButton(ChatPanelModel panel, BuildContext context) {
    final isPlayerIconVisible = panel.lastState.paused || panel.hasLeader();
    final clientsOnlineText = !panel.isConnected
        ? 'Connection...'
        : '${panel.clients.length} online';

    return TextButton(
      onPressed: () => showUsersSnackBar(context),
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              clientsOnlineText,
              style: TextStyle(color: Theme.of(context).icon),
              overflow: .ellipsis,
              maxLines: 1,
            ),
          ),
          if (isPlayerIconVisible)
            Icon(
              panel.lastState.paused ? Icons.pause : Icons.play_arrow,
              color: Theme.of(context).icon,
            ),
        ],
      ),
    );
  }
}
