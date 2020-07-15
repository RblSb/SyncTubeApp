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
                    : Theme.of(context).iconColor,
                size: 30,
              ),
            ),
          ),
          Text(app.clients.length == 0
              ? 'Connection...'
              : '${app.clients.length} online'),
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
                    : Theme.of(context).iconColor,
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
        color: app.isLeader() ? Theme.of(context).leaderActiveBorder : Theme.of(context).cardColor,
      ),
      shape: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Text('Leader'),
      onPressed: app.requestLeader,
    );
  }
}
