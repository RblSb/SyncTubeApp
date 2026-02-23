import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
// import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:provider/provider.dart';
import 'package:synctube/models/app.dart';
import 'package:synctube/utils/multi_tap_recognizer.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'chat_panel.dart';
import 'color_scheme.dart';
import 'models/chat_panel.dart';
import 'models/player.dart';
import 'settings.dart';

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
          case .waiting:
          case .active:
            return const Center(child: CircularProgressIndicator());

          case .done:
            if (Settings.isTV) {
              return TvControls(
                child: buildPlayer(player),
              );
            }
            return buildPlayer(player);
          case .none:
            return GestureDetector(
              child: Settings.isTV
                  ? tvEmptyPlayerWidget(context)
                  : const SizedBox.expand(),
              behavior: HitTestBehavior.translucent,
              // don't allow to go fullscreen on empty player, only enter landscape
              onDoubleTap: () {
                if (player.app.prefferedOrientation == .landscape) return;
                goLandscapeOrFullscreen(player.app);
              },
              onLongPress: () {
                if (player.app.prefferedOrientation == .landscape) return;
                goLandscapeOrFullscreen(player.app);
              },
            );
        }
      },
    );
  }

  Widget buildPlayer(PlayerModel player) {
    if (player.isIframe()) return iframeWidget(player);

    final captionText = player.currentCaptions
        ?.getCaptionFor(player.player.state.position)
        ?.text;
    return MultiTapListener(
      onDoubleTap: () => goLandscapeOrFullscreen(player.app),
      child: GestureDetector(
        // onDoubleTap: () => goLandscapeOrFullscreen(player.app),
        onLongPress: () {
          if (player.showControls) return;
          goLandscapeOrFullscreen(player.app);
        },
        child: Stack(
          children: [
            Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: player.isFitWidth ? BoxFit.fitWidth : BoxFit.contain,
                  child: SizedBox(
                    width: player.player.state.width?.toDouble() ?? (1280 / 2),
                    height: player.player.state.height?.toDouble() ?? (720 / 2),
                    child: Video(controller: player.controller),
                  ),
                ),
              ],
            ),
            if (player.app.showSubtitles &&
                captionText != null &&
                captionText.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Text(
                    captionText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      backgroundColor: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            _PlayPauseOverlay(player: player),
            _ChatToggleButton(player: player),
          ],
        ),
      ),
    );
  }

  void goLandscapeOrFullscreen(AppModel app) {
    final orientation = app.prefferedOrientation;
    switch (orientation) {
      case .portrait:
        Settings.setPrefferedOrientation(app, .landscape);
      case .landscape:
        app.isChatVisible = !app.isChatVisible;
      case null:
    }
    SystemChrome.restoreSystemUIOverlays();
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

  String _timeText(PlayerModel player) {
    final state = player.player.state;
    final p = _stringDuration(state.position);
    final d = _stringDuration(state.duration);
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
                child: Text(_timeText(player)),
              ),
            ),
          if (player.showControls) _buildVideoProgress(context),
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
                    _buildPlaybackRateButton(context),
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
                        Icons.screen_rotation,
                        color: Theme.of(context).playerIcon,
                        size: 23,
                      ),
                      tooltip: player.fullscreenTooltipText,
                      onPressed: () {
                        final orientation = MediaQuery.of(context).orientation;
                        switch (orientation) {
                          case .portrait:
                            Settings.setPrefferedOrientation(
                              player.app,
                              .landscape,
                            );
                          case .landscape:
                            player.app.isChatVisible = true;
                            Settings.setPrefferedOrientation(
                              player.app,
                              .portrait,
                            );
                        }
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

  PopupMenuButton<double> _buildPlaybackRateButton(BuildContext context) {
    return PopupMenuButton<double>(
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onLongPress: () {
          player.setPlaybackSpeed(1.0);
          HapticFeedback.mediumImpact();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Icon(
                Icons.speed_outlined,
                color: Theme.of(context).playerIcon,
                size: 30,
              ),
            ),
            if (player.player.state.rate != 1.0)
              Positioned(
                top: -2,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    player.player.state.rate.toString().replaceAll('.0', ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      initialValue: player.player.state.rate,
      onSelected: (double speed) {
        player.setPlaybackSpeed(speed);
        player.hideControlsWithDelay();
      },
      onOpened: () => player.cancelControlsHide(),
      onCanceled: () => player.hideControlsWithDelay(),
      itemBuilder: (BuildContext context) {
        return [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map(
          (double speed) {
            return PopupMenuItem<double>(
              value: speed,
              child: Text('${speed}'),
            );
          },
        ).toList();
      },
    );
  }

  GestureDetector _buildVideoProgress(BuildContext context) {
    var durationMs = player.player.state.duration.inMilliseconds.toDouble();
    if (durationMs == 0) durationMs = 1;
    var posMs = player.player.state.position.inMilliseconds.toDouble();
    var bufMs = player.player.state.buffer.inMilliseconds.toDouble();
    posMs = posMs.clamp(0, durationMs);

    return GestureDetector(
      onHorizontalDragDown: (details) {
        player.cancelControlsHide();
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 15,
            top: 5,
            left: 15,
            right: 15,
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 12,
              ),
            ),
            child: SizedBox(
              height: 15,
              child: Slider(
                value: posMs,
                min: 0,
                max: durationMs,
                secondaryTrackValue: bufMs,
                onChanged: (value) {
                  player.seekTo(
                    Duration(milliseconds: value.toInt()),
                  );
                },
                activeColor: const Color.fromRGBO(200, 0, 0, 0.75),
                inactiveColor: const Color.fromRGBO(200, 200, 200, 0.2),
                secondaryActiveColor: const Color.fromRGBO(255, 255, 255, 0.3),
              ),
            ),
          ),
        ),
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

class _ChatToggleButton extends StatelessWidget {
  const _ChatToggleButton({
    Key? key,
    required this.player,
  }) : super(key: key);

  final PlayerModel player;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).orientation == .portrait) {
      return const SizedBox.shrink();
    }

    final app = player.app;
    final showControls = player.showControls;
    final showMessageIcon = player.showMessageIcon;
    // final showMessageIcon = true;

    if (!showControls && !showMessageIcon) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: showControls
              ? IconButton(
                  icon: _buildChatIcon(context, app.isChatVisible),
                  tooltip: player.fullscreenTooltipText,
                  onPressed: () {
                    app.isChatVisible = !app.isChatVisible;
                    player.hideControlsWithDelay();
                  },
                )
              : _buildUnreadIcon(context),
        ),
      ),
    );
  }

  Widget _buildUnreadIcon(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Icon(
        Icons.chat_bubble,
        color: Theme.of(
          context,
        ).playerIcon.withValues(alpha: 0.5),
        size: 24,
        shadows: [
          Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildChatIcon(BuildContext context, bool isVisible) {
    final color = Theme.of(context).playerIcon;
    const icon = Icons.chat_bubble_outline;
    const size = 24.0;

    if (!isVisible) {
      return const Icon(icon, color: Colors.white, size: size);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: color, size: size),
        Transform.translate(
          offset: Offset(0, -1.5),
          child: Transform.rotate(
            angle: -45 * (math.pi / 180.0),
            child: Container(
              width: 2,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
