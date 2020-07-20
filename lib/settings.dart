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
        ListTile(
          title: Text('Orientation'),
          trailing: Text('${app.prefferedOrientationType()}'),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final key = 'prefferedOrientation';
            var state = prefs.getInt(key) ?? 0;
            state++;
            if (state > 1) state = 0;
            setPrefferedOrientation(app, state);
            prefs.setInt(key, state);
          },
        ),
        SwitchListTile(
          title: Text('System UI'),
          value: app.hasSystemUi,
          onChanged: (state) async {
            final prefs = await SharedPreferences.getInstance();
            prefs.setBool('hasSystemUi', state);
            setSystemUi(app, state);
          },
        ),
      ],
    );
  }

  static nextOrientationView(AppModel app) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'prefferedOrientation';
    var state = prefs.getInt(key) ?? 0;
    switch (state) {
      case 0:
        state++;
        setPrefferedOrientation(app, state);
        prefs.setInt(key, state);
        break;
      case 1:
        app.isChatVisible = !app.isChatVisible;
        break;
    }
  }

  static setPrefferedOrientation(AppModel app, int state) {
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
    }
    app.setPrefferedOrientation(state);
  }

  static setSystemUi(AppModel app, bool flag) {
    app.hasSystemUi = flag;
    if (flag) {
      SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.bottom, SystemUiOverlay.top],
      );
    } else {
      SystemChrome.setEnabledSystemUIOverlays([]);
    }
  }

  static applySettings(AppModel app) async {
    final prefs = await SharedPreferences.getInstance();
    setPrefferedOrientation(app, prefs.getInt('prefferedOrientation') ?? 0);
    setSystemUi(app, prefs.getBool('hasSystemUi') ?? false);
  }
}
