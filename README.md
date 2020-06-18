## SyncTubeApp

Mobile client for [SyncTube](https://github.com/RblSb/SyncTube).

Not supported things for now:
- Iframes
- Youtube playlists
- Login
- Some buttons and settings

### Builds (Android)

Open [workflow list](https://github.com/RblSb/SyncTubeApp/actions?query=is%3Asuccess), open first in list and download apk articaft.

### Development

- Install [Flutter](https://flutter.dev/docs/get-started/install).
- Install VSCode, [Dart](https://marketplace.visualstudio.com/items?itemName=Dart-Code.dart-code) and [Flutter](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter) extensions.
- Open project, connect device with usb, press F5 for debug build with hot-reload.

For signed release build, create `android/release.jks` keystore and `android/key.properties` with:
```
storePassword=VALUE
keyPassword=VALUE
keyAlias=VALUE
storeFile=FILE_PATH
```

And run: `flutter build apk`.

Or `flutter build apk --target-platform=android-arm` for specific architecture.
