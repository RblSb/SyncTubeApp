import 'dart:convert';

import 'package:video_player/video_player.dart';

final _assTimeStamp = RegExp(r'\d+:\d\d:\d\d.\d\d');
final _blockTags = RegExp(r'\{\\[^}]*\}');
final _tags = RegExp(r'\\[^ ]+');

/// Represents a [ClosedCaptionFile], parsed from the ASS file format.
class AssCaptionFile extends ClosedCaptionFile {
  AssCaptionFile(this.fileContents)
      : _captions = _parseCaptionsFromAssString(fileContents);

  final String fileContents;
  final List<Caption> _captions;

  @override
  List<Caption> get captions => _captions;
}

List<Caption> _parseCaptionsFromAssString(String file) {
  final List<Caption> captions = <Caption>[];

  final List<String> lines = LineSplitter.split(file).toList();
  bool eventStart = false;
  bool formatFound = false;
  Map<String, int> ids = {};
  var captionNumber = 1;
  for (final String rawLine in lines) {
    final line = rawLine.trim();
    if (!eventStart) {
      eventStart = line.startsWith('[Events]');
      continue;
    }

    if (!formatFound) {
      formatFound = line.startsWith('Format:');
      if (!formatFound) continue;
      final list = line.replaceFirst('Format:', '').split(',');
      ids = {for (var i = 0; i < list.length; i++) list[i].trim(): i};
    }

    if (!line.startsWith('Dialogue: ')) continue;
    var list = line.replaceFirst('Dialogue:', '').split(',');
    while (list.length > ids.length) {
      final el = list.removeLast();
      list[list.length - 1] += el;
    }
    list = list.map((e) => e.trim()).toList();
    var text = list[ids['Text']!];
    text = text.replaceAll(_blockTags, '');
    text = text.replaceAll(_tags, '');
    final caption = Caption(
      number: captionNumber,
      start: _parseAssTimestamp(list[ids['Start']!]),
      end: _parseAssTimestamp(list[ids['End']!]),
      text: text,
    );
    captions.add(caption);
    captionNumber++;
  }
  return captions;
}

Duration _parseAssTimestamp(String timestampString) {
  if (!_assTimeStamp.hasMatch(timestampString)) {
    return const Duration();
  }
  final List<String> commaSections = timestampString.split('.');
  final List<String> hoursMinutesSeconds = commaSections[0].split(':');

  final int hours = int.parse(hoursMinutesSeconds[0]);
  final int minutes = int.parse(hoursMinutesSeconds[1]);
  final int seconds = int.parse(hoursMinutesSeconds[2]);
  final int milliseconds = int.parse(commaSections[1]);

  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}
