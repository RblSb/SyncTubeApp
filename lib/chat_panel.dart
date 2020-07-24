import 'package:flutter/material.dart';

import 'models/app.dart';
import 'color_scheme.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    Key? key,
    required this.app,
  }) : super(key: key);

  final AppModel app;

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => app.togglePanel(MainTab.playlist),
              tooltip: 'Show playlist',
              icon: Icon(
                Icons.list,
                color: app.mainTab == MainTab.playlist
                    ? Theme.of(context).buttonColor
                    : Theme.of(context).icon,
                size: 30,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final text = app.clients.map((c) {
                if (c.isLeader) return '${c.name} (Leader)';
                return c.name;
              }).join(', ');
              Scaffold.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    text,
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.black45,
                ),
              );
            },
            child: Text(
              !app.isConnected
                  ? 'Connection...'
                  : '${app.clients.length} online',
              style: TextStyle(color: Theme.of(context).icon),
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: paddingNum),
            child: ButtonTheme(
              minWidth: 60,
              height: 30,
              child: leaderButton(context),
            ),
          ),
          Padding(
            padding: btnPadding,
            child: IconButton(
              onPressed: () => app.togglePanel(MainTab.settings),
              tooltip: 'Show settings',
              icon: Icon(
                Icons.settings,
                color: app.mainTab == MainTab.settings
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

  Widget leaderButton(BuildContext context) {
    return OutlineButton(
      borderSide: BorderSide(
        color: app.isLeader()
            ? Theme.of(context).leaderActiveBorder
            : Theme.of(context).cardColor,
      ),
      shape: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        'Leader',
        style: app.isLeader() ? null : TextStyle(color: Theme.of(context).icon),
      ),
      onPressed: app.requestLeader,
    );
  }
}
