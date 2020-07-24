import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'models/app.dart';
import 'models/player.dart';

class VideoPlayerScreen extends StatelessWidget {
  VideoPlayerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // print('player rebuild');
    final player = Provider.of<PlayerModel>(context);
    return FutureBuilder(
      future: player.initPlayerFuture,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
          case ConnectionState.active:
            return const Center(child: CircularProgressIndicator());

          case ConnectionState.done:
            return Align(
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: player.controller?.value.aspectRatio ?? 16 / 9,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    VideoPlayer(player.controller),
                    AnimatedOpacity(
                      opacity: player.showMessageIcon ? 0.5 : 0,
                      duration: const Duration(milliseconds: 500),
                      child: const Align(
                        alignment: Alignment.topRight,
                        child: Icon(Icons.mail),
                      ),
                    ),
                    if (player.controller?.value.caption.text != null)
                      ClosedCaption(
                        text: player.controller?.value.caption.text,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    _PlayPauseOverlay(player: player),
                  ],
                ),
              ),
            );
          default:
            return const SizedBox.shrink();
        }
      },
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

  void _hideControlsWithDelay() {
    if (!player.showControls) return;
    player.controlsTimer?.cancel();
    player.controlsTimer = Timer(
      const Duration(seconds: 3),
      () => player.toggleControls(false),
    );
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
              _hideControlsWithDelay();
            },
            child: Container(
              color: Colors.black38,
              child: Center(
                child: GestureDetector(
                  onTap: player.showControls ? _onPlayButton : null,
                  child: Icon(
                    player.isPlaying() ? Icons.pause : Icons.play_arrow,
                    color: Colors.white60,
                    size: 100,
                  ),
                ),
              ),
            ),
          ),
          if (player.showControls)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7, left: 7),
                child: Text(_timeText(player.controller?.value)),
              ),
            ),
          if (player.showControls)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VideoProgressIndicator(
                  player.controller,
                  padding: const EdgeInsets.only(bottom: 20, top: 20),
                  colors: VideoProgressColors(
                    playedColor: const Color.fromRGBO(200, 0, 0, 0.75),
                    bufferedColor: const Color.fromRGBO(200, 200, 200, 0.5),
                    backgroundColor: const Color.fromRGBO(200, 200, 200, 0.2),
                  ),
                  allowScrubbing: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
