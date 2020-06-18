import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/playlist.dart';
import 'color_scheme.dart';
import 'wsdata.dart';

class Playlist extends StatelessWidget {
  const Playlist({
    Key key,
  }) : super(key: key);

  Widget plailistItem(
    BuildContext context,
    PlaylistModel playlist, {
    VideoList item,
    int pos,
  }) {
    const containerPadding = EdgeInsets.all(5.0);
    const paddingNum = 5.0;
    const btnPadding = EdgeInsets.all(paddingNum);
    final isActive = pos == playlist.pos;
    final time = item.isIframe ? "" : duration(item.duration);
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).primaryColor
            : Theme.of(context).canvasColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).itemBorderColor,
          ),
        ),
      ),
      padding: containerPadding,
      child: Row(
        children: <Widget>[
          Padding(
            padding: btnPadding,
            child: Text(time),
          ),
          Expanded(
            child: Container(
              padding: btnPadding,
              child: Text(
                item.title,
                overflow: TextOverflow.fade,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => playlist.sendPlayItem(pos),
            tooltip: 'Play item',
            icon: Icon(
              Icons.play_arrow,
              size: 30,
              color: Theme.of(context).iconColor,
            ),
          ),
          IconButton(
            onPressed: () => playlist.sendSetNextItem(pos),
            tooltip: 'Set item as next',
            icon: Icon(
              Icons.arrow_upward,
              size: 30,
              color: Theme.of(context).iconColor,
            ),
          ),
          IconButton(
            onPressed: () => playlist.sendToggleItemType(pos),
            tooltip: 'Lock/unlock item',
            icon: Icon(
              item.isTemp ? Icons.lock_open : Icons.lock,
              size: 30,
              color: Theme.of(context).iconColor,
            ),
          ),
          IconButton(
            onPressed: () {
              print(playlist.getItem(pos).url);
              playlist.sendRemoveItem(playlist.getItem(pos).url);
            },
            tooltip: 'Remove item',
            icon: Icon(
              Icons.clear,
              size: 30,
              color: Theme.of(context).iconColor,
            ),
          ),
        ],
      ),
    );
  }

  String duration(double timeNum) {
    final h = timeNum / 60 ~/ 60;
    final m = timeNum ~/ 60 - h * 60;
    final s = (timeNum % 60).toInt();
    var time = '$m:';
    if (m < 10) time = '0$time';
    if (h > 0) time = '$h:$time';
    if (s < 10) time = time + '0';
    time += s.toString();
    return time;
  }

  @override
  Widget build(BuildContext context) {
    print("Rebuild playlist");
    final playlist = Provider.of<PlaylistModel>(context);
    List<Widget> items = [];
    for (var i = 0; i < playlist.length; i++) {
      final item = playlist.getItem(i);
      items.add(
        plailistItem(
          context,
          playlist,
          item: item,
          pos: i,
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        children: items,
      ),
    );
  }
}
