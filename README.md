## SyncTubeApp

Mobile client for [SyncTube](https://github.com/RblSb/SyncTube).

Screenshots: [portrait](https://i.imgur.com/ft5N5bb.png) / [landscape](https://i.imgur.com/Q0jz89w.png).

### Builds (Android)

Open [workflow list](https://github.com/RblSb/SyncTubeApp/actions?query=is%3Asuccess), open first in list and download apk articaft.
Or try to download from [this link](https://nightly.link/RblSb/SyncTubeApp/workflows/main/master/app-release.apk.zip).

### Development

- Install [Flutter](https://flutter.dev/docs/development/tools/sdk/releases) (1.22.0+).
- Install VSCode and [Flutter](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter) extension.
- Open project, connect device with usb, press F5 for debug build with hot-reload.

For signed release build, create `android/release.jks` [keystore](https://flutter.dev/docs/deployment/android#create-a-keystore) and `android/key.properties` with:
```
storePassword=VALUE
keyPassword=VALUE
keyAlias=VALUE
storeFile=release.jks
```

And run: `flutter build apk`.

Or `flutter build apk --target-platform=android-arm` for specific architecture.
