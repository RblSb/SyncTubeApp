import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'color_scheme.dart';
import 'models/playlist.dart';
import 'wsdata.dart';

class Playlist extends StatelessWidget {
  const Playlist({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<PlaylistModel>();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      scrollDirection: Axis.vertical,
      itemCount: playlist.length,
      itemBuilder: (context, index) {
        final item = playlist.getItem(index)!;
        return PlaylistEntry(
          key: ValueKey(item.url),
          playlist: playlist,
          item: item,
          pos: index,
        );
      },
    );
  }
}

class PlaylistEntry extends StatefulWidget {
  const PlaylistEntry({
    Key? key,
    required this.playlist,
    required this.item,
    required this.pos,
  }) : super(key: key);

  final PlaylistModel playlist;
  final VideoList item;
  final int pos;

  @override
  State<PlaylistEntry> createState() => _PlaylistEntryState();
}

class _PlaylistEntryState extends State<PlaylistEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool get _isIncomplete => widget.item.isIncomplete == true;

  @override
  void initState() {
    super.initState();
    if (_isIncomplete) _blink.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PlaylistEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isIncomplete && !_blink.isAnimating) {
      _blink.repeat(reverse: true);
    } else if (!_isIncomplete && _blink.isAnimating) {
      _blink.stop();
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const containerPadding = EdgeInsets.all(5.0);
    final item = widget.item;
    final theme = Theme.of(context);
    final isActive = widget.pos == widget.playlist.pos;
    final isIncomplete = _isIncomplete;
    final isCached = item.doCache && item.isIncomplete == false;
    final progress = widget.playlist
        .itemProgress(item.url)
        .clamp(0.0, 1.0)
        .toDouble();

    final Color bgColor = isIncomplete
        ? theme.scaffoldBackgroundColor
        : isActive
        ? theme.primaryColor
        : isCached
        ? theme.cardColor
        : theme.scaffoldBackgroundColor;

    final content = Padding(
      padding: containerPadding,
      child: Opacity(
        opacity: isIncomplete ? 0.5 : 1.0,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            double parentWidth = constraints.maxWidth;
            double? iconMinW = parentWidth > 150 ? null : 40;
            return Wrap(
              children: [
                titleLine(context, item: item),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    playlistBtn(
                      context,
                      size: iconMinW,
                      onPressed: () => widget.playlist.sendPlayItem(widget.pos),
                      tooltip: 'Play item',
                      iconData: Icons.play_arrow,
                    ),
                    playlistBtn(
                      context,
                      size: iconMinW,
                      onPressed: () =>
                          widget.playlist.sendSetNextItem(widget.pos),
                      tooltip: 'Set item as next',
                      iconData: Icons.arrow_upward,
                    ),
                    if (parentWidth > 200)
                      playlistBtn(
                        context,
                        size: iconMinW,
                        onPressed: () =>
                            widget.playlist.sendToggleItemType(widget.pos),
                        tooltip: 'Lock/unlock item',
                        iconData: item.isTemp ? Icons.lock_open : Icons.lock,
                      ),
                    playlistBtn(
                      context,
                      size: iconMinW,
                      onPressed: () {
                        final item = widget.playlist.getItem(widget.pos);
                        if (item == null) return;
                        widget.playlist.sendRemoveItem(item.url);
                      },
                      tooltip: 'Remove item',
                      iconData: Icons.clear,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _blink,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: theme.playlistItemBorder),
            ),
          ),
          child: Stack(
            children: [
              if (isIncomplete && progress > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(color: theme.cardColor),
                  ),
                ),
              child!,
              if (isIncomplete)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: Color.lerp(
                      theme.playlistItemBorder,
                      theme.icon,
                      _blink.value,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: content,
    );
  }

  Widget titleLine(
    BuildContext context, {
    required VideoList item,
  }) {
    final time = item.playerType == 'IframeType' ? '' : duration(item.duration);
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
