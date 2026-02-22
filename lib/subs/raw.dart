import '../models/captions.dart';

class RawCaptionFile extends LocalClosedCaptionFile {
  RawCaptionFile(this._captions);

  final List<LocalCaption> _captions;

  @override
  List<LocalCaption> get captions => _captions;
}
