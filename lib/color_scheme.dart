import 'package:flutter/material.dart';

extension CustomColorScheme on ThemeData {
  Color get icon => Colors.grey;
  Color get playlistItemBorder => Colors.grey[900]!;
  Color get chatPanelBackground => const Color(0xFF0A0A0A);
  Color get leaderActiveBorder => Colors.green;
  Color get timeStamp => Colors.grey;
  Color get rewindButton => Colors.white;
}
