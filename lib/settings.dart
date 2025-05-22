import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app.dart';
import 'wsdata.dart';

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    return ListView(
      children: [
        ListTile(
          title: const Text('Orientation'),
          trailing: Text('${app.prefferedOrientationType()}'),
          onTap: () async {
            final prefs = await SharedPreferencesAsync();
            final key = 'prefferedOrientation';
            var state = await prefs.getInt(key) ?? 0;
            state++;
            if (state > 1) state = 0;
            setPrefferedOrientation(app, state);
            await prefs.setInt(key, state);
          },
        ),
        SwitchListTile(
          title: const Text('System UI'),
          value: app.hasSystemUi,
          onChanged: (state) async {
            final prefs = await SharedPreferencesAsync();
            await prefs.setBool('hasSystemUi', state);
            setSystemUi(app, state);
          },
        ),
        SwitchListTile(
          title: const Text('Background audio'),
          value: app.hasBackgroundAudio,
          onChanged: (state) async {
            final prefs = await SharedPreferencesAsync();
            await prefs.setBool('backgroundAudio', state);
            app.hasBackgroundAudio = state;
          },
        ),
        if (!app.chat.isUnknownClient)
          ListTile(
            title: const Text('Logout'),
            onTap: () {
              app.send(WsData(type: 'Logout'));
            },
          ),
      ],
    );
  }

  static Future<String> getSavedName() async {
    final prefs = await SharedPreferencesAsync();
    return await prefs.getString('savedName') ?? '';
  }

  static Future<List<String>> getSavedNameAndHash() async {
    final prefs = await SharedPreferencesAsync();
    return [
      await prefs.getString('savedName') ?? '',
      await prefs.getString('savedHash') ?? '',
    ];
  }

  static void resetNameAndHash() async {
    final prefs = await SharedPreferencesAsync();
    await prefs.setString('savedName', '');
    await prefs.setString('savedHash', '');
  }

  static void nextOrientationView(AppModel app) async {
    final prefs = await SharedPreferencesAsync();
    final key = 'prefferedOrientation';
    var state = await prefs.getInt(key) ?? 0;
    switch (state) {
      case 0:
        state++;
        setPrefferedOrientation(app, state);
        await prefs.setInt(key, state);
        break;
      case 1:
        app.isChatVisible = !app.isChatVisible;
        break;
    }
    SystemChrome.restoreSystemUIOverlays();
  }

  static var isTV = false;
  static List<String> checkedCache = [];

  static List<DeviceOrientation> prefferedOrientations = [];

  static void setPrefferedOrientation(AppModel app, int state) async {
    switch (state) {
      case 0:
        prefferedOrientations = [];
        break;
      case 1:
        prefferedOrientations = [
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ];
        final orientation = await NativeDeviceOrientationCommunicator()
            .orientation(useSensor: true)
            .timeout(
              Duration(milliseconds: 100),
              onTimeout: () => NativeDeviceOrientation.landscapeLeft,
            );
        if (orientation == NativeDeviceOrientation.landscapeRight)
          prefferedOrientations = [DeviceOrientation.landscapeRight];
        break;
    }
    SystemChrome.setPreferredOrientations(prefferedOrientations);
    app.setPrefferedOrientation(state);
  }

  static void setSystemUi(AppModel app, bool flag) {
    app.hasSystemUi = flag;
    if (flag) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
        SystemUiOverlay.bottom,
        SystemUiOverlay.top,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    }
  }

  static setPlayerCacheCheckbox(String playerType, bool checked) async {
    final prefs = await SharedPreferencesAsync();
    checkedCache.remove(playerType);
    if (checked) checkedCache.add(playerType);
    await prefs.setStringList('checkedCache', checkedCache);
  }

  static void applySettings(AppModel app) async {
    final prefs = await SharedPreferencesAsync();
    setPrefferedOrientation(
        app, await prefs.getInt('prefferedOrientation') ?? 0);
    setSystemUi(app, await prefs.getBool('hasSystemUi') ?? false);
    app.hasBackgroundAudio = await prefs.getBool('backgroundAudio') ?? true;
    checkedCache = await prefs.getStringList('checkedCache') ?? [];
  }
}
