import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models/player.dart';
import 'models/app.dart';
import 'playlist.dart';
import 'chat_panel.dart';
import 'settings.dart';
import 'video_player.dart';
import 'wsdata.dart';
import 'chat.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
// import 'color_scheme.dart';

typedef WsDataFunc = void Function(WsData data);

class App extends StatefulWidget {
  const App({
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
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);
    final nativeOrientation = NativeDeviceOrientationCommunicator();
    final orientationStream =
        nativeOrientation.onOrientationChanged(useSensor: true);
    orientationListener = orientationStream.listen((event) {
      switch (event) {
        case NativeDeviceOrientation.landscapeLeft:
          if (Settings.prefferedOrientations.isEmpty) return;
          SystemChrome.setPreferredOrientations(
              [DeviceOrientation.landscapeLeft]);
          break;
        case NativeDeviceOrientation.landscapeRight:
          if (Settings.prefferedOrientations.isEmpty) return;
          SystemChrome.setPreferredOrientations(
              [DeviceOrientation.landscapeRight]);
          break;
        default:
      }
    });
  }

  late AppModel app;
  late StreamSubscription<NativeDeviceOrientation>? orientationListener;

  Widget providers({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app.playlist),
        ChangeNotifierProvider.value(value: app.player),
        ChangeNotifierProvider.value(value: app.chat),
        ChangeNotifierProvider.value(value: app.chatPanel),
        ChangeNotifierProvider.value(value: app),
      ],
      child: AnnotatedRegion(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
        ),
        child: GestureDetector(
          onTap: () => removeFocus(),
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _onWillPop(context);
            },
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
          children: [
            Selector<AppModel, bool>(
                selector: (context, app) => app.isChatVisible,
                builder: (context, isChatVisible, child) {
                  return Selector<PlayerModel, double>(
                    selector: (context, player) {
                      final isInit =
                          player.controller?.value.isInitialized ?? false;
                      if (!isInit) return 16 / 9;
                      return player.controller?.value.aspectRatio ?? 16 / 9;
                    },
                    builder: (context, ratio, child) {
                      final media = MediaQuery.of(context);
                      return Container(
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
                              ChatPanel(),
                            Expanded(child: VideoPlayerScreen()),
                          ],
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
                      children: [
                        if (orientation == Orientation.portrait &&
                            !_isKeyboardVisible())
                          ChatPanel(),
                        Selector<AppModel, int>(
                          selector: (context, app) => app.mainTab.index,
                          builder: (context, index, child) {
                            return Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 100),
                                child: _panelWidget(index),
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
          selector: (context, app) =>
              app.mainTab == MainTab.playlist && app.isChatVisible,
          builder: (context, isVisible, child) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 100),
              child: isVisible
                  ? FloatingActionButton(
                      tooltip: 'Add video URL',
                      child: const Icon(Icons.add),
                      onPressed: () => _addUrlDialog(context),
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _panelWidget(int index) {
    switch (index) {
      case 1:
        return Playlist();
      case 2:
        return Settings();
      default:
        return Chat();
    }
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
      case AppLifecycleState.resumed:
        app.inForeground();
        break;
      default:
    }
  }

  void removeFocus() {
    FocusScope.of(context).focusedChild?.unfocus();
    FocusScope.of(context).unfocus();
    SystemChrome.restoreSystemUIOverlays();
  }

  Future<bool> _onWillPop(BuildContext context) async {
    if (!Settings.isTV) {
      if (!app.isChatVisible) {
        app.isChatVisible = true;
        return false;
      }
      final focus = FocusScope.of(context);
      if (focus.hasFocus && focus.focusedChild != null) {
        removeFocus();
        return false;
      }
    }
    bool? dialog = await showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return PopScope(
          canPop: true,
          child: AlertDialog(
            title: const Text('Are you sure?'),
            content: const Text('Do you want to exit channel?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        );
      },
    );
    removeFocus();
    final result = dialog ?? false;
    if (result) Navigator.of(context).pop();
    return result;
  }

  String getPlayerType(String url) {
    final playerType =
        PlayerModel.extractVideoId(url).isEmpty ? 'RawType' : 'YoutubeType';
    return playerType;
  }

  onUrlUpdate(AddVideo data, String url) {
    data.item.url = url;
    final playerType = getPlayerType(url);
    data.item.playerType = playerType;
    final hasCacheSupport = app.playersCacheSupport.contains(playerType);
    data.item.doCache = Settings.checkedCache.contains(playerType);
    if (!hasCacheSupport) data.item.doCache = false;
  }

  Future<AddVideo?> _addUrlDialog(BuildContext context) async {
    final clipboard = await Clipboard.getData('text/plain');
    final defaultUrl = '';
    var url = defaultUrl;
    final clipboardText = clipboard?.text ?? '';
    if (clipboardText.contains('mp4') ||
        clipboardText.contains('mp3') ||
        clipboardText.contains('m3u8') ||
        clipboardText.contains('youtu')) {
      url = clipboardText;
    }
    final data = AddVideo(
      item: VideoList(
        url: url,
        subs: '',
        title: 'Raw Video',
        author: '',
        duration: 0.0,
        isTemp: true,
        playerType: '',
        doCache: Settings.checkedCache.contains(getPlayerType(url)),
      ),
      atEnd: true,
    );
    onUrlUpdate(data, url);

    final addVideo = await showDialog<AddVideo>(
      context: context,
      builder: (BuildContext context) {
        final bgAlpha = app.playlist.isEmpty() ? 255 : 200;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor:
                  Theme.of(context).dialogBackgroundColor.withAlpha(bgAlpha),
              insetPadding: EdgeInsets.zero,
              scrollable: true,
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                        initialValue: data.item.url,
                        autofocus: url == defaultUrl,
                        decoration: const InputDecoration(
                          labelText: 'Video URL',
                        ),
                        onChanged: (value) {
                          onUrlUpdate(data, value);
                          setState(() => {});
                        }),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Subtitles URL',
                      ),
                      onChanged: (value) => data.item.subs = value,
                    ),
                    if (app.playersCacheSupport
                        .contains(getPlayerType(data.item.url)))
                      CheckboxListTile(
                        title: const Text('Cache'),
                        value: data.item.doCache,
                        onChanged: (flag) => setState(() {
                          data.item.doCache = flag == true;
                          final playerType = getPlayerType(data.item.url);
                          Settings.setPlayerCacheCheckbox(
                            playerType,
                            data.item.doCache,
                          );
                        }),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Queue next'),
                  onPressed: () {
                    data.atEnd = false;
                    Navigator.of(context).pop(data);
                    app.sendVideoItem(data);
                  },
                ),
                TextButton(
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
    orientationListener?.cancel();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
  }
}

class Printer extends StatelessWidget {
  const Printer({Key? key, required this.child}) : super(key: key);
  final Widget child;
  @override
  Widget build(BuildContext context) {
    print('child rebuilded');
    return child;
  }
}
