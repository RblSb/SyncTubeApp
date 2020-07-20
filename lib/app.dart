import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/player.dart';
import 'models/app.dart';
import 'playlist.dart';
import 'chat_panel.dart';
import 'settings.dart';
import 'video_player.dart';
import 'wsdata.dart';
import 'chat.dart';
// import 'color_scheme.dart';

typedef WsDataFunc = void Function(WsData data);

class App extends StatefulWidget {
  App({
    Key? key,
    required this.name,
    required this.url,
  }) : super(key: key);

  final String name;
  final String url;

  @override
  State<StatefulWidget> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    app = AppModel(widget.url);
    Settings.applySettings(app);
  }

  late AppModel app;

  Widget providers({required Widget child}) {
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
          onTap: () => removeFocus(),
          child: WillPopScope(
            onWillPop: () => _onWillPop(context),
            child: Selector<AppModel, bool>(
              selector: (context, app) => app.hasSystemUi,
              builder: (context, hasSystemUi, _) =>
                  hasSystemUi ? SafeArea(child: child) : child,
            ),
          ),
        ),
      ),
    );
  }

  double playerHeight(double ratio) {
    final media = MediaQuery.of(context);
    var height = double.infinity;
    if (media.orientation == Orientation.portrait) {
      height = media.size.width / ratio;
      final max = (media.size.height - media.viewInsets.bottom) / 2;
      if (height > max) height = max;
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    print('App rebuild');
    final orientation = MediaQuery.of(context).orientation;
    return providers(
      child: Scaffold(
        body: Flex(
          direction: orientation == Orientation.landscape
              ? Axis.horizontal
              : Axis.vertical,
          children: <Widget>[
            Selector<AppModel, bool>(
                selector: (context, app) => app.isChatVisible,
                builder: (context, isChatVisible, child) {
                  return Selector<PlayerModel, double>(
                    selector: (context, player) {
                      final isInit =
                          player.controller?.value.initialized ?? false;
                      if (!isInit) return 16 / 9;
                      return player.controller?.value.aspectRatio ?? 16 / 9;
                    },
                    builder: (context, ratio, child) {
                      final media = MediaQuery.of(context);
                      return GestureDetector(
                        onDoubleTap: () => Settings.nextOrientationView(app),
                        child: Container(
                          color: Colors.black,
                          padding: EdgeInsets.only(
                            top: _isKeyboardVisible() ? media.padding.top : 0,
                          ),
                          width: orientation == Orientation.landscape
                              ? isChatVisible
                                  ? media.size.width / 1.5
                                  : media.size.width
                              : double.infinity,
                          height: playerHeight(ratio),
                          child: Column(
                            children: [
                              if (orientation == Orientation.landscape &&
                                  !_isKeyboardVisible() &&
                                  isChatVisible)
                                Consumer<AppModel>(
                                  builder: (context, app, child) =>
                                      ChatPanel(app: app),
                                ),
                              Expanded(child: VideoPlayerScreen()),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
            Selector<AppModel, bool>(
              selector: (context, app) => app.isChatVisible,
              builder: (context, isChatVisible, child) {
                return Visibility(
                  visible: isChatVisible,
                  child: Expanded(
                    child: Column(
                      children: <Widget>[
                        if (orientation == Orientation.portrait &&
                            !_isKeyboardVisible())
                          Consumer<AppModel>(
                            builder: (context, app, child) =>
                                ChatPanel(app: app),
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
                );
              },
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
    );
  }

  bool _isKeyboardVisible() {
    return MediaQuery.of(context).viewInsets.bottom != 0;
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

  void removeFocus() {
    FocusScope.of(context).unfocus();
    SystemChrome.restoreSystemUIOverlays();
  }

  Future<bool> _onWillPop(BuildContext context) async {
    final focus = FocusScope.of(context);
    if (focus.hasFocus && focus.focusedChild != null) {
      removeFocus();
      return false;
    }
    bool? dialog = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to exit channel?'),
        actions: <Widget>[
          FlatButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FlatButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    SystemChrome.restoreSystemUIOverlays();
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
    final addVideo = await showDialog<AddVideo>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: EdgeInsets.zero,
              scrollable: true,
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      initialValue: data.item.url,
                      autofocus: url == defaultUrl,
                      decoration: const InputDecoration(
                        labelText: 'Video URL',
                      ),
                      onChanged: (value) => data.item.url = value,
                    ),
                    CheckboxListTile(
                      title: const Text('Add as temporary'),
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
                  child: const Text('Queue next'),
                  onPressed: () {
                    data.atEnd = false;
                    Navigator.of(context).pop(data);
                    app.sendVideoItem(data);
                  },
                ),
                FlatButton(
                  child: const Text('Queue last'),
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
    SystemChrome.restoreSystemUIOverlays();
    return addVideo;
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
  const Printer({Key? key, this.child}) : super(key: key);
  final Widget? child;
  @override
  Widget? build(BuildContext context) {
    print('child rebuilded');
    return child;
  }
}
