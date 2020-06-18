import 'package:flutter/material.dart';

import 'wsdata.dart';

class EmotesTab extends StatelessWidget {
  const EmotesTab({
    Key key,
    @required this.emotes,
    @required this.input,
  }) : super(key: key);

  final List<Emotes> emotes;
  final TextEditingController input;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 4,
        children: emotes.map((emote) {
          return Center(
            child: InkWell(
              onTap: () {
                input.text += ' ${emote.name}';
                input.selection = TextSelection.fromPosition(
                  TextPosition(offset: input.text.length),
                );
              },
              child: Image.network(emote.image),
            ),
          );
        }).toList(),
      ),
    );
  }
}
