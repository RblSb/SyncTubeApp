import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';
import 'chat_panel.dart';
import 'models/chat_panel.dart';
import 'models/player.dart';
import 'settings.dart';
import 'color_scheme.dart';

class VideoPlayerScreen extends StatelessWidget {
  VideoPlayerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // print('player rebuild');
    final player = context.watch<PlayerModel>();
    return FutureBuilder(
      future: player.initPlayerFuture,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
          case ConnectionState.active:
            return const Center(child: CircularProgressIndicator());

          case ConnectionState.done:
            if (Settings.isTV) {
              return TvControls(
                child: buildPlayer(player),
              );
            }
            return buildPlayer(player);
          default:
            return GestureDetector(
              child: Settings.isTV
                  ? tvEmptyPlayerWidget(context)
                  : const SizedBox.expand(),
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () {
                if (player.app.prefferedOrientationType() == 'Landscape')
                  return;
                Settings.nextOrientationView(player.app);
              },
              onLongPress: () {
                if (player.app.prefferedOrientationType() == 'Landscape')
                  return;
                Settings.nextOrientationView(player.app);
              },
            );
        }
      },
    );
  }

  Widget buildPlayer(PlayerModel player) {
    if (player.isIframe()) return iframeWidget(player);
    final captionText = player.controller?.value.caption.text;
    return GestureDetector(
      onDoubleTap: () => Settings.nextOrientationView(player.app),
      onLongPress: () {
        if (player.showControls) return;
        Settings.nextOrientationView(player.app);
      },
      child: Stack(
        children: [
          Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: player.isFitWidth ? BoxFit.fitWidth : BoxFit.contain,
                child: SizedBox(
                  width: player.controller?.value.aspectRatio ?? 16 / 9,
                  height: 1,
                  child: VideoPlayer(player.controller!),
                ),
              ),
            ],
          ),
          if (player.app.showSubtitles &&
              captionText != null &&
              captionText.isNotEmpty)
            ClosedCaption(
              text: captionText,
              textStyle: const TextStyle(fontSize: 16),
            ),
          _PlayPauseOverlay(player: player),
          AnimatedOpacity(
            opacity: player.showMessageIcon ? 0.7 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.mail),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget iframeWidget(PlayerModel player) {
    return GestureDetector(
      onTap: () async {
        final link = player.app.getChannelLink();
        if (await canLaunchUrlString(link))
          launchUrlString(link, mode: LaunchMode.externalApplication);
      },
      child: const Align(
        alignment: Alignment.center,
        child: Text(
          'Iframes are not supported.\nClick here to open web client.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget tvEmptyPlayerWidget(BuildContext context) {
    final panel = context.watch<ChatPanelModel>();
    return GestureDetector(
      child: Align(
        alignment: Alignment.center,
        child: Text(
          !panel.isConnected
              ? 'Connection...'
              : 'Playlist is empty. Waiting for videos... (${panel.clients.length} online)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  const _PlayPauseOverlay({
    Key? key,
    required this.player,
  }) : super(key: key);

  final PlayerModel player;

  void _onPlayButton() {
    if (!player.isPlaying()) player.toggleControls(false);
    player.userSetPlayerState(!player.isPlaying());
  }

  String _timeText(VideoPlayerValue? value) {
    if (value == null) return '';
    final p = _stringDuration(value.position);
    final d = _stringDuration(value.duration);
    return '$p / $d';
  }

  String _stringDuration(Duration d) {
    final twoDigitMinutes = _twoDigits(d.inMinutes.remainder(60));
    final twoDigitSeconds = _twoDigits(d.inSeconds.remainder(60));
    final h = d.inHours == 0 ? '' : '${_twoDigits(d.inHours)}:';
    return '$h$twoDigitMinutes:$twoDigitSeconds';
  }

  String _twoDigits(num n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: player.showControls ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              player.toggleControls(!player.showControls);
              player.hideControlsWithDelay();
            },
            child: Container(
              color: Colors.black38,
              child: Center(
                child: GestureDetector(
                  onTap: player.showControls ? _onPlayButton : null,
                  child: Icon(
                    player.isPlaying() ? Icons.pause : Icons.play_arrow,
                    color: Colors.white70,
                    size: MediaQuery.of(context).size.shortestSide / 4,
                  ),
                ),
              ),
            ),
          ),
          if (player.showControls)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32, left: 15),
                child: Text(_timeText(player.controller?.value)),
              ),
            ),
          if (player.showControls)
            GestureDetector(
              onHorizontalDragDown: (details) {
                player.cancelControlsHide();
              },
              child: Align(
                alignment: Alignment.bottomCenter,
                child: VideoProgressIndicator(
                  player.controller!,
                  padding: const EdgeInsets.only(
                      bottom: 15, top: 5, left: 15, right: 15),
                  colors: VideoProgressColors(
                    playedColor: const Color.fromRGBO(200, 0, 0, 0.75),
                    bufferedColor: const Color.fromRGBO(200, 200, 200, 0.5),
                    backgroundColor: const Color.fromRGBO(200, 200, 200, 0.2),
                  ),
                  allowScrubbing: true,
                ),
              ),
            ),
          if (player.showControls)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(player.getCurrentItemTitle()),
              ),
            ),
          if (player.showControls)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        player.isFitWidth
                            ? Icons.fit_screen
                            : Icons.fit_screen_outlined,
                        color: Theme.of(context).playerIcon,
                        size: 30,
                      ),
                      onPressed: () {
                        player.isFitWidth = !player.isFitWidth;
                      },
                    ),
                    if (player.hasCaptions())
                      IconButton(
                        icon: Icon(
                          player.app.showSubtitles
                              ? Icons.subtitles
                              : Icons.subtitles_off,
                          color: Theme.of(context).playerIcon,
                          size: 30,
                        ),
                        onPressed: () {
                          player.app.showSubtitles = !player.app.showSubtitles;
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        player.app.isChatVisible
                            ? Icons.fullscreen
                            : Icons.fullscreen_exit,
                        color: Theme.of(context).playerIcon,
                        size: 30,
                      ),
                      tooltip: 'Double-tap or long-tap for fullscreen',
                      onPressed: () {
                        Settings.nextOrientationView(player.app);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AllowMultipleGestureRecognizer extends TapGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

class TvControls extends StatelessWidget {
  TvControls({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;
  static final focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: KeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: (value) {
          if (!focusNode.hasFocus) return;
          final isKeyPressed = HardwareKeyboard.instance.isLogicalKeyPressed;
          if (isKeyPressed(LogicalKeyboardKey.arrowUp)) {
            ChatPanel.showUsersSnackBar(context);
          }
          if (isKeyPressed(LogicalKeyboardKey.select)) {
            final player = context.read<PlayerModel>();
            player.toggleControls(!player.showControls);
            player.hideControlsWithDelay();
          }
          // if (isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
          //   () async {
          //     final volume = await PerfectVolumeControl.getVolume();
          //     var newVolume = volume - 0.1;
          //     if (newVolume < 0) newVolume = 0;
          //     PerfectVolumeControl.setVolume(newVolume);
          //   }();
          // }
          // if (isKeyPressed(LogicalKeyboardKey.arrowRight)) {
          //   () async {
          //     final volume = await PerfectVolumeControl.getVolume();
          //     var newVolume = volume + 0.1;
          //     if (newVolume > 1) newVolume = 1;
          //     PerfectVolumeControl.setVolume(newVolume);
          //   }();
          // }
        },
        child: child,
      ),
    );
  }
}
