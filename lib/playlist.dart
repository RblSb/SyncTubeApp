import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/playlist.dart';
import 'color_scheme.dart';
import 'wsdata.dart';

class Playlist extends StatelessWidget {
  const Playlist({Key? key}) : super(key: key);

  Widget plailistItem(
    BuildContext context,
    PlaylistModel playlist, {
    required VideoList item,
    required int pos,
  }) {
    const containerPadding = EdgeInsets.all(5.0);
    const paddingNum = 5.0;
    const btnPadding = EdgeInsets.all(paddingNum);
    final isActive = pos == playlist.pos;
    final time = item.isIframe ? '' : duration(item.duration);
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).primaryColor
            : Theme.of(context).canvasColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).playlistItemBorder,
          ),
        ),
      ),
      padding: containerPadding,
      child: Wrap(
        children: <Widget>[
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: item.url));
              Scaffold.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Video URL is copied',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.black45,
                ),
              );
            },
            child: Row(
              children: [
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
                      softWrap: false,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => playlist.sendPlayItem(pos),
                tooltip: 'Play item',
                icon: Icon(
                  Icons.play_arrow,
                  size: 30,
                  color: Theme.of(context).icon,
                ),
              ),
              IconButton(
                onPressed: () => playlist.sendSetNextItem(pos),
                tooltip: 'Set item as next',
                icon: Icon(
                  Icons.arrow_upward,
                  size: 30,
                  color: Theme.of(context).icon,
                ),
              ),
              IconButton(
                onPressed: () => playlist.sendToggleItemType(pos),
                tooltip: 'Lock/unlock item',
                icon: Icon(
                  item.isTemp ? Icons.lock_open : Icons.lock,
                  size: 30,
                  color: Theme.of(context).icon,
                ),
              ),
              IconButton(
                onPressed: () {
                  playlist.sendRemoveItem(playlist.getItem(pos).url);
                },
                tooltip: 'Remove item',
                icon: Icon(
                  Icons.clear,
                  size: 30,
                  color: Theme.of(context).icon,
                ),
              ),
            ],
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
    final playlist = Provider.of<PlaylistModel>(context);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      scrollDirection: Axis.vertical,
      itemCount: playlist.length,
      itemBuilder: (context, index) {
        final item = playlist.getItem(index);
        return plailistItem(
          context,
          playlist,
          item: item,
          pos: index,
        );
      },
    );
  }
}
