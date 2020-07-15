import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:SyncTube/models/player.dart';

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
                child: GestureDetector(
                  onPanDown: (_) {
                    player.toggleControls(true);
                    player.controlsTimer?.cancel();
                    player.controlsTimer =
                        Timer(const Duration(seconds: 3), () {
                      player.toggleControls(false);
                    });
                  },
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      VideoPlayer(player.controller),
                      ClosedCaption(
                        text: player.controller?.value.caption.text,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      if (player.showControls)
                        _PlayPauseOverlay(
                          player: player,
                        ),
                      if (player.showControls)
                        VideoProgressIndicator(
                          player.controller,
                          padding: const EdgeInsets.only(top: 20),
                          allowScrubbing: true,
                        ),
                    ],
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: player.isPlaying()
              ? Container(
                  color: Colors.black38,
                  child: const Center(
                    child: Icon(
                      Icons.pause,
                      color: Colors.white60,
                      size: 100.0,
                    ),
                  ),
                )
              : Container(
                  color: Colors.black38,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white60,
                      size: 100.0,
                    ),
                  ),
                ),
        ),
        GestureDetector(onTap: () {
          if (!player.isPlaying()) {
            // Timer(const Duration(milliseconds: 100), () {});
            player.toggleControls(false);
          }
          player.userSetPlayerState(!player.isPlaying());
        }),
      ],
    );
  }
}
