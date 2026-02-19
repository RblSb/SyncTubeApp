import 'package:flutter/widgets.dart';
import '../wsdata.dart';

abstract class AbstractPlayer {
  Widget build(BuildContext context);
  String getPlayerType();
  bool isSupportedLink(String url);
  Future<void> loadVideo(VideoList item);
  void removeVideo();
  bool isVideoLoaded();
  void play();
  void pause();
  bool isPaused();
  Future<Duration> getPosition();
  void seekTo(Duration duration);
  Future<double> getPlaybackRate();
  void setPlaybackRate(double rate);
  void setVolume(double volume);

  // For UI and logic
  double get aspectRatio;
  String get captionText;

  // For metadata
  Future<double> getVideoDuration(String url);
  Future<String> getVideoTitle(String url);

  void dispose();
}
