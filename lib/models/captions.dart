class LocalCaption {
  const LocalCaption({
    required this.number,
    required this.start,
    required this.end,
    required this.text,
  });

  final int number;
  final Duration start;
  final Duration end;
  final String text;
}

abstract class LocalClosedCaptionFile {
  List<LocalCaption> get captions;

  LocalCaption? getCaptionFor(Duration position) {
    if (captions.isEmpty) return null;
    for (final caption in captions) {
      if (position >= caption.start && position <= caption.end) {
        return caption;
      }
    }
    return null;
  }
}

class WebVTTCaptionFile extends LocalClosedCaptionFile {
  WebVTTCaptionFile(String webvtt) : _captions = _parseWebVTT(webvtt);

  final List<LocalCaption> _captions;

  @override
  List<LocalCaption> get captions => _captions;

  static List<LocalCaption> _parseWebVTT(String data) {
    final List<LocalCaption> captions = [];
    final lines = data.split('\n');
    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final times = line.split('-->');
        final start = _parseTimestamp(times[0].trim());
        final end = _parseTimestamp(times[1].trim());
        String text = '';
        i++;
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          text += lines[i].trim() + '\n';
          i++;
        }
        captions.add(
          LocalCaption(
            number: captions.length,
            start: start,
            end: end,
            text: text.trim(),
          ),
        );
      }
      i++;
    }
    return captions;
  }

  static Duration _parseTimestamp(String timestamp) {
    final parts = timestamp.split(':');
    if (parts.length == 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final rest = parts[2].split('.');
      final seconds = int.parse(rest[0]);
      final milliseconds = int.parse(rest[1].padRight(3, '0').substring(0, 3));
      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    } else {
      final minutes = int.parse(parts[0]);
      final rest = parts[1].split('.');
      final seconds = int.parse(rest[0]);
      final milliseconds = int.parse(rest[1].padRight(3, '0').substring(0, 3));
      return Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
    }
  }
}
