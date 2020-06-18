import 'dart:async';
import 'package:SyncTube/playlist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'chat_panel.dart';
import 'models/app.dart';
import 'settings.dart';
import 'video_player.dart';
import 'wsdata.dart';
import 'chat.dart';
import 'color_scheme.dart';

typedef WsDataFunc = void Function(WsData data);

class App extends StatefulWidget {
  App({
    Key key,
    @required this.name,
    @required this.url,
  }) : super(key: key);

  final String name;
  final String url;

  @override
  State<StatefulWidget> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    SystemChrome.setEnabledSystemUIOverlays([]);
    app = AppModel(widget.url);
    super.initState();
  }

  AppModel app;

  @override
  Widget build(BuildContext context) {
    print('App rebuild');
    final orientation = MediaQuery.of(context).orientation;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app.playlist),
        ChangeNotifierProvider.value(value: app.player),
        ChangeNotifierProvider.value(value: app.chat),
        ChangeNotifierProvider.value(value: app),
      ],
      child: AnnotatedRegion(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
        ),
        child: GestureDetector(
          onTap: () => removeFocus(context),
          child: WillPopScope(
            onWillPop: () => _onWillPop(context),
            child: Scaffold(
              body: Flex(
                direction: orientation == Orientation.landscape
                    ? Axis.horizontal
                    : Axis.vertical,
                children: <Widget>[
                  Container(
                    constraints: BoxConstraints(
                      minWidth: orientation == Orientation.landscape
                          ? MediaQuery.of(context).size.width / (16 / 9)
                          : 0,
                      minHeight: orientation == Orientation.landscape
                          ? 0
                          : MediaQuery.of(context).size.width / (16 / 9),
                      maxWidth: orientation == Orientation.landscape
                          ? MediaQuery.of(context).size.width / 1.75
                          : double.infinity,
                    ),
                    child: VideoPlayerScreen(),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Consumer<AppModel>(
                          builder: (context, app, child) => ChatPanel(app: app),
                        ),
                        Selector<AppModel, int>(
                          selector: (context, app) => app.mainTab.index,
                          builder: (context, index, child) {
                            return Expanded(
                              child: IndexedStack(
                                index: index,
                                children: [
                                  Chat(),
                                  Playlist(),
                                  Settings(),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: Selector<AppModel, bool>(
                selector: (context, app) => app.mainTab == MainTab.playlist,
                builder: (context, isVisible, child) {
                  return Visibility(
                    child: FloatingActionButton(
                      tooltip: 'Add video URL',
                      child: const Icon(Icons.add),
                      onPressed: () => _addUrlDialog(context),
                    ),
                    visible: isVisible,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        app.inBackground();
        break;
      default:
    }
  }

  void removeFocus(BuildContext context) {
    FocusScope.of(context).unfocus();
    SystemChrome.setEnabledSystemUIOverlays([]);
  }

  Future<bool> _onWillPop(BuildContext context) async {
    if (FocusScope.of(context).hasFocus) {
      removeFocus(context);
      return false;
    }
    final dialog = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Are you sure?'),
        content: Text('Do you want to exit channel?'),
        actions: <Widget>[
          FlatButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          FlatButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes'),
          ),
        ],
      ),
    );
    return dialog ?? false;
  }

  Future<AddVideo> _addUrlDialog(BuildContext context) async {
    final clipboard = await Clipboard.getData('text/plain');
    final defaultUrl = 'http://';
    var url = defaultUrl;
    if (clipboard.text.contains('mp4') ||
        clipboard.text.contains('m3u8') ||
        clipboard.text.contains('youtu')) {
      url = clipboard.text;
    }
    final data = AddVideo(
      item: VideoList(
        url: url,
        title: 'Raw Video',
        author: '',
        duration: 0.0,
        isTemp: true,
        isIframe: false,
      ),
      atEnd: true,
    );
    return showDialog<AddVideo>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Server'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      initialValue: data.item.url,
                      autofocus: url == defaultUrl,
                      decoration: InputDecoration(
                        labelText: 'Video URL',
                      ),
                      onChanged: (value) => data.item.url = value,
                    ),
                    CheckboxListTile(
                      title: Text('Add as temporary'),
                      value: data.item.isTemp,
                      onChanged: (flag) => setState(() {
                        data.item.isTemp = flag;
                      }),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                FlatButton(
                  child: Text('Queue next'),
                  onPressed: () {
                    data.atEnd = false;
                    Navigator.of(context).pop(data);
                    app.sendVideoItem(data);
                  },
                ),
                FlatButton(
                  child: Text('Queue last'),
                  onPressed: () {
                    data.atEnd = true;
                    Navigator.of(context).pop(data);
                    app.sendVideoItem(data);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    print('app disposed');
    super.dispose();
    app.dispose();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIOverlays([
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
  }
}

class Printer extends StatelessWidget {
  const Printer({Key key, this.child}) : super(key: key);
  final Widget child;
  @override
  Widget build(BuildContext context) {
    print('child rebuilded');
    return child;
  }
}
