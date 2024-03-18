import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/playlist.dart';
import 'color_scheme.dart';
import 'wsdata.dart';

class Playlist extends StatelessWidget {
  const Playlist({Key? key}) : super(key: key);

  Widget playlistItem(
    BuildContext context,
    PlaylistModel playlist, {
    required VideoList item,
    required int pos,
  }) {
    const containerPadding = EdgeInsets.all(5.0);
    final isActive = pos == playlist.pos;
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      double parentWidth = constraints.maxWidth;
      double? iconMinW = parentWidth > 150 ? null : 40;
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
          children: [
            titleLine(
              context,
              item: item,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                playlistBtn(
                  context,
                  size: iconMinW,
                  onPressed: () => playlist.sendPlayItem(pos),
                  tooltip: 'Play item',
                  iconData: Icons.play_arrow,
                ),
                playlistBtn(
                  context,
                  size: iconMinW,
                  onPressed: () => playlist.sendSetNextItem(pos),
                  tooltip: 'Set item as next',
                  iconData: Icons.arrow_upward,
                ),
                if (parentWidth > 200)
                  playlistBtn(
                    context,
                    size: iconMinW,
                    onPressed: () => playlist.sendToggleItemType(pos),
                    tooltip: 'Lock/unlock item',
                    iconData: item.isTemp ? Icons.lock_open : Icons.lock,
                  ),
                playlistBtn(
                  context,
                  size: iconMinW,
                  onPressed: () {
                    final item = playlist.getItem(pos);
                    if (item == null) return;
                    playlist.sendRemoveItem(item.url);
                  },
                  tooltip: 'Remove item',
                  iconData: Icons.clear,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget titleLine(
    BuildContext context, {
    required VideoList item,
  }) {
    final time = item.isIframe ? '' : duration(item.duration);
    const btnPadding = EdgeInsets.all(5.0);
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: item.url));
        ScaffoldMessenger.of(context).showSnackBar(
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
    );
  }

  Widget playlistBtn(
    BuildContext context, {
    double? size = null,
    required void Function() onPressed,
    required String tooltip,
    required IconData iconData,
  }) {
    return Container(
      padding: const EdgeInsets.all(0.0),
      width: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        // constraints: iconConstraints,
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(
          iconData,
          size: 30,
          color: Theme.of(context).icon,
        ),
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
    final playlist = context.watch<PlaylistModel>();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      scrollDirection: Axis.vertical,
      itemCount: playlist.length,
      itemBuilder: (context, index) {
        final item = playlist.getItem(index)!;
        return playlistItem(
          context,
          playlist,
          item: item,
          pos: index,
        );
      },
    );
  }
}
