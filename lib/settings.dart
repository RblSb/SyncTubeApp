import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app.dart';
import 'wsdata.dart';

class ChannelPreferences {
  final String login;
  final String hash;

  ChannelPreferences({required this.login, required this.hash});

  factory ChannelPreferences.fromJson(Map<String, dynamic> json) {
    return ChannelPreferences(
      login: json['login'] ?? '',
      hash: json['hash'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'login': login,
      'hash': hash,
    };
  }
}

class Settings extends StatelessWidget {
  static void load(AppModel app) async {
    final prefs = await SharedPreferencesAsync();
    final orientationI = await prefs.getInt('prefferedOrientation') ?? 0;
    setPrefferedOrientation(app, Orientation.values[orientationI], save: false);
    setSystemUi(app, await prefs.getBool('hasSystemUi') ?? false);
    app.hasBackgroundAudio = await prefs.getBool('backgroundAudio') ?? true;
    checkedCache = await prefs.getStringList('checkedCache') ?? [];
    // ChannelPreferences are per-channel, so not loaded globally here
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    return ListView(
      children: [
        ListTile(
          title: const Text('Orientation'),
          trailing: Text('${prefferedOrientationText(app)}'),
          onTap: () async {
            var orientationI = app.prefferedOrientation?.index ?? 0;
            orientationI++;
            if (orientationI > 1) orientationI = 0;
            setPrefferedOrientation(app, Orientation.values[orientationI]);
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

  String prefferedOrientationText(AppModel app) {
    switch (app.prefferedOrientation) {
      case null:
        return 'Auto';
      case .portrait:
        return 'Portrait';
      case .landscape:
        return 'Landscape';
    }
  }

  /// Get ChannelPreferences for a given channelUrl (server list key)
  static Future<ChannelPreferences> getChannelPreferences(
    String channelUrl,
  ) async {
    final prefs = await SharedPreferencesAsync();
    final jsonString = await prefs.getString('channelPrefs_$channelUrl');
    if (jsonString == null || jsonString.isEmpty) {
      return ChannelPreferences(login: '', hash: '');
    }
    try {
      final Map<String, dynamic> map = jsonDecode(jsonString);
      return ChannelPreferences.fromJson(map);
    } catch (_) {
      return ChannelPreferences(login: '', hash: '');
    }
  }

  /// Set ChannelPreferences for a given channelUrl (server list key)
  static Future<void> setChannelPreferences(
    String channelUrl,
    ChannelPreferences prefsObj,
  ) async {
    final prefs = await SharedPreferencesAsync();
    final jsonString = jsonEncode(prefsObj.toJson());
    await prefs.setString('channelPrefs_$channelUrl', jsonString);
  }

  /// Reset ChannelPreferences for a given channelUrl (server list key)
  static Future<void> resetChannelPreferences(String channelUrl) async {
    final prefs = await SharedPreferencesAsync();
    await prefs.remove('channelPrefs_$channelUrl');
  }

  static var isTV = false;
  static List<String> checkedCache = [];

  static List<DeviceOrientation> prefferedOrientations = [];

  static void setPrefferedOrientation(
    AppModel app,
    Orientation orientation, {
    save = true,
  }) async {
    switch (orientation) {
      case .portrait:
        prefferedOrientations = [];
        break;
      case .landscape:
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
    app.prefferedOrientation = orientation;

    if (!save) return;
    final prefs = await SharedPreferencesAsync();
    prefs.setInt('prefferedOrientation', orientation.index);
  }

  static void setSystemUi(AppModel app, bool flag) {
    app.hasSystemUi = flag;
    if (flag) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [
          SystemUiOverlay.bottom,
          SystemUiOverlay.top,
        ],
      );
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
}
