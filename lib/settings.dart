import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app.dart';

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppModel>(context);
    return Column(
      children: <Widget>[
        FlatButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            final key = 'prefferedOrientation';
            var state = prefs.getInt(key) ?? 0;
            state++;
            if (state > 2) state = 0;
            switch (state) {
              case 0:
                SystemChrome.setPreferredOrientations([]);
                break;
              case 1:
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight
                ]);
                break;
              case 2:
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                ]);
                break;
            }
            app.setPrefferedOrientation(state);
            prefs.setInt(key, state);
          },
          child: Text('Orientation: ${app.prefferedOrientationType()}'),
        ),
      ],
    );
  }
}
