import 'package:video_player/video_player.dart';

class RawCaptionFile extends ClosedCaptionFile {
  RawCaptionFile(this._captions);

  final List<Caption> _captions;

  @override
  List<Caption> get captions => _captions;
}
